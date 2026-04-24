# claude-code-bridge

Run your existing Claude Code skills on DeepSeek, OpenAI, and Gemini — same skills, same hooks, same workflows, different model.

## The problem

Claude Code has the best agent runtime for developers: skills, subagents, hooks, MCP servers, per-skill model routing. But it only officially supports Anthropic models. If you want to run your skill library against a cheaper model (DeepSeek V4 at roughly 10x less than Claude Opus) or a specialty model (Gemini's 1M+ token context window), you're on your own. That means reverse-engineering env vars, standing up a proxy, writing hooks, and guessing tier mappings.

**claude-code-bridge** is a configuration kit that handles all of that. One install, pick your provider, and your entire skill library works.

## Quick start

```bash
# 1. Install LiteLLM (the only dependency)
pip install 'litellm[proxy]==1.63.2'

# 2. Clone and install
git clone https://github.com/shinytoyrobots/claude-code-bridge.git
cd claude-code-bridge
./install.sh

# 3. Set your API key and go
export DEEPSEEK_API_KEY="your-key-here"
claude-deepseek
```

That's it. Your skills, hooks, and MCP servers all work — `model: opus` in frontmatter routes to the provider's flagship, `model: sonnet` to the workhorse, `model: haiku` to the cheap tier.

## How it works

claude-code-bridge sits between Claude Code and your chosen provider:

```text
Claude Code  →  LiteLLM proxy  →  Provider API
(your skills)   (format translation)  (DeepSeek/OpenAI/Gemini)
```

- **LiteLLM** translates Claude Code's Anthropic wire format to the provider's native API
- **Shell functions** (`claude-deepseek`, `claude-openai`, `claude-gemini`) start the proxy and launch Claude Code with the right env vars
- **A SessionStart hook** detects non-Claude execution and briefs the model on Claude Code's tool-use idioms
- **Tier mapping** routes `opus`/`sonnet`/`haiku` aliases to provider-appropriate models

## Supported providers

| Provider | Opus | Sonnet | Haiku | Notes |
|----------|------|--------|-------|-------|
| **DeepSeek** | deepseek-v4-pro | deepseek-v4-flash | deepseek-v4-flash | Validated end-to-end with complex multi-agent skills |
| **OpenAI** | gpt-5 | gpt-5-mini | gpt-5-nano | [Sonnet slot is ambiguous](docs/tier-mapping.md) — consider o3/o4 for reasoning |
| **Gemini** | gemini-2.5-pro | gemini-2.5-flash | gemini-2.5-flash | Best for long-context tasks (1M+ tokens) |

Sonnet and Haiku map to the same model for DeepSeek and Gemini because those providers have two meaningful tiers, not three. See [tier mapping](docs/tier-mapping.md) for the full rationale and how to override.

## Provider setup guides

- [DeepSeek setup](docs/setup-deepseek.md) — the most tested path; start here
- [OpenAI setup](docs/setup-openai.md)
- [Gemini setup](docs/setup-gemini.md)

## What you need to know

- **Permission mode**: Claude Code uses its normal interactive permission mode (`default`) with non-Anthropic models. The only mode that is blocked is `auto`. You can pass any supported mode explicitly: `claude-deepseek --permission-mode dontAsk`.
- **Skill compatibility**: Skills that rely on Claude-specific behavior (extended thinking, specific tool-calling quirks) may degrade on other models. Most skills work unchanged.
- **LiteLLM is required**: Claude Code speaks Anthropic wire format exclusively. LiteLLM translates. There is no way around this dependency for OpenAI-format providers.
- **The hook is optional but recommended**: The SessionStart hook (`morph-session`) helps non-Claude models understand Claude Code's Agent tool, subagent patterns, and skill frontmatter. Without it, models may fumble on tool calls.

## Troubleshooting

See the [troubleshooting guide](docs/troubleshooting.md) for common issues:

- "auto mode unavailable" error
- Model not found / 404 from provider
- LiteLLM port collision (default: 4000)
- API key not set
- How to verify which model is answering

## Project scope

This is a configuration kit, not a runtime. It ships shell scripts, YAML templates, and documentation. It does not make API calls, does not wrap Claude Code, and has no dependencies beyond LiteLLM.

**Not in scope for v1**: Mistral, Qwen, Grok, Fish shell, Windows, a GUI, plugin marketplace packaging. See [CONTRIBUTING.md](CONTRIBUTING.md) for what's in scope.

## License

[MIT](LICENSE) — Robin Cannon

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Scope is intentionally narrow: provider configs, shell templates, installer, hook, docs.
