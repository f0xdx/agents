# Contributing to Agent Flakes

Thank you for your interest in contributing to this collection of Nix Flakes for AI coding agents, Agent Client Protocol (ACP) bridges, and agent gateways. This document outlines the architectural principles, maintenance workflows, and guidelines for adding or updating packages.

## Architectural Principles

This repository follows four core principles to stay maintainable and composable with the broader Nix ecosystem:

### Upstream Respect and Minimal Duplication

We do not re-package agent CLIs that are already maintained in upstream Home Manager. If an upstream agent also natively supports ACP (for example, OpenCode via `opencode acp`), no package or flake is maintained here.

### Gap Fulfillment

We only introduce flakes where upstream Home Manager has a functional gap:

* Packaging the agent CLI itself when absent upstream (Pattern 1: Integrated Agent Flake)
* Packaging the external ACP companion bridge when an upstream agent lacks native ACP support (Pattern 2: Standalone ACP Bridge Flake)
* Packaging standalone agent utilities or gateways not available upstream (Pattern 3: Standalone Agent Utility Flake)

### Uniform ACP Client Contract

Regardless of whether ACP is implemented natively by an agent or provided through an external bridge, companion Home Manager modules expose a uniform read-only interface (`programs.<agent>.acp.command`, `args`, `env`) so editor integrations (such as Zed, Neovim, or Emacs) can wire up any agent's ACP server seamlessly.

### Pure Evaluation

Derivations must never perform network operations at build time. All prebuilt binaries and npm/PyPI distribution tarballs are locked with fixed-output SHA-256 hashes in each package's `metadata.json`.

---

## Development Setup

### Prerequisites

* Nix with `flakes` and `nix-command` experimental features enabled (`x86_64-linux`, `aarch64-linux`, or `aarch64-darwin`)

### Entering the Development Shell

Always use the tools provided by the root development shell (`jq`, `curl`, `nix`, `git`, `gh`, `gnused`, `gnugrep`, `gawk`, `findutils`) rather than relying on host-installed utilities:

```bash
nix develop
```

### Building and Verifying Packages

To build an individual package from the root flake:

```bash
nix build .#junie
./result/bin/junie --help
```

To build a sub-flake in isolation:

```bash
nix build ./pkgs/junie
```

To run structural and evaluation checks across the repository and a sub-flake:

```bash
nix flake check
nix flake check ./pkgs/junie
```

---

## Updating Packages

Each package stores its version, platform download URLs, SHA-256 hashes, and ACP metadata in `pkgs/<name>/metadata.json`. Update scripts live in `scripts/` and are exposed as Nix flake apps.

### Updating All Flakes

To update all sub-flakes and refresh the root `flake.lock` in one command:

```bash
nix run .#update-flakes
```

### Updating a Single Flake

To update a specific package and refresh locks:

```bash
nix run .#update-junie
nix run .#update-cortex-code
nix run .#update-air-gateway
nix run .#update-antigravity-acp
nix run .#update-codex-acp
```

### Automated Daily CI and AI Triage

A scheduled GitHub Actions workflow ([`.github/workflows/update-flakes.yml`](./.github/workflows/update-flakes.yml)) runs daily at `06:00 UTC` via `nix run .#ci-update-flakes`:

* Updates each sub-flake in isolation and verifies it with `nix flake check ./pkgs/<name>` and `nix build .#<name>`
* Commits and pushes passing updates directly to `main`, reverting and isolating any failing flake so healthy packages are never blocked
* Invokes the GitHub Models API (`openai/gpt-4o`) on failure to diagnose the root cause from build logs and repository files
* Maintains at most one open tracking issue labeled `flake-update-failure` (auto-closing it once all flakes recover)
* Opens or updates a verified Draft Fix PR (`fix/flake-update-<name>`) when an automated fix passes `nix flake check` and `nix build`

You can test the CI orchestration locally without pushing commits or opening GitHub issues/PRs using `--dry-run`:

```bash
nix run .#ci-update-flakes -- --dry-run
```

---

## Adding a New Package

Before adding a new package, consult the [ACP Registry](https://github.com/agentclientprotocol/registry) (`https://cdn.agentclientprotocol.com/registry/v1/latest/registry.json`) and upstream Home Manager to select the appropriate pattern:

| Scenario | Pattern | Directory |
|---|---|---|
| Agent CLI is not in upstream Home Manager | Pattern 1: Integrated Agent Flake | `pkgs/<agent-name>/` |
| Agent CLI is in upstream Home Manager, but requires an external ACP bridge | Pattern 2: Standalone ACP Bridge Flake | `pkgs/<agent-name>-acp/` |
| Tool is a standalone agent gateway or proxy utility | Pattern 3: Standalone Agent Utility Flake | `pkgs/<tool-name>/` |

### Implementation Checklist

1. Create the sub-flake directory under `pkgs/<name>/` with:
   * `metadata.json` containing locked versions, per-system URLs/hashes (`x86_64-linux`, `aarch64-linux`, `aarch64-darwin`), and ACP configuration (if applicable)
   * `package.nix` (and optional internal `acp.nix` for Pattern 1 agents with external ACP bridges) using `pkgs.stdenv.hostPlatform.system`
   * `module.nix` exposing the Home Manager module options
   * `outputs.nix` exporting `packages`, `devShells`, `homeManagerModules`, and `overlays`
   * `flake.nix` importing `./outputs.nix`
   * `README.md` documenting standalone usage, Home Manager configuration, and upstream license terms
2. Register the new sub-flake in the root [`flake.nix`](./flake.nix):
   * Import `./pkgs/<name>/outputs.nix`
   * Expose its `packages`, `homeManagerModules`, and `overlays`
   * If the package is unfree, add its derivation name to `allowUnfreePredicate` and document the license in [`README.md`](./README.md)
3. Add an update script in `scripts/update_<name>.sh`:
   * Guard the trailing root `nix flake update` with `if [[ "${SKIP_ROOT_LOCK_UPDATE:-0}" != "1" ]]; then nix flake update; fi`
   * Register `update-<name>` in `flake.nix`, add it to `update-flakes`, and include it in `FLAKES` inside [`scripts/ci_update_and_triage.sh`](./scripts/ci_update_and_triage.sh)
4. Verify with `nix flake check`, `nix flake check ./pkgs/<name>`, and `nix build .#<name>`.

---

## Code Style and Commit Conventions

### Nix and Shell Guidelines

* Ensure evaluations and builds produce zero Nix warnings (use `pkgs.stdenv.hostPlatform.system` rather than `pkgs.system`)
* Keep all shell scripts compatible with `shellcheck` (enforced automatically by `pkgs.writeShellApplication` during `nix flake check`)
* Never embed credentials, tokens, or network calls inside Nix build phases

### Markdown Style

* Use `*` for bullet point lists
* Avoid bold face as the leading element in bullet point lists; use sub-headings where hierarchy is needed

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

* `feat(junie): add aarch64-darwin support`
* `chore(cortex-code): update to version 1.2.41`
* `fix(ci): handle empty upstream hash response`
