# claude-code-provider-kit Handoff Notes

**Date**: 2026-04-25
**Last PR merged**: #30 — docs: custom agent support across providers
**Sprint 2 closed**: 2026-04-24 — 4/4 stories, 13 pts, PASS

## Current State

All three providers are working end-to-end (validated 2026-04-24):

- **DeepSeek**: `deepseek-chat` (sonnet/haiku/default) and `deepseek-reasoner` (opus) via `hosted_vllm/` prefix, routed through `https://api.deepseek.com/v1`
- **OpenAI**: `gpt-5` (opus), `gpt-5-mini` (sonnet), `gpt-5-nano` (haiku) via `openai/` prefix
- **Gemini**: `gemini-2.5-pro` (opus), `gemini-2.5-flash` (sonnet/haiku) via `gemini/` prefix

ASGI middleware in `start-proxy.py` handles all providers: stripping `context_management`, overriding `thinking` to disabled, stripping thinking blocks from history, stripping remote MCP tools, fixing bare array schemas.

**Custom agent support** (sprint 2): The `morph-session` SessionStart hook enumerates custom agents from `~/.claude/commands/agents/`, parses YAML frontmatter, and injects a catalog + launch convention into session guidance. DeepSeek follows the convention reliably. Gemini works with minor reporting inconsistency. OpenAI is unreliable.

## What's Next

### 1. Harden OpenAI/Gemini launch convention (sprint 3 candidate, HIGH priority)

Both OpenAI and Gemini gravitate toward `subagent_type: Explore` instead of `general-purpose` when the agent's description sounds like exploration. The hook says "only use general-purpose" but the models match semantics over instructions.

**Approach (try in order, stop when it works):**
1. Add negative examples to hook wording: "Even if the agent's description mentions exploration or indexing, always use `general-purpose`" (~15 min, low risk)
2. Re-run 3-provider validation in **git-initialized** directories to isolate wrong-subagent_type from missing-git-repo failures (~30 min). OpenAI's `Explore` choice caused a crash only because the temp dir had no git repo — it might work fine in a real project.
3. If neither fixes OpenAI: middleware interception to catch `Explore` errors and retry with `general-purpose` (higher complexity, defer unless #1-2 fail)

**Evidence**: `sprints/claude-code-bridge/sprint-2/validation-report.md` has full per-provider results.

### 2. CRITICAL: DeepSeek model deprecation (deadline July 24, 2026)

Both `deepseek-chat` and `deepseek-reasoner` are deprecated legacy model names:
- `deepseek-chat` maps to `deepseek-v4-flash` internally
- `deepseek-reasoner` maps to `deepseek-v4-pro` internally (assumption)
- Deadline: July 24, 2026 — after this date, these model names stop working

The V4 model names (`deepseek-v4-flash`, `deepseek-v4-pro`) trigger thinking mode at the DeepSeek API level regardless of endpoint or parameters. When thinking mode is active, DeepSeek returns `reasoning_content` in responses. Claude Code translates this into Anthropic `thinking` blocks, but cannot convert them back to `reasoning_content` on the next turn, causing: "The reasoning_content in the thinking mode must be passed back to the API."

**To fix before July 2026, we need one of**:
- A way to suppress thinking mode on V4 model names (DeepSeek API feature request or undocumented param)
- LiteLLM support for round-tripping `reasoning_content` through the Anthropic passthrough path
- Claude Code support for preserving provider-specific reasoning content across turns
- A middleware solution that captures `reasoning_content` from responses and injects it back into subsequent requests

This is the highest-priority technical risk for the DeepSeek provider.

### 3. Demo GIF for README

Record a 20-30 second terminal demo showing: `./install.sh` → `claude-deepseek` launching → a skill invocation with tier routing visible. Use VHS or asciinema. Place at `docs/assets/demo.gif` and add `![Demo](docs/assets/demo.gif)` below the tagline in README.md.

### 4. Process improvements (from sprint 2 retro)

- Add installed-hook sync check to `/sprint-plan` prerequisites for sprints that modify global hooks
- Add required env var check for sprints needing provider credentials
- Pre-flight environment validation would have saved ~15 min of HITL on story-003

## Resolved (Sprint 2)

### ~~Custom agent definitions not recognized by non-Claude models~~

Resolved via enhanced `morph-session` SessionStart hook (PRs #28, #29). The hook enumerates agents, parses frontmatter, injects catalog + launch convention. Docs updated in PR #30.

**Validation (2026-04-24):** DeepSeek PASS (confirmed twice). Gemini PASS with advisory. OpenAI FAIL (chose wrong subagent_type). Sprint passed 2-of-3 provider bar. Fast-follow candidates above in §1.

## Stale branches (advisory)

4 remote branches from merged PRs can be cleaned up:
- `origin/docs/persist-api-key` (#27), `origin/docs/remove-demo-gif` (#24), `origin/fix/deepseek-reasoning-mode` (#22), `origin/fix/docs-and-permission-mode` (#23)

## Architecture Notes

- `templates/start-proxy.py` — ASGI middleware wrapping LiteLLM via uvicorn.run monkey-patch. This is the only reliable interception point for Anthropic-format requests (LiteLLM's callback hooks don't fire in the passthrough path).
- `hosted_vllm/` prefix — bypasses LiteLLM's provider-specific logic entirely, using generic OpenAI-compatible handling. This is why DeepSeek works — it avoids both the beta endpoint and the thinking param handling.
- `drop_params: true` and `modify_params: true` in `litellm.base.yaml` — these DON'T work in the Anthropic passthrough path. The middleware handles what they can't.
- `templates/hooks/morph-session` — SessionStart hook. Non-Claude models get guidance injection (agent conventions, subagent patterns, custom agent catalog). Claude-native models get no-op path. Uses `jq -n --arg` for JSON-safe output.

## Key Debugging Lessons

- The shell functions (`claude-deepseek` etc.) reuse an existing LiteLLM proxy on the default port instead of restarting it. When iterating on `start-proxy.py`, always kill the existing proxy first: `kill $(lsof -i :4000 -t)`.
- When testing the installed hook, always diff against the template first: `diff templates/hooks/morph-session ~/.claude/hooks/morph-session`. Stale hooks silently validate old behavior.
- Use `claude-deepseek -p "prompt"` for non-interactive validation. The `-p` mode shows the model's text summary but not raw tool call JSON — keep this in mind when evaluating whether a model followed the launch convention.
