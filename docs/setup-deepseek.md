# DeepSeek Setup Guide

> **Recommended for first-time users.** DeepSeek is the most-validated provider path — the author ran complex multi-agent skills (including `/dr-research`) end-to-end against DeepSeek before building this kit.

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed and working
- [LiteLLM](https://docs.litellm.ai/) installed: `pip install 'litellm[proxy]==1.63.2'`
- A DeepSeek API key from [platform.deepseek.com](https://platform.deepseek.com)

## API key setup

1. Sign up at [platform.deepseek.com](https://platform.deepseek.com) and generate an API key
2. Export it in your shell:

```bash
export DEEPSEEK_API_KEY="your-key-here"
```

Add this to your `~/.zshrc` or `~/.bashrc` to persist across sessions.

## Install

```bash
git clone https://github.com/shinytoyrobots/claude-code-provider-kit.git
cd claude-code-provider-kit
./install.sh --providers deepseek
```

Or install all providers at once with `./install.sh`.

## First run

```bash
claude-deepseek
```

This starts the LiteLLM proxy (if not already running), exports the correct environment variables, and launches Claude Code. To verify the right model is answering:

```bash
claude-deepseek -p "What model are you? Reply with just your model name."
```

You should see a response identifying a DeepSeek model.

## Tier mapping

| Claude Code tier | DeepSeek model | Use case |
|------------------|----------------|----------|
| `opus` | deepseek-reasoner | Flagship — reasoning-focused model |
| `sonnet` | deepseek-chat | Workhorse — general-purpose, fast responses |
| `haiku` | deepseek-chat | Cheap — same as Sonnet (DeepSeek has two tiers) |

Sonnet and Haiku both map to `deepseek-chat` because DeepSeek has two meaningful tiers. Using `deepseek-reasoner` for the Sonnet slot would roughly double the cost of most skill calls without meaningful quality improvement for routine work.

To override: edit `providers/deepseek.yaml` and change the `model_name` alias mappings. See [tier mapping](tier-mapping.md) for details.

## Deprecation warning

The `deepseek-chat` and `deepseek-reasoner` model names are legacy identifiers that DeepSeek plans to deprecate on **July 24, 2026**. The V4 replacements (`deepseek-v4-pro`, `deepseek-v4-flash`) exist but currently trigger unresolvable reasoning-mode errors through LiteLLM's provider path.

We're actively working on V4 configuration. Once resolved, the provider config will update to V4 names. In the meantime, the legacy names work correctly.

## Known limitations

- **Validated end-to-end**: This is the most-tested path. No known issues with standard skill execution.
- **Extended thinking**: DeepSeek models don't support Claude's extended thinking feature. Skills that rely on `thinking` blocks will degrade gracefully (the model simply skips them).
- **Parallel subagents**: Non-Claude models handle sequential subagent orchestration more reliably than parallel. The SessionStart hook advises the model to prefer sequential launches.

## Troubleshooting

See the [troubleshooting guide](troubleshooting.md) for common issues.
