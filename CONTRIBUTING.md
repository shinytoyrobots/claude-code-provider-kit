# Contributing to claude-code-bridge

Thanks for your interest in contributing. This project is an opinionated, small-scope configuration kit for running Claude Code against non-Anthropic models. Scope is intentionally narrow — provider configs, shell templates, installer, hook, docs. Not-in-scope contributions (a GUI, new runtimes, a Python CLI wrapper) are unlikely to be merged; open an issue first to discuss.

## Pull requests

- Target `main` via a feature branch named `{type}/{story-id}-{slug}` where `type` is one of `feat`, `fix`, `refactor`, `test`, `docs`, `chore`.
- One logical change per PR. Commits follow the Conventional Commits format.
- Every `.sh` file and the `morph-session` hook MUST pass ShellCheck with zero errors.
- Markdown files MUST pass markdownlint with the project's `.markdownlint.json` config.
- All prose uses American English spelling (`color`, `organize`, not `colour`, `organise`). CI runs `codespell` to enforce this.
- New behavior requires a corresponding update to the relevant `docs/*.md` file.
- Do not commit secrets. `.env.example` documents env var names only; real values live in your shell environment.

## Reporting issues

Open a GitHub Issue with: your shell (zsh/bash), OS (macOS/Linux), Claude Code version, LiteLLM version, and the exact command + output that failed. Include your provider yaml (with API keys redacted) if the issue is provider-specific.
