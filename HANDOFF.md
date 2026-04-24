# claude-code-bridge Handoff Notes

**Date**: 2026-04-24
**Last PR merged**: #22 — fix(deepseek): bypass LiteLLM DeepSeek provider

## Current State

All three providers are working end-to-end (validated 2026-04-24):

- **DeepSeek**: `deepseek-chat` (sonnet/haiku/default) and `deepseek-reasoner` (opus) via `hosted_vllm/` prefix, routed through `https://api.deepseek.com/v1`
- **OpenAI**: `gpt-5` (opus), `gpt-5-mini` (sonnet), `gpt-5-nano` (haiku) via `openai/` prefix
- **Gemini**: `gemini-2.5-pro` (opus), `gemini-2.5-flash` (sonnet/haiku) via `gemini/` prefix

ASGI middleware in `start-proxy.py` handles all providers: stripping `context_management`, overriding `thinking` to disabled, stripping thinking blocks from history, stripping remote MCP tools, fixing bare array schemas.

## Immediate Next Steps

### 1. Demo GIF for README

Record a 20-30 second terminal demo showing: `./install.sh` → `claude-deepseek` launching → a skill invocation with tier routing visible. Use VHS or asciinema. Place at `docs/assets/demo.gif` and add `![Demo](docs/assets/demo.gif)` below the tagline in README.md.

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

## Architecture Notes

- `templates/start-proxy.py` — ASGI middleware wrapping LiteLLM via uvicorn.run monkey-patch. This is the only reliable interception point for Anthropic-format requests (LiteLLM's callback hooks don't fire in the passthrough path).
- `hosted_vllm/` prefix — bypasses LiteLLM's provider-specific logic entirely, using generic OpenAI-compatible handling. This is why DeepSeek works — it avoids both the beta endpoint and the thinking param handling.
- `drop_params: true` and `modify_params: true` in `litellm.base.yaml` — these DON'T work in the Anthropic passthrough path. The middleware handles what they can't.

## Key Debugging Lesson

The shell functions (`claude-deepseek` etc.) reuse an existing LiteLLM proxy on the default port instead of restarting it. When iterating on `start-proxy.py`, always kill the existing proxy first: `kill $(lsof -i :4000 -t)`. Multiple debugging sessions were wasted because stale proxy code was running.
