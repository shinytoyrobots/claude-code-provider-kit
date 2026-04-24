# Tier Mapping

## How skill routing works

This is the single most valuable behavior claude-code-provider-kit enables: **your skill frontmatter `model: opus` routes to the provider's flagship tier automatically.**

Here's the chain:

1. A skill's frontmatter declares `model: opus` (or `sonnet` or `haiku`)
2. Claude Code reads the corresponding environment variable: `ANTHROPIC_DEFAULT_OPUS_MODEL`
3. That variable is set by the shell function (for example, `claude-deepseek` sets it to `deepseek-reasoner`)
4. Claude Code sends the request to LiteLLM at `ANTHROPIC_BASE_URL`
5. LiteLLM matches the model alias and routes to the provider's actual model

This means your entire skill library works unchanged — every `model: opus` call routes to the provider's best model, every `model: haiku` call routes to the cheapest.

## Environment variables

The shell functions export these variables:

| Variable | Purpose | Example (DeepSeek) |
|----------|---------|-------------------|
| `ANTHROPIC_BASE_URL` | Points Claude Code at LiteLLM | `http://localhost:4000` |
| `ANTHROPIC_MODEL` | Default model for the session | `deepseek-chat` |
| `ANTHROPIC_DEFAULT_OPUS_MODEL` | Opus tier target | `deepseek-reasoner` |
| `ANTHROPIC_DEFAULT_SONNET_MODEL` | Sonnet tier target | `deepseek-chat` |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL` | Haiku tier target | `deepseek-chat` |

## Provider tier maps

| Claude Code tier | DeepSeek | OpenAI | Gemini |
|------------------|----------|--------|--------|
| **Opus** (flagship) | deepseek-reasoner | gpt-5 | gemini-2.5-pro |
| **Sonnet** (workhorse) | deepseek-chat | gpt-5-mini | gemini-2.5-flash |
| **Haiku** (cheap) | deepseek-chat | gpt-5-nano | gemini-2.5-flash |

## Why these defaults?

The kit ships opinionated defaults because picking a default is strictly better than shipping nothing and making every user research model lineups.

**DeepSeek**: Two meaningful tiers. `deepseek-reasoner` is the flagship; `deepseek-chat` is fast and cheap enough for both Sonnet and Haiku slots. Using `deepseek-reasoner` for Sonnet would roughly double the cost of most skill calls. These are legacy model names — V4 names (`deepseek-v4-pro`, `deepseek-v4-flash`) will replace them once LiteLLM routing issues are resolved. See the [DeepSeek setup guide](setup-deepseek.md#deprecation-warning).

**OpenAI**: Three tiers that map naturally. The Sonnet slot (gpt-5-mini) is the most debatable — see the [OpenAI setup guide](setup-openai.md) for alternative mappings with o-series reasoning models.

**Gemini**: Two meaningful tiers. Same pattern as DeepSeek — Pro for Opus, Flash for everything else. Gemini's long context window (1M+ tokens on Pro) is its primary differentiator.

## How to override

### Change a tier mapping

Edit the provider's YAML file in `providers/`. For example, to map Sonnet to `deepseek-reasoner`:

```yaml
# In providers/deepseek.yaml, change:
- model_name: sonnet
  litellm_params:
    model: hosted_vllm/deepseek-reasoner   # was hosted_vllm/deepseek-chat
    api_key: os.environ/DEEPSEEK_API_KEY
```

### Add a model

Copy any entry in the provider YAML and change `model_name` and `litellm_params.model`:

```yaml
- model_name: o3
  litellm_params:
    model: openai/o3
    api_key: os.environ/OPENAI_API_KEY
```

Then set `ANTHROPIC_DEFAULT_OPUS_MODEL=o3` in the shell function or your environment.

### Use a completely different model for one session

Override the env var directly:

```bash
ANTHROPIC_DEFAULT_OPUS_MODEL=o4-mini claude-openai
```
