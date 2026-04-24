# Troubleshooting

## "auto mode unavailable" error

**Symptom**: Claude Code refuses to start with an error about permission mode.

**Cause**: Claude Code blocks `auto` permission mode for non-Anthropic models.

**Fix**: Use `--permission-mode dontAsk`. The shell functions (`claude-deepseek`, `claude-openai`, `claude-gemini`) already pass this flag automatically. If you're launching Claude Code manually, add it:

```bash
claude --permission-mode dontAsk
```

## Model not found / 404 from provider

**Symptom**: Requests fail with "model not found", "The model does not exist", or a 404 error from the provider.

**Cause**: The model ID in the provider YAML does not match the provider's actual model catalog. Model IDs change as providers release new versions.

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

Update the model ID in `~/.config/claude-code-bridge/providers/{provider}.yaml`. For example, if `deepseek-v4-pro` has been renamed:

```yaml
- model_name: opus
  litellm_params:
    model: deepseek/correct-model-name-here
```

Restart your shell function after editing the YAML.

## LiteLLM port collision

**Symptom**: "LiteLLM failed to start within 10 seconds" or "Address already in use."

**Cause**: Another process is using port 4000 (the default).

**Fix**: Set a different port:

```bash
export CLAUDE_BRIDGE_PROXY_PORT=4001
claude-deepseek
```

To find what's using port 4000:

```bash
lsof -i :4000
```

## API key not set

**Symptom**: `claude-code-bridge: DEEPSEEK_API_KEY is not set.`

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
cat /tmp/claude-code-bridge-litellm-4000.log
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

**Fix**: Pin to a known working version. As of this release, the kit was tested with LiteLLM 1.x. To install a specific version:

```bash
pip install 'litellm[proxy]==1.63.2'
```

Check the [LiteLLM changelog](https://github.com/BerriAI/litellm/releases) if you encounter issues after updating.

## LiteLLM not found

**Symptom**: `command not found: litellm` when running a shell function.

**Fix**: Install LiteLLM:

```bash
pip install 'litellm[proxy]'
```

If installed but not found, it may not be on your PATH. Check:

```bash
python3 -m litellm --help
```

If that works, find the install location and add it to PATH, or use a virtual environment.
