#!/usr/bin/env bash
set -euo pipefail

# claude-code-bridge installer
# Idempotent install/uninstall of shell functions, SessionStart hook,
# and provider configs for running Claude Code with non-Anthropic models.

MARKER_START="# >>> claude-code-bridge >>>"
MARKER_END="# <<< claude-code-bridge <<<"
INSTALL_DIR="${HOME}/.config/claude-code-bridge"
TMP_SUFFIX=".claude-code-bridge.tmp"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ALL_PROVIDERS="deepseek openai gemini"

DRY_RUN=false
UNINSTALL=false
PROVIDERS=""

# --- Output helpers ---

info() { printf "  %s\n" "$*"; }
success() { printf "  [ok] %s\n" "$*"; }
warn() { printf "  [warn] %s\n" "$*" >&2; }
error() { printf "  [error] %s\n" "$*" >&2; }

# --- Atomic write: tmp file + mv ---

atomic_write() {
  local target="$1"
  local content="$2"
  local tmp="${target}${TMP_SUFFIX}"

  if "$DRY_RUN"; then
    info "WRITE $target"
    return
  fi

  mkdir -p "$(dirname "$target")"
  printf '%s' "$content" > "$tmp"
  mv "$tmp" "$target"
}

atomic_copy() {
  local src="$1"
  local dest="$2"
  local tmp="${dest}${TMP_SUFFIX}"

  if "$DRY_RUN"; then
    info "COPY $src -> $dest"
    return
  fi

  mkdir -p "$(dirname "$dest")"
  cp "$src" "$tmp"
  mv "$tmp" "$dest"
}

# --- Reconcile abandoned tmp files from interrupted installs ---

reconcile_tmp() {
  local target="$1"
  local tmp="${target}${TMP_SUFFIX}"
  if [ -f "$tmp" ]; then
    warn "Found abandoned tmp file: $tmp (removing)"
    rm -f "$tmp"
  fi
}

# --- RC file marker block management ---

has_marker() {
  local rc_file="$1"
  [ -f "$rc_file" ] && grep -qF "$MARKER_START" "$rc_file"
}

remove_marker_block() {
  local rc_file="$1"
  if ! has_marker "$rc_file"; then
    return
  fi
  if "$DRY_RUN"; then
    info "REMOVE marker block from $rc_file"
    return
  fi
  local tmp="${rc_file}${TMP_SUFFIX}"
  sed "/${MARKER_START//\//\\/}/,/${MARKER_END//\//\\/}/d" "$rc_file" > "$tmp"
  mv "$tmp" "$rc_file"
}

add_marker_block() {
  local rc_file="$1"
  local shell_variant="$2"
  local source_path="${INSTALL_DIR}/templates/shell-functions.${shell_variant}"

  remove_marker_block "$rc_file"

  if "$DRY_RUN"; then
    info "ADD marker block to $rc_file (source $source_path)"
    return
  fi

  local block
  block="$(printf '\n%s\nsource "%s"\n%s\n' "$MARKER_START" "$source_path" "$MARKER_END")"
  local tmp="${rc_file}${TMP_SUFFIX}"
  if [ -f "$rc_file" ]; then
    cp "$rc_file" "$tmp"
  else
    touch "$tmp"
  fi
  printf '%s' "$block" >> "$tmp"
  mv "$tmp" "$rc_file"
}

# --- Detect user's shell ---

detect_shell() {
  local login_shell
  login_shell="${SHELL##*/}"
  case "$login_shell" in
    zsh)  printf "zsh" ;;
    bash) printf "bash" ;;
    *)    printf "bash" ;;
  esac
}

rc_file_for_shell() {
  local sh="$1"
  case "$sh" in
    zsh)  printf "%s/.zshrc" "$HOME" ;;
    bash) printf "%s/.bashrc" "$HOME" ;;
    *)    printf "%s/.bashrc" "$HOME" ;;
  esac
}

# --- Parse arguments ---

usage() {
  cat <<'USAGE'
Usage: install.sh [OPTIONS]

Options:
  --dry-run              Print planned changes without modifying anything
  --uninstall            Remove claude-code-bridge from your system
  --providers LIST       Comma-separated providers to install (default: all)
                         Valid: deepseek, openai, gemini
  --help                 Show this help message

Examples:
  ./install.sh                          Install all providers
  ./install.sh --providers deepseek     Install DeepSeek only
  ./install.sh --dry-run                Preview changes
  ./install.sh --uninstall              Remove everything
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)   DRY_RUN=true; shift ;;
    --uninstall) UNINSTALL=true; shift ;;
    --providers)
      [ $# -lt 2 ] && { error "--providers requires a comma-separated list"; exit 1; }
      PROVIDERS="$2"; shift 2 ;;
    --help)      usage; exit 0 ;;
    *)           error "Unknown option: $1"; usage; exit 1 ;;
  esac
done

# Default providers
if [ -z "$PROVIDERS" ]; then
  PROVIDERS="$ALL_PROVIDERS"
else
  PROVIDERS="${PROVIDERS//,/ }"
fi

# Validate provider names
for p in $PROVIDERS; do
  case "$p" in
    deepseek|openai|gemini) ;;
    *) error "Unknown provider: $p (valid: deepseek, openai, gemini)"; exit 1 ;;
  esac
done

# --- Pre-flight checks ---

if [ "$(id -u)" -eq 0 ]; then
  error "Do not run install.sh as root."
  error "Running as root writes files owned by root into your home directory,"
  error "which breaks permissions for your normal user account."
  error ""
  error "Run as your normal user instead:"
  error "  ./install.sh"
  exit 1
fi

USER_SHELL="$(detect_shell)"
RC_FILE="$(rc_file_for_shell "$USER_SHELL")"

# --- Uninstall ---

if "$UNINSTALL"; then
  printf "claude-code-bridge: uninstalling\n"

  remove_marker_block "$RC_FILE"
  success "Removed shell functions from $RC_FILE"

  if ! "$DRY_RUN"; then
    rm -f "${HOME}/.claude/hooks/morph-session"
    rm -rf "$INSTALL_DIR"
  else
    info "DELETE ${HOME}/.claude/hooks/morph-session"
    info "DELETE $INSTALL_DIR/"
  fi
  success "Removed hook and config directory"

  printf "\nclaude-code-bridge: uninstalled. Restart your shell to apply.\n"
  exit 0
fi

# --- LiteLLM check (skip for dry-run) ---

if ! "$DRY_RUN" && ! command -v litellm >/dev/null 2>&1; then
  error "LiteLLM is not installed."
  error ""
  error "Install it with:"
  error "  pip install 'litellm[proxy]'"
  error ""
  error "Then re-run this installer."
  exit 1
fi

# --- Install ---

printf "claude-code-bridge: installing\n"
printf "  shell: %s (%s)\n" "$USER_SHELL" "$RC_FILE"
printf "  providers: %s\n" "$PROVIDERS"
printf "  install dir: %s\n" "$INSTALL_DIR"
printf "\n"

# Reconcile any abandoned tmp files from interrupted prior installs
reconcile_tmp "$RC_FILE"
reconcile_tmp "${HOME}/.claude/hooks/morph-session"

# Step 1: Copy kit files to install dir
if ! "$DRY_RUN"; then
  mkdir -p "${INSTALL_DIR}/templates/hooks"
  mkdir -p "${INSTALL_DIR}/providers"
fi

atomic_copy "${SCRIPT_DIR}/templates/litellm.base.yaml" "${INSTALL_DIR}/templates/litellm.base.yaml"
atomic_copy "${SCRIPT_DIR}/templates/proxy_handler.py" "${INSTALL_DIR}/templates/proxy_handler.py"
atomic_copy "${SCRIPT_DIR}/templates/shell-functions.zsh" "${INSTALL_DIR}/templates/shell-functions.zsh"
atomic_copy "${SCRIPT_DIR}/templates/shell-functions.bash" "${INSTALL_DIR}/templates/shell-functions.bash"
success "Copied shell function templates"

# Step 2: Copy selected provider configs
for p in $PROVIDERS; do
  local_src="${SCRIPT_DIR}/providers/${p}.yaml"
  if [ ! -f "$local_src" ]; then
    warn "Provider config not found: $local_src (skipping)"
    continue
  fi
  atomic_copy "$local_src" "${INSTALL_DIR}/providers/${p}.yaml"
done
success "Copied provider configs: $PROVIDERS"

# Step 3: Install SessionStart hook
atomic_copy "${SCRIPT_DIR}/templates/hooks/morph-session" "${HOME}/.claude/hooks/morph-session"
if ! "$DRY_RUN"; then
  chmod +x "${HOME}/.claude/hooks/morph-session"
fi
success "Installed SessionStart hook"

# Step 4: Add source line to rc file
add_marker_block "$RC_FILE" "$USER_SHELL"
success "Added shell functions to $RC_FILE"

printf "\nclaude-code-bridge: installed successfully.\n"
printf "\nNext steps:\n"
printf "  1. Restart your shell (or run: source %s)\n" "$RC_FILE"
printf "  2. Set your API key:\n"
for p in $PROVIDERS; do
  case "$p" in
    deepseek) printf "     export DEEPSEEK_API_KEY=\"your-key\"\n" ;;
    openai)   printf "     export OPENAI_API_KEY=\"your-key\"\n" ;;
    gemini)   printf "     export GEMINI_API_KEY=\"your-key\"\n" ;;
  esac
done
printf "  3. Launch Claude Code:\n"
for p in $PROVIDERS; do
  printf "     claude-%s\n" "$p"
done
printf "\n"
