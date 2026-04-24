# claude-code-provider-kit

Run Claude Code with DeepSeek, OpenAI, or Gemini — your skills, hooks, and agents actually work, at up to 10x lower cost.

<!-- Demo GIF — uncomment when recorded:
  ![Demo](docs/assets/demo.gif)
  Storyboard:
  1. Terminal: run `./install.sh` — shows files being written
  2. Terminal: run `claude-deepseek` — LiteLLM starts, Claude Code launches
  3. Claude Code: invoke a real skill with `model: opus` frontmatter
  4. Claude Code: skill runs successfully, tier routing visibly works
  Total: 20-30 seconds. Record with VHS or asciinema.
-->

## Why?

Claude Code is Anthropic's CLI-based coding agent. It has the best runtime in the category — skills, hooks, MCP servers, per-skill model routing — but only officially supports Anthropic models.

You can point it at a LiteLLM proxy, but that only translates the wire format. Your skills still break:

- Thinking blocks can't round-trip between turns
- Remote MCP tools (claude.ai-only) cause request errors
- Array schemas without `items` get rejected by OpenAI
- Non-Claude models don't understand Claude Code's agent conventions

**claude-code-provider-kit** fixes all that. One install, pick your provider, and your skills, hooks, and multi-agent workflows actually work.

**Use this if you want to:**

- **Cut costs** — DeepSeek V4 runs at ~10x less than Claude Opus for most workloads
- **Access long context** — Gemini 2.5 Pro offers 1M+ token context windows
- **Compare models** — run the same workflow against multiple providers to benchmark quality

## Quick start

```bash
# 1. Install LiteLLM (the only dependency)
pip install 'litellm[proxy]==1.63.2'

# 2. Clone and install
git clone https://github.com/shinytoyrobots/claude-code-provider-kit.git
cd claude-code-provider-kit
./install.sh

# 3. Set your API key and go
export DEEPSEEK_API_KEY="your-key-here"
claude-deepseek
```

To persist the key across sessions, add the `export` line to your `~/.zshrc` or `~/.bashrc`.

That's it. Claude Code launches with DeepSeek as the backing model. Tier aliases work automatically — `opus` routes to the provider's flagship, `sonnet` to the workhorse, `haiku` to the cheap tier.

Verify the backing model:

```bash
claude-deepseek -p "What model are you? Reply with just your model name."
```

You should see a DeepSeek model identify itself.

## What it does

```text
Claude Code  →  LiteLLM proxy  →  Provider API
               (+ middleware)     (DeepSeek/OpenAI/Gemini)
```

A raw LiteLLM proxy translates the wire format, but complex skills still fail. The middleware and hook are what make your skills actually work on a different model.

The kit installs four things:

1. **Shell functions** (`claude-deepseek`, `claude-openai`, `claude-gemini`) that start the proxy, set the right env vars, and launch Claude Code
2. **Provider configs** (YAML) that map Claude Code's model tier aliases to each provider's models
3. **ASGI middleware** that patches requests to fix what LiteLLM's passthrough path misses:
   - Strips thinking blocks from conversation history (can't round-trip)
   - Fixes bare array schemas that OpenAI rejects
   - Removes remote MCP tools that only work on claude.ai
   - Overrides unsupported Anthropic parameters
4. **A SessionStart hook** that briefs non-Claude models on Claude Code's tool-use conventions

## Supported providers

| Provider | Opus | Sonnet | Haiku | Notes |
|----------|------|--------|-------|-------|
| **DeepSeek** | deepseek-reasoner | deepseek-chat | deepseek-chat | Legacy names — [V4 migration in progress](docs/setup-deepseek.md#deprecation-warning) |
| **OpenAI** | gpt-5 | gpt-5-mini | gpt-5-nano | [Sonnet slot is ambiguous](docs/tier-mapping.md) — consider o3/o4 for reasoning |
| **Gemini** | gemini-2.5-pro | gemini-2.5-flash | gemini-2.5-flash | Best for long-context tasks (1M+ tokens) |

Sonnet and Haiku map to the same model for DeepSeek and Gemini because those providers have two meaningful tiers, not three. See [tier mapping](docs/tier-mapping.md) for the full rationale and how to override.

## Is this allowed?

Yes. Anthropic's [LLM gateway documentation](https://code.claude.com/docs/en/llm-gateway) describes exactly this pattern — routing Claude Code through `ANTHROPIC_BASE_URL` to a LiteLLM proxy. You bring your own API keys for whatever provider you choose.

What Anthropic prohibits is third-party tools extracting and proxying Claude subscription OAuth tokens. This kit doesn't do that — it routes requests to providers using your own API keys.

## Provider setup guides

- [DeepSeek setup](docs/setup-deepseek.md) — the most tested path; start here
- [OpenAI setup](docs/setup-openai.md)
- [Gemini setup](docs/setup-gemini.md)

## What you need to know

- **Permission mode**: Claude Code uses its normal interactive permission mode (`default`) with non-Anthropic models. The only mode blocked is `auto`. You can pass any supported mode explicitly: `claude-deepseek --permission-mode dontAsk`.
- **Compatibility**: Skills that rely on Claude-specific behavior (extended thinking, certain tool-calling quirks) may degrade on other models. Most skills work unchanged.
- **LiteLLM is required**: Claude Code speaks Anthropic wire format exclusively. LiteLLM translates. There is no way around this dependency.
- **The hook is optional but recommended**: The SessionStart hook (`morph-session`) helps non-Claude models understand Claude Code's Agent tool and subagent patterns. Without it, models may fumble on tool calls.

## Troubleshooting

See the [troubleshooting guide](docs/troubleshooting.md) for common issues:

- "auto mode unavailable" error
- Model not found / 404 from provider
- LiteLLM port collision (default: 4000)
- API key not set
- How to verify which model is answering

## Project scope

This is a configuration kit, not a runtime. It ships shell scripts, YAML templates, and a thin Python middleware. It doesn't wrap Claude Code and has no dependencies beyond LiteLLM.

**Not in scope for v1**: Mistral, Qwen, Grok, Fish shell, Windows, a GUI, plugin marketplace packaging. See [CONTRIBUTING.md](CONTRIBUTING.md) for what's in scope.

## License

[MIT](LICENSE) — Robin Cannon

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Scope is intentionally narrow: provider configs, shell templates, installer, hook, docs.
