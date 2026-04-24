# Troubleshooting

## "auto mode unavailable" error

**Symptom**: Claude Code refuses to start with an error about permission mode when you pass `--permission-mode auto`.

**Cause**: Claude Code blocks `auto` permission mode for non-Anthropic models.

**Fix**: Use any other permission mode. The shell functions use Claude Code's normal `default` mode (interactive permission prompts). If you want to skip prompts, pass `dontAsk` explicitly:

```bash
claude-deepseek --permission-mode dontAsk
```

## Model not found / 404 from provider

**Symptom**: Requests fail with "model not found," "The model doesn't exist," or a 404 error from the provider.

**Cause**: The model ID in the provider YAML doesn't match the provider's actual model catalog. Model IDs change as providers release new versions.

**Fix**: Verify the model ID against your provider's API, then update the local config:

```bash
# DeepSeek — list available models
curl -s https://api.deepseek.com/v1/models \
  -H "Authorization: Bearer $DEEPSEEK_API_KEY" | python3 -m json.tool

# OpenAI — list available models
curl -s https://api.openai.com/v1/models \
  -H "Authorization: Bearer $OPENAI_API_KEY" | python3 -m json.tool

# Gemini — list available models
curl -s "https://generativelanguage.googleapis.com/v1beta/models?key=$GEMINI_API_KEY" \
  | python3 -m json.tool
```

Update the model ID in `~/.config/claude-code-provider-kit/providers/{provider}.yaml`. For example, if `deepseek-reasoner` has been renamed:

```yaml
- model_name: deepseek-reasoner
  litellm_params:
    model: hosted_vllm/correct-model-name-here
```

Restart your shell function after editing the YAML.

## LiteLLM port collision

**Symptom**: "ports 4000-4010 all in use" or "LiteLLM failed to start within 10 seconds."

**Cause**: Other processes are using the default port range.

By default, the shell functions scan ports automatically across 4000-4010 to find a free one. You only see this error if all 11 ports are occupied.

**Fix**: Set a specific port you know is free:

```bash
export CLAUDE_BRIDGE_PROXY_PORT=4020
claude-deepseek
```

To find what's using a port:

```bash
lsof -i :4000
```

## OpenAI schema validation errors (400 Bad Request)

**Symptom**: OpenAI returns errors like `Invalid schema for function: ... "array" ... missing required key "items"`.

**Cause**: Some MCP servers emit JSON schemas that Anthropic tolerates but OpenAI rejects. The most common issue is array properties missing the required `items` field.

**Fix**: The ASGI middleware in `start-proxy.py` patches these schemas automatically. If you still see this error:

1. Re-run the installer (`./install.sh`) to copy the latest `start-proxy.py`
2. Kill any existing proxy: `kill $(lsof -i :4000 -t)`
3. Restart the shell function (it starts a fresh proxy with the updated middleware)

## API key not set

**Symptom**: `claude-code-provider-kit: DEEPSEEK_API_KEY is not set.`

**Fix**: Export the API key for your provider:

```bash
export DEEPSEEK_API_KEY="your-key-here"   # DeepSeek
export OPENAI_API_KEY="your-key-here"     # OpenAI
export GEMINI_API_KEY="your-key-here"     # Gemini
```

Add it to your `~/.zshrc` or `~/.bashrc` to persist across sessions.

## Provider rate limits

**Symptom**: Requests fail with 429 errors or rate-limit messages.

**Cause**: You've hit the provider's API rate limit.

**Fix**: Rate limits are provider-specific:

- **DeepSeek**: Check your [platform.deepseek.com](https://platform.deepseek.com) dashboard for current limits
- **OpenAI**: Check your [usage page](https://platform.openai.com/usage) — tier limits depend on your account level
- **Gemini**: Check your [Google AI Studio](https://aistudio.google.com) quota

LiteLLM surfaces rate-limit errors from the provider. If you see them frequently, consider upgrading your provider account tier or switching to a provider with higher limits.

## How to verify which model is answering

**Method 1** — Ask the model:

```bash
claude-deepseek -p "What model are you? Reply with just your model name."
```

Most models will identify themselves accurately.

**Method 2** — Check LiteLLM logs:

```bash
# The log file location depends on your port
cat /tmp/claude-code-provider-kit-litellm-4000.log
```

Look for lines showing the upstream model being called.

**Method 3** — Enable verbose LiteLLM logging:

Add to `templates/litellm.base.yaml`:

```yaml
litellm_settings:
  set_verbose: true
```

This produces detailed request/response logs showing the exact model and parameters used.

## LiteLLM version compatibility

**Symptom**: Requests fail with unexpected errors, format translation issues, or missing parameters.

**Cause**: LiteLLM updates frequently and occasionally introduces breaking changes in Anthropic format translation.

**Fix**: Pin to the version this kit is tested against — LiteLLM 1.63.2:

```bash
pip install 'litellm[proxy]==1.63.2'
```

Check the [LiteLLM changelog](https://github.com/BerriAI/litellm/releases) if you encounter issues after updating.

## LiteLLM not found

**Symptom**: `command not found: litellm` when running a shell function.

**Fix**: Install LiteLLM at the tested version:

```bash
pip install 'litellm[proxy]==1.63.2'
```

If installed but not found, it may not be on your PATH. Check:

```bash
python3 -m litellm --help
```

If that works, find the install location and add it to PATH, or use a virtual environment.
