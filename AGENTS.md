# AGENTS.md - Agent Flakes Collection

This repository is a collection of Nix Flakes for various agent CLIs and
associated ACP support. It follows a modular architecture that supports both
standalone usage of individual tools and aggregate management through a root
flake.

## Setup & Build Commands

### Environment

* Development Shell: Use `nix develop` in the root directory to get a shell with
  required commands, e.g., `jq`, `curl`, `nix`, `git` etc..
* Nix Version: Requires Nix with `flakes` and `nix-command` experimental
  features enabled.
* Tooling Consistency: Always use tools provided by the root `flake.nix` dev
  shell (`buildInputs`). Avoid using global or system-wide versions of these
  tools. If a new tool is required for maintenance, add it to the
  `devShells.default` in the root `flake.nix`.

### Building

* Build Agent: `nix build .#<agent-name>` from the root or `nix build
  .#<agent-name> --flake pkgs/<agent-name>` from anywhere.
* Pure Evaluation: Root builds should be pure. To support pure evaluation of
  unfree packages (e.g., Junie, Cortex Code), we use `allowUnfreePredicate` in the
  flake outputs. This allows users to build and run these specific packages
  without requiring `--impure` or global `allowUnfree` settings.
* Explicit Consent: By using these flakes, users acknowledge the unfree licenses
  of the included agents. The `allowUnfreePredicate` is scoped specifically to
  the agents managed by this repository; this MUST be communicated clearly both
  in the `README.md` (tabular overview with link to original agent's license) and
  in the agent specific `pkgs/<agent-name>/README.md` in the agent flake's sub-folder

## Testing & Validation

* Binary Check: After building, verify the binary runs:
  `./result/bin/<agent-name> --help`.
* Warning Hygiene: Always investigate and fix warnings during evaluation and
  building (e.g., deprecated `pkgs.system` vs `pkgs.stdenv.hostPlatform.system`,
  or deprecated CLI flags). Ensure local flake settings do not trigger
  unnecessary warnings.
* Wrapper Verification: Ensure required environment variables (e.g., data
  directories or runner paths) are correctly set by the wrapper.
* Flake Check: Run `nix flake check` in the root and in `pkgs/<agent-name>/` to
  ensure structural integrity.

## Code Style & Architecture Conventions

### Markdown Format

* use `*` for bullet point lists
* avoid bold face as leading element in bullet point lists; where applicable,
  use sub-headings

### Repository Structure

* Root: Management aggregate and repository-wide tools.
* `pkgs/<agent-name>/`: Self-contained directory for repository-managed agent flakes (e.g., `pkgs/junie/`, `pkgs/cortex-code/`).
* `pkgs/<agent-name>-acp/`: Self-contained directory for standalone ACP companion bridge flakes (e.g., `pkgs/antigravity-acp/`, `pkgs/codex-acp/`).
* `pkgs/<tool-name>/`: Self-contained directory for standalone agent utilities and gateways (e.g., `pkgs/air-gateway/`).
* `scripts/`: Automation scripts for metadata updates.

### Architectural Principles & Models

This repository follows four core architectural principles:
* Upstream Respect & Minimal Duplication: We do not re-package agent CLIs that are already provided by upstream Home Manager. If an upstream agent also natively supports ACP (e.g., OpenCode via `opencode acp`), no package or flake is maintained here.
* Gap Fulfillment: We only introduce flakes where upstream Home Manager has a functional gap: packaging the agent CLI itself when absent upstream (Integrated Agent Flake), packaging the external ACP companion bridge when the upstream agent lacks native ACP support (Standalone ACP Bridge Flake), or packaging standalone agent utilities/gateways not available upstream (Standalone Agent Utility Flake).
* Uniform ACP Client Contract: Regardless of whether ACP is implemented natively or through an external bridge, companion Home Manager modules expose a uniform read-only interface (`command`, `args`, `env`) so editor integrations (e.g., Zed, Emacs, Neovim) can consume any agent's ACP server seamlessly.
* Pure Evaluation: Derivations must never perform network operations at build time. Prebuilt binaries and npm/PyPI distribution packages must be locked with fixed-output hashes in `metadata.json`.

#### Pattern 1: Integrated Agent Flakes (`pkgs/<agent-name>/`)

Used for agents whose CLI is not packaged in the upstream Home Manager distribution (e.g., Junie, Cortex Code). The sub-flake encapsulates both the agent CLI and declarative ACP enablement:
* `package.nix`: Core agent CLI derivation using `pkgs.stdenv.mkDerivation` (assume upstream binaries are statically linked or self-contained unless a specific agent requires dynamic linking).
* `acp.nix`: Optional internal derivation for agents requiring an external ACP bridge executable according to the ACP Registry. Not exposed as a standalone flake package output; consumed internally by `module.nix` when `programs.<agent>.acp.enable = true`.
* `module.nix`: Home Manager module definition exposing a uniform interface across repository-managed agents:
  * `enable`: Installs the agent CLI package.
  * `package`: The agent CLI derivation.
  * `settings`: Declarative configuration (`pkgs.formats.json` or `toml`), materialized via `home.file` when `settings != {}`.
  * `acp.enable`: Enables ACP support. Installs the internal `acp.nix` companion package into `home.packages` if `metadata.acp.mode == "external"`, or acts as a package no-op if `metadata.acp.mode == "internal"`.
  * `acp.command`, `acp.args`, `acp.env`: Read-only options resolved from the installed package and `metadata.acp`, allowing downstream Home Manager configurations (e.g., Zed, Emacs, Neovim) to wire up the agent's ACP server seamlessly regardless of whether ACP is native or bridged.
* `outputs.nix`: Shared `utils.lib.eachSystem` logic (iterating over `builtins.attrNames metadata.systems`) exposing `packages.<agent>`, `packages.default`, `homeManagerModules.<agent>`, `homeManagerModules.default`, `overlays.<agent>`, and `overlays.default`.
* `metadata.json`: Version, binary info (URLs/Hashes), and internal/external ACP configuration.

#### Pattern 2: Standalone ACP Bridge Flakes (`pkgs/<agent-name>-acp/`)

Used for agents that already have a dedicated CLI package and module in upstream Home Manager, but require a companion ACP bridge according to the ACP Registry (e.g., Antigravity, Codex):
* Upstream Native ACP Exemption: If an agent already has an upstream Home Manager module and natively implements ACP (e.g., OpenCode via `opencode acp`), no package or sub-flake is created in this repository.
* `package.nix`: Core ACP bridge derivation unpacking prebuilt binaries or building a wrapper from locked npm/PyPI tarballs.
* `module.nix`: Home Manager companion module extending or complementing the agent's configuration:
  * `programs.<agent>.acp.enable` (and `programs.<agent>-acp.enable` alias): Adds the bridge package to `home.packages`.
  * `programs.<agent>.acp.package`: The ACP bridge package derivation.
  * `programs.<agent>.acp.command`, `programs.<agent>.acp.args`, `programs.<agent>.acp.env`: Read-only options pointing to the bridge executable, arguments, and environment variables for downstream editor consumption.
* `outputs.nix`: Shared `utils.lib.eachSystem` logic exposing `packages.<agent>-acp`, `packages.default`, `homeManagerModules.<agent>-acp`, `homeManagerModules.default`, `overlays.<agent>-acp`, and `overlays.default`.
* `metadata.json`: ACP bridge version, registry ID, distribution type, download URLs/hashes, executable command, arguments, and environment variables.

#### Pattern 3: Standalone Agent Utilities & Gateways (`pkgs/<tool-name>/`)

Used for standalone agent infrastructure utilities, proxies, or gateways (e.g., JetBrains Air Gateway in `pkgs/air-gateway/`) that configure or route traffic for multiple agent harnesses rather than acting as an agent or ACP server themselves:
* `package.nix`: Core utility derivation unpacking platform binaries and providing any appropriate CLI aliases.
* `module.nix`: Home Manager module exposing `programs.<tool-name>` (`enable`, `package`, `settings`).
  * Mutable Configuration Merging: When a utility stores runtime secrets or session state in the same configuration file as user settings (e.g., `central` writing `proxy_secret` and `ai_access` to `~/.jetbrains-central/config.json`), use a `home.activation` script with `jq` to merge `settings` in-place rather than replacing the file with a read-only `home.file` store symlink. Where applicable, pin self-update channels (e.g., `release_track = cfg.package.version`) by default so updates remain managed by Nix.
* `outputs.nix`: Shared `utils.lib.eachSystem` logic exposing `packages.<tool-name>`, `packages.default`, `homeManagerModules.<tool-name>`, `homeManagerModules.default`, `overlays.<tool-name>`, and `overlays.default`.
* `metadata.json`: Tool version and platform binary URLs/hashes (no `acp` block).

### Metadata & ACP Support

* Metadata Format: Always use `metadata.json` for binary and ACP info. Nix imports this
  via `builtins.fromJSON (builtins.readFile ./metadata.json)`.
* ACP Registry Source: Use the official [ACP Registry](https://github.com/agentclientprotocol/registry)
  (and its live index at `https://cdn.agentclientprotocol.com/registry/v1/latest/registry.json`)
  as the single source of truth for ACP support.
* Pattern 1 Schema (Integrated Agent):
  ```json
  {
    "version": "1.2.3",
    "systems": {
      "x86_64-linux": { "url": "...", "sha256": "..." },
      "aarch64-linux": { "url": "...", "sha256": "..." },
      "aarch64-darwin": { "url": "...", "sha256": "..." }
    },
    "acp": {
      "registryId": "<registry-id>",
      "mode": "internal",
      "command": "<binary-name>",
      "args": ["--acp"],
      "env": {}
    }
  }
  ```
  When `acp.mode` is `"external"`, include `version`, `distribution` (`binary`, `npx`, or `uvx`), and fixed-output `systems` (or tarball/wheel URL + `sha256`) inside the `acp` object.
* Pattern 2 Schema (Standalone ACP Bridge):
  ```json
  {
    "version": "1.4.1",
    "registryId": "<agent-name>-acp",
    "distribution": "binary",
    "systems": {
      "x86_64-linux": { "url": "...", "sha256": "..." },
      "aarch64-linux": { "url": "...", "sha256": "..." },
      "aarch64-darwin": { "url": "...", "sha256": "..." }
    },
    "command": "<bridge-binary-name>",
    "args": [],
    "env": {}
  }
  ```
  For npm/PyPI bridges, specify `tarball` (or `wheel`) and `sha256` under `distribution` instead of platform-specific archives.
* Pattern 3 Schema (Standalone Agent Utility / Gateway):
  ```json
  {
    "version": "1.14.0",
    "systems": {
      "x86_64-linux": { "url": "...", "sha256": "..." },
      "aarch64-linux": { "url": "...", "sha256": "..." },
      "aarch64-darwin": { "url": "...", "sha256": "..." }
    }
  }
  ```
* Code Reuse: Root `flake.nix` and sub-flakes both import and call shared `outputs.nix` files.

## Adding a New Agent, ACP Bridge, or Utility

To add agent tooling to this collection, follow this decision tree:

### 1. Upstream & Registry Check

* Determine Tool Category: Check whether the tool is an agent CLI, an ACP bridge, or a standalone agent utility/gateway.
* Check Upstream Home Manager: Determine whether the tool or agent CLI is already packaged and maintained in the upstream Home Manager distribution.
* Check ACP Registry: For agents, inspect `https://github.com/agentclientprotocol/registry` (`registry.json`) to determine whether ACP is native or bridged.
  * If agent is in upstream Home Manager and supports ACP natively (e.g., OpenCode): Do not create a flake. Upstream Home Manager satisfies all requirements.
  * If agent is in upstream Home Manager and requires an external bridge: Create a Standalone ACP Bridge Flake (`pkgs/<name>-acp/`) using Pattern 2.
  * If agent is not in upstream Home Manager: Create an Integrated Agent Flake (`pkgs/<name>/`) using Pattern 1.
  * If tool is a standalone agent gateway or harness utility not in upstream Home Manager (e.g., Air Gateway): Create a Standalone Agent Utility Flake (`pkgs/<name>/`) using Pattern 3.

### 2. Implement Sub-Flake

* Create Directory: `mkdir -p pkgs/<name>` (or `pkgs/<name>-acp`)
* Initialize Metadata: Create `metadata.json` matching Pattern 1, Pattern 2, or Pattern 3 schema.
* Implement Derivations: Create `package.nix` (and internal `acp.nix` if Pattern 1 with external ACP). Ensure derivations use `pkgs.stdenv.hostPlatform.system`.
* Implement Module: Create `module.nix` providing either `programs.<name>` (Pattern 1 / Pattern 3) or `programs.<name>.acp` / `programs.<name>-acp` (Pattern 2).
* Define Outputs: Create `outputs.nix` exposing `packages`, `devShells`, `homeManagerModules`, and `overlays`.
* Create Sub-Flake: Create `flake.nix` importing `outputs.nix`.

### 3. Register in Root Flake & Documentation

* Root Flake Registration: Import `outputs.nix` in root `flake.nix`, register packages, Home Manager modules, overlays, and add any unfree package names to `allowUnfreePredicate`.
* Create Update Script: Add `scripts/update_<name>.sh` (or `scripts/update_<name>_acp.sh`) using `jq` and fixed-output hashes.
* Register Update App: Add an app in root `flake.nix` using `mkUpdateApp` and chain into `update-flakes`.
* Update Skill & Documentation: Update the reference table in `.agents/skills/update-agent-flake/SKILL.md` and the status table in `README.md`.

## Maintenance & Updates

### Automated Updates

* Update App: Run `nix run .#update-<name>` (or `nix run .#update-<name>-acp`) to fetch the latest version info and update locks.
* Script Convention: Update scripts should be placed in `scripts/`, use `jq` for robust JSON handling, and update both sub-flake and root flake locks.
* Skill Maintenance: Maintain the unified `.agents/skills/update-agent-flake` skill when adding or updating flakes in this collection.

## Commit Guidelines

* Format: Use Conventional Commits.
* Examples:
  * `feat(junie): add aarch64-darwin support`
  * `chore(junie): update to version 888.195`
  * `refactor: move metadata to json`

## Security Considerations

* Credentials: Never include API keys or credentials in the repository.
* Unfree Software: Clearly mark unfree licenses in the `meta` section of
  derivations.
* Purity: Always use fixed-output hashes (`sha256`) for downloads. Never perform
  network operations inside a derivation's build phase.
