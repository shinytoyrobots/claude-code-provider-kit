#!/usr/bin/env zsh
# claude-code-bridge — shell functions for launching Claude Code with non-Anthropic providers
# Source this file from your .zshrc:
#   source /path/to/claude-code-bridge/templates/shell-functions.zsh

_claude_code_bridge_launch() {
  local provider="$1"
  shift
  local api_key_var config_file
  local opus_model sonnet_model haiku_model default_model

  case "$provider" in
    deepseek)
      api_key_var="DEEPSEEK_API_KEY"
      config_file="providers/deepseek.yaml"
      opus_model="deepseek-v4-pro"
      sonnet_model="deepseek-v4-flash"
      haiku_model="deepseek-v4-flash"
      default_model="deepseek-v4-flash"
      ;;
    openai)
      api_key_var="OPENAI_API_KEY"
      config_file="providers/openai.yaml"
      opus_model="gpt-5"
      sonnet_model="gpt-5-mini"
      haiku_model="gpt-5-nano"
      default_model="gpt-5-mini"
      ;;
    gemini)
      api_key_var="GEMINI_API_KEY"
      config_file="providers/gemini.yaml"
      opus_model="gemini-2.5-pro"
      sonnet_model="gemini-2.5-flash"
      haiku_model="gemini-2.5-flash"
      default_model="gemini-2.5-flash"
      ;;
    *)
      echo "claude-code-bridge: unknown provider '$provider'" >&2
      return 1
      ;;
  esac

  # Check API key — zsh uses ${(P)var} for indirect expansion.
  # shellcheck disable=SC2296 # zsh indirect expansion not recognized by shellcheck
  if [ -z "${(P)api_key_var:-}" ]; then
    echo "claude-code-bridge: $api_key_var is not set." >&2
    echo "Export it in your shell: export $api_key_var=\"your-key-here\"" >&2
    return 1
  fi

  local port="${CLAUDE_BRIDGE_PROXY_PORT:-4000}"
  local log="/tmp/claude-code-bridge-litellm-${port}.log"

  # Resolve config paths relative to this script's install location.
  # The installer places configs in ~/.config/claude-code-bridge/.
  local config_dir="${CLAUDE_CODE_BRIDGE_HOME:-${HOME}/.config/claude-code-bridge}"
  local base_config="${config_dir}/templates/litellm.base.yaml"
  local provider_config="${config_dir}/${config_file}"

  # Start LiteLLM if not already running on the configured port.
  if ! (exec 3<>"/dev/tcp/localhost/${port}") 2>/dev/null; then
    echo "Starting LiteLLM proxy on port ${port}..."
    nohup litellm \
      --config "$base_config" \
      --config "$provider_config" \
      --port "$port" \
      > "$log" 2>&1 &

    local i=0
    while ! (exec 3<>"/dev/tcp/localhost/${port}") 2>/dev/null && (( i < 20 )); do
      sleep 0.5
      (( i++ ))
    done

    if ! (exec 3<>"/dev/tcp/localhost/${port}") 2>/dev/null; then
      echo "claude-code-bridge: LiteLLM failed to start within 10 seconds." >&2
      echo "Check the log: $log" >&2
      return 1
    fi
    echo "LiteLLM proxy ready on port ${port}."
  fi

  # Launch Claude Code with the provider's env vars.
  ANTHROPIC_BASE_URL="http://localhost:${port}" \
  ANTHROPIC_AUTH_TOKEN="sk-litellm" \
  ANTHROPIC_API_KEY="" \
  ANTHROPIC_MODEL="$default_model" \
  ANTHROPIC_DEFAULT_OPUS_MODEL="$opus_model" \
  ANTHROPIC_DEFAULT_SONNET_MODEL="$sonnet_model" \
  ANTHROPIC_DEFAULT_HAIKU_MODEL="$haiku_model" \
  claude --permission-mode dontAsk "$@"
}

claude-deepseek() {
  _claude_code_bridge_launch deepseek "$@"
}

claude-openai() {
  _claude_code_bridge_launch openai "$@"
}

claude-gemini() {
  _claude_code_bridge_launch gemini "$@"
}
