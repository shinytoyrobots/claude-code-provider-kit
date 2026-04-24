# Contributing to claude-code-bridge

Thanks for your interest in contributing. This project is an opinionated, small-scope configuration kit for running Claude Code against non-Anthropic models.

## What's in scope

- Provider configs (YAML templates for LiteLLM)
- Shell function templates (bash + zsh)
- The `install.sh` installer
- The `morph-session` SessionStart hook
- Documentation (`README.md`, `docs/*.md`)
- CI workflow (`.github/workflows/ci.yml`)

## What's not in scope

These are unlikely to be merged. Open an issue first to discuss.

- New runtimes or CLI wrappers (Python, Node, etc.)
- GUI or TUI interfaces
- Fish shell, nushell, or Windows support
- Plugin marketplace packaging
- Providers beyond DeepSeek, OpenAI, and Gemini (for v1)

## Pull requests

- Target `main` via a feature branch named `{type}/{slug}` where `type` is one of `feat`, `fix`, `refactor`, `test`, `docs`, `chore`.
- One logical change per PR. Commits follow the Conventional Commits format.
- New behavior requires a corresponding update to the relevant `docs/*.md` file.
- Do not commit secrets. `.env.example` documents env var names only; real values live in your shell environment.

### CI checks that must pass

Every PR runs four CI jobs (see `.github/workflows/ci.yml`):

- **ShellCheck**: every `.sh` file and the `morph-session` hook must pass with zero errors.
- **markdownlint**: `README.md` and `docs/*.md` must pass with the project's `.markdownlint.json` config.
- **codespell**: all `.md`, `.sh`, `.yaml`, and `.txt` files are spell-checked. American English only (`color`, `organize`, not `colour`, `organise`). Update `.codespell.cfg` if you need to add an ignore word.
- **Install dry-run**: `install.sh --dry-run` output must match the golden file at `.github/fixtures/install-dry-run.golden.txt`. If you change the installer's output, update the golden file in the same PR.

## Reporting issues

Open a GitHub Issue with: your shell (zsh/bash), OS (macOS/Linux), Claude Code version, LiteLLM version, and the exact command + output that failed. Include your provider YAML (with API keys redacted) if the issue is provider-specific.
