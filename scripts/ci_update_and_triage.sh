#!/usr/bin/env bash
set -euo pipefail

# Automated CI flake update, build verification, AI failure analysis,
# single-issue management, and candidate fix Draft PR generator.
#
# Usage:
#   scripts/ci_update_and_triage.sh [--dry-run]

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$REPO_ROOT"

DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      cat <<'EOF'
Usage: scripts/ci_update_and_triage.sh [OPTIONS]

Options:
  --dry-run   Run updates and checks without pushing or mutating GitHub issues/PRs
  -h, --help  Show this help message
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

AUTHOR_HANDLE="${GITHUB_REPOSITORY_OWNER:-f0xdx}"
ISSUE_LABEL="flake-update-failure"
MODELS_API_URL="${GITHUB_MODELS_URL:-https://models.github.ai/inference/chat/completions}"
AI_MODEL="${GITHUB_MODELS_MODEL:-openai/gpt-4o}"
AI_TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-}}"

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

FLAKES=(
  "junie:scripts/update_junie.sh"
  "cortex-code:scripts/update_cortex_code.sh"
  "air-gateway:scripts/update_air_gateway.sh"
  "antigravity-acp:scripts/update_antigravity_acp.sh"
  "codex-acp:scripts/update_codex_acp.sh"
)

UPDATED_FLAKES=()
UNCHANGED_FLAKES=()
FAILED_FLAKES=()
COMMITS_CREATED=0

configure_git_identity() {
  if [[ "$DRY_RUN" == "1" ]]; then
    return 0
  fi
  if [[ -z "$(git config user.name || true)" ]]; then
    git config user.name "github-actions[bot]"
  fi
  if [[ -z "$(git config user.email || true)" ]]; then
    git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
  fi
}

update_single_flake() {
  local name="$1"
  local script="$2"
  local log_file="$WORK_DIR/${name}.log"
  local meta_file="pkgs/${name}/metadata.json"
  local old_version new_version
  local failed_stage=""

  old_version=$(jq -r '.version // "unknown"' "$meta_file" 2>/dev/null || echo "unknown")
  echo "=================================================================="
  echo "Processing flake: ${name} (current version: ${old_version})"
  echo "=================================================================="

  : > "$log_file"

  echo "---> Step 1/3: Running ${script}..." | tee -a "$log_file"
  if ! SKIP_ROOT_LOCK_UPDATE=1 bash "$script" >> "$log_file" 2>&1; then
    failed_stage="metadata-update"
  fi

  if [[ -z "$failed_stage" ]]; then
    echo "---> Step 2/3: Running nix flake check ./pkgs/${name}..." | tee -a "$log_file"
    if ! nix flake check "./pkgs/${name}" >> "$log_file" 2>&1; then
      failed_stage="flake-check"
    fi
  fi

  if [[ -z "$failed_stage" ]]; then
    echo "---> Step 3/3: Building .#${name}..." | tee -a "$log_file"
    if ! nix build ".#${name}" --no-link --print-build-logs >> "$log_file" 2>&1; then
      failed_stage="nix-build"
    fi
  fi

  if [[ -n "$failed_stage" ]]; then
    echo "FAILURE: ${name} failed during stage '${failed_stage}'."
    FAILED_FLAKES+=("${name}:${failed_stage}:${script}")
    git checkout -- "pkgs/${name}" 2>/dev/null || true
    git clean -fd "pkgs/${name}" 2>/dev/null || true
    return 0
  fi

  new_version=$(jq -r '.version // "unknown"' "$meta_file" 2>/dev/null || echo "unknown")

  if [[ -n "$(git status --porcelain "pkgs/${name}")" ]]; then
    local commit_msg
    if [[ "$old_version" != "$new_version" ]]; then
      commit_msg="chore(${name}): update to version ${new_version}"
      UPDATED_FLAKES+=("${name} (${old_version} -> ${new_version})")
    else
      commit_msg="chore(${name}): update flake.lock"
      UPDATED_FLAKES+=("${name} (lockfile updated, v${new_version})")
    fi

    if [[ "$DRY_RUN" == "1" ]]; then
      echo "[DRY-RUN] Would commit: ${commit_msg}"
      git checkout -- "pkgs/${name}" 2>/dev/null || true
    else
      git add "pkgs/${name}"
      git commit -m "$commit_msg"
      COMMITS_CREATED=$((COMMITS_CREATED + 1))
      echo "Committed: ${commit_msg}"
    fi
  else
    echo "No changes for ${name} (up to date at ${new_version})."
    UNCHANGED_FLAKES+=("${name} (v${new_version})")
  fi
}

update_root_lock() {
  local log_file="$WORK_DIR/root.log"
  echo "=================================================================="
  echo "Updating root flake.lock and running root nix flake check..."
  echo "=================================================================="

  if nix flake update > "$log_file" 2>&1 && nix flake check >> "$log_file" 2>&1; then
    if [[ -n "$(git status --porcelain flake.lock)" ]]; then
      if [[ "$DRY_RUN" == "1" ]]; then
        echo "[DRY-RUN] Would commit: chore(flake): update root flake.lock"
        git checkout -- flake.lock 2>/dev/null || true
      else
        git add flake.lock
        git commit -m "chore(flake): update root flake.lock"
        COMMITS_CREATED=$((COMMITS_CREATED + 1))
      fi
    fi
  else
    echo "Warning: Root flake update/check encountered an issue; reverting root flake.lock."
    git checkout -- flake.lock 2>/dev/null || true
  fi
}

analyze_failure_with_ai() {
  local name="$1"
  local stage="$2"
  local script="$3"
  local log_file="$WORK_DIR/${name}.log"
  local out_json="$WORK_DIR/${name}_ai.json"

  local log_tail script_content pkg_content meta_content
  log_tail=$(tail -n 120 "$log_file" 2>/dev/null || true)
  script_content=$(cat "$script" 2>/dev/null || true)
  pkg_content=$(cat "pkgs/${name}/package.nix" 2>/dev/null || true)
  meta_content=$(cat "pkgs/${name}/metadata.json" 2>/dev/null || true)

  if [[ -z "$AI_TOKEN" ]]; then
    echo "No GITHUB_TOKEN/GH_TOKEN detected; using structured diagnostic fallback for ${name}."
    jq -n \
      --arg root_cause "Automated update for \`${name}\` failed at stage \`${stage}\`. (AI analysis skipped: no GITHUB_TOKEN provided in environment)." \
      --arg remediation "* Inspect the failure log below for \`${name}\`.\n* Verify upstream release endpoints in \`${script}\` and archive layout in \`pkgs/${name}/package.nix\`." \
      '{
        root_cause: $root_cause,
        suggested_remediation: $remediation,
        can_autofix: false,
        commit_message: "",
        files: []
      }' > "$out_json"
    return 0
  fi

  local system_prompt user_prompt payload response_file http_code
  system_prompt=$(cat <<'EOF'
You are an expert Nix Flake maintainer for an open-source collection of AI agent CLIs and ACP bridges.
Analyze the provided CI flake update/build failure and return a strict JSON object with the following schema:
{
  "root_cause": "Clear explanation of what broke (e.g., upstream URL changed, JSON manifest schema changed, archive binary layout changed, or hash mismatch).",
  "suggested_remediation": "Markdown bullet list (using '*' for bullets and no leading bold text) explaining how to fix the issue.",
  "can_autofix": true or false (set true ONLY if you have high confidence in a concrete code change to the update script or package.nix that resolves the failure),
  "commit_message": "fix(<flake>): concise conventional commit message (if can_autofix is true, else empty string)",
  "files": [
    {
      "path": "relative path (MUST be either scripts/update_<name>.sh or pkgs/<name>/package.nix)",
      "content": "complete, full replacement content of the file"
    }
  ]
}
EOF
)

  user_prompt=$(cat <<EOF
Flake Name: ${name}
Failed Stage: ${stage}

--- Current ${script} ---
${script_content}

--- Current pkgs/${name}/package.nix ---
${pkg_content}

--- Current pkgs/${name}/metadata.json ---
${meta_content}

--- Failure Log (last 120 lines) ---
${log_tail}
EOF
)

  payload=$(jq -n \
    --arg model "$AI_MODEL" \
    --arg sys "$system_prompt" \
    --arg usr "$user_prompt" \
    '{
      model: $model,
      temperature: 0.1,
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: $sys },
        { role: "user", content: $usr }
      ]
    }')

  response_file="$WORK_DIR/${name}_models_resp.json"
  http_code=$(curl -sS -w "%{http_code}" -o "$response_file" \
    -X POST "$MODELS_API_URL" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${AI_TOKEN}" \
    -d "$payload" || echo "000")

  if [[ "$http_code" == "200" ]] && jq -e '.choices[0].message.content | fromjson | .root_cause' "$response_file" >/dev/null 2>&1; then
    jq -r '.choices[0].message.content' "$response_file" | jq '.' > "$out_json"
    echo "GitHub Models AI analysis succeeded for ${name}."
  else
    echo "Warning: GitHub Models API returned HTTP ${http_code} for ${name}. Falling back to log-based report."
    jq -n \
      --arg root_cause "Automated update for \`${name}\` failed during stage \`${stage}\`." \
      --arg remediation "* Check the captured build/update log below.\n* Run \`nix run .#update-${name}\` and \`nix build .#${name}\` locally inside \`nix develop\` to reproduce." \
      '{
        root_cause: $root_cause,
        suggested_remediation: $remediation,
        can_autofix: false,
        commit_message: "",
        files: []
      }' > "$out_json"
  fi
}

attempt_candidate_fix_pr() {
  local name="$1"
  local script="$2"
  local issue_num="$3"
  local ai_json="$WORK_DIR/${name}_ai.json"
  local pr_url_file="$WORK_DIR/${name}_pr_url.txt"

  local can_autofix file_count
  can_autofix=$(jq -r '.can_autofix // false' "$ai_json")
  file_count=$(jq -r '(.files // []) | length' "$ai_json")

  if [[ "$can_autofix" != "true" || "$file_count" -eq 0 ]]; then
    return 0
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    echo "[DRY-RUN] Would create/update candidate fix branch fix/flake-update-${name} and open Draft PR."
    return 0
  fi

  local base_branch fix_branch commit_msg
  base_branch=$(git rev-parse --abbrev-ref HEAD)
  fix_branch="fix/flake-update-${name}"
  commit_msg=$(jq -r --arg def "fix(${name}): automated AI candidate fix for flake update" '
    if (.commit_message // "") != "" then .commit_message else $def end
  ' "$ai_json")

  git checkout -B "$fix_branch"

  local applied_any=0
  while IFS= read -r file_entry; do
    local fpath fcontent
    fpath=$(printf '%s\n' "$file_entry" | jq -r '.path // empty')
    fcontent=$(printf '%s\n' "$file_entry" | jq -r '.content // empty')

    # Strictly restrict AI modifications to the target flake's script or package directory
    if [[ "$fpath" == "$script" || "$fpath" == "pkgs/${name}/"* ]] && [[ -n "$fcontent" ]]; then
      printf '%s\n' "$fcontent" > "$fpath"
      if [[ "$fpath" == scripts/*.sh ]]; then
        chmod +x "$fpath"
      fi
      applied_any=1
    else
      echo "Skipping disallowed or empty AI file path: ${fpath}"
    fi
  done < <(jq -c '.files[]' "$ai_json")

  if [[ "$applied_any" -eq 0 ]]; then
    git checkout "$base_branch"
    return 0
  fi

  local fix_verified="false"
  local verify_log="$WORK_DIR/${name}_fix_verify.log"
  if SKIP_ROOT_LOCK_UPDATE=1 bash "$script" > "$verify_log" 2>&1 \
    && nix flake check "./pkgs/${name}" >> "$verify_log" 2>&1 \
    && nix build ".#${name}" --no-link --print-build-logs >> "$verify_log" 2>&1; then
    fix_verified="true"
  fi

  if [[ -z "$(git status --porcelain)" ]]; then
    git checkout "$base_branch"
    return 0
  fi

  git add "$script" "pkgs/${name}"
  git commit -m "$commit_msg"
  git push --force origin "HEAD:refs/heads/${fix_branch}"

  local pr_body_file="$WORK_DIR/${name}_pr_body.md"
  local verify_badge
  if [[ "$fix_verified" == "true" ]]; then
    verify_badge="Passed (\`update_${name}\`, \`nix flake check\`, and \`nix build .#${name}\` succeeded in CI)"
  else
    verify_badge="Needs manual adjustment (candidate patch generated by AI, but CI build verification still failed)"
  fi

  cat <<EOF > "$pr_body_file"
## Automated AI Candidate Fix for \`${name}\`

cc @${AUTHOR_HANDLE}
Refs #${issue_num}

### Root Cause Analysis

$(jq -r '.root_cause' "$ai_json")

### Verification Status

* CI Verification: ${verify_badge}

### Suggested Remediation Notes

$(jq -r '.suggested_remediation' "$ai_json")
EOF

  local existing_pr pr_url
  existing_pr=$(gh pr list --head "$fix_branch" --state open --json number --jq '.[0].number // empty' 2>/dev/null || true)
  if [[ -n "$existing_pr" ]]; then
    gh pr edit "$existing_pr" --title "$commit_msg" --body-file "$pr_body_file" >/dev/null
    pr_url=$(gh pr view "$existing_pr" --json url --jq '.url')
  else
    pr_url=$(gh pr create --draft --base "main" --head "$fix_branch" --title "$commit_msg" --body-file "$pr_body_file")
  fi

  printf '%s\n' "$pr_url" > "$pr_url_file"
  git checkout "$base_branch"
}

manage_failure_issue() {
  local failed_names=()
  local entry
  for entry in "${FAILED_FLAKES[@]}"; do
    local name="${entry%%:*}"
    failed_names+=("$name")
  done

  local failed_list_str
  failed_list_str=$(IFS=", "; echo "${failed_names[*]}")
  local issue_title="ci(flakes): automated flake update failure (${failed_list_str})"
  local issue_body_file="$WORK_DIR/issue_body.md"
  local run_url=""

  if [[ -n "${GITHUB_SERVER_URL:-}" && -n "${GITHUB_REPOSITORY:-}" && -n "${GITHUB_RUN_ID:-}" ]]; then
    run_url="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"
  fi

  {
    echo "## Automated Daily Flake Update Failure"
    echo ""
    echo "cc @${AUTHOR_HANDLE}"
    echo ""
    echo "One or more Nix flakes failed during the daily automated update and verification workflow."
    echo ""
    echo "### Run Summary"
    echo ""
    echo "* Timestamp (UTC): $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    if [[ -n "$run_url" ]]; then
      echo "* Workflow Run: [View GitHub Actions Run](${run_url})"
    fi
    echo "* Failing Flakes: ${failed_list_str}"
    if [[ ${#UPDATED_FLAKES[@]} -gt 0 ]]; then
      echo "* Successfully Updated Flakes: $(IFS=", "; echo "${UPDATED_FLAKES[*]}")"
    fi
    if [[ ${#UNCHANGED_FLAKES[@]} -gt 0 ]]; then
      echo "* Unchanged Healthy Flakes: $(IFS=", "; echo "${UNCHANGED_FLAKES[*]}")"
    fi
    echo ""

    for entry in "${FAILED_FLAKES[@]}"; do
      local name stage script
      IFS=":" read -r name stage script <<< "$entry"
      local ai_json="$WORK_DIR/${name}_ai.json"
      local log_file="$WORK_DIR/${name}.log"
      local log_tail
      log_tail=$(tail -n 80 "$log_file" 2>/dev/null || true)

      echo "---"
      echo ""
      echo "### Flake: \`${name}\` (Failed Stage: \`${stage}\`)"
      echo ""
      echo "#### AI Root-Cause Analysis"
      echo ""
      jq -r '.root_cause' "$ai_json"
      echo ""
      echo "#### Suggested Remediation"
      echo ""
      jq -r '.suggested_remediation' "$ai_json"
      echo ""
      echo "<details>"
      echo "<summary>Captured Build / Update Log (last 80 lines)</summary>"
      echo ""
      echo '```text'
      printf '%s\n' "$log_tail"
      echo '```'
      echo "</details>"
      echo ""
    done
  } > "$issue_body_file"

  if [[ "$DRY_RUN" == "1" ]]; then
    echo "=================================================================="
    echo "[DRY-RUN] Generated Issue Title: ${issue_title}"
    echo "[DRY-RUN] Generated Issue Body:"
    cat "$issue_body_file"
    echo "=================================================================="
    return 0
  fi

  gh label create "$ISSUE_LABEL" \
    --color "d73a4a" \
    --description "Automated daily flake update failure" \
    --force >/dev/null 2>&1 || true

  local open_issue_num
  open_issue_num=$(gh issue list --label "$ISSUE_LABEL" --state open --limit 1 --json number --jq '.[0].number // empty')

  if [[ -n "$open_issue_num" ]]; then
    echo "Updating existing open issue #${open_issue_num}..."
    gh issue edit "$open_issue_num" --title "$issue_title" --body-file "$issue_body_file"
    gh issue comment "$open_issue_num" --body "cc @${AUTHOR_HANDLE} — Daily flake update check still failing as of $(date -u '+%Y-%m-%d %H:%M:%S UTC') (${failed_list_str}). Issue description has been updated with the latest AI analysis and logs."
  else
    echo "Creating new issue with label '${ISSUE_LABEL}'..."
    local created_url
    created_url=$(gh issue create \
      --title "$issue_title" \
      --body-file "$issue_body_file" \
      --label "$ISSUE_LABEL" \
      --assignee "$AUTHOR_HANDLE" 2>/dev/null || \
      gh issue create \
        --title "$issue_title" \
        --body-file "$issue_body_file" \
        --label "$ISSUE_LABEL")
    open_issue_num="${created_url##*/}"
    echo "Created issue #${open_issue_num}: ${created_url}"
  fi

  # Attempt candidate fix Draft PRs if AI proposed patches
  for entry in "${FAILED_FLAKES[@]}"; do
    local name stage script
    IFS=":" read -r name stage script <<< "$entry"
    attempt_candidate_fix_pr "$name" "$script" "$open_issue_num"
    if [[ -f "$WORK_DIR/${name}_pr_url.txt" ]]; then
      local pr_url
      pr_url=$(cat "$WORK_DIR/${name}_pr_url.txt")
      gh issue comment "$open_issue_num" --body "cc @${AUTHOR_HANDLE} — Opened/updated a candidate Draft Fix PR for \`${name}\`: ${pr_url}"
    fi
  done
}

close_resolved_issue_if_open() {
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "[DRY-RUN] All flakes healthy. Would close any open '${ISSUE_LABEL}' issue if present."
    return 0
  fi

  if [[ -z "$AI_TOKEN" ]]; then
    return 0
  fi

  local open_issue_num
  open_issue_num=$(gh issue list --label "$ISSUE_LABEL" --state open --limit 1 --json number --jq '.[0].number // empty' 2>/dev/null || true)
  if [[ -n "$open_issue_num" ]]; then
    echo "Closing resolved issue #${open_issue_num}..."
    gh issue comment "$open_issue_num" --body "All flake updates and builds succeeded in the latest run ($(date -u '+%Y-%m-%d %H:%M:%S UTC')). Automatically closing this issue."
    gh issue close "$open_issue_num"
  fi
}

# --- Main Execution ---

configure_git_identity

for item in "${FLAKES[@]}"; do
  flake_name="${item%%:*}"
  flake_script="${item#*:}"
  update_single_flake "$flake_name" "$flake_script"
done

update_root_lock

if [[ "$COMMITS_CREATED" -gt 0 && "$DRY_RUN" == "0" ]]; then
  if [[ "${GITHUB_ACTIONS:-false}" == "true" || "${PUSH_CHANGES:-0}" == "1" ]]; then
    echo "Pushing ${COMMITS_CREATED} commit(s) to origin/main..."
    git push origin HEAD:main
  else
    echo "Created ${COMMITS_CREATED} local commit(s). Set PUSH_CHANGES=1 to push outside GitHub Actions."
  fi
fi

if [[ ${#FAILED_FLAKES[@]} -gt 0 ]]; then
  echo "=================================================================="
  echo "Detected ${#FAILED_FLAKES[@]} flake failure(s). Running AI triage..."
  echo "=================================================================="
  for entry in "${FAILED_FLAKES[@]}"; do
    IFS=":" read -r name stage script <<< "$entry"
    analyze_failure_with_ai "$name" "$stage" "$script"
  done
  manage_failure_issue
  exit 1
else
  echo "=================================================================="
  echo "All flakes updated and verified cleanly!"
  echo "=================================================================="
  close_resolved_issue_if_open
fi
