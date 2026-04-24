#!/usr/bin/env python3
"""claude-code-bridge — LiteLLM proxy launcher with request-patching middleware.

LiteLLM's callback hooks don't fire for Anthropic-format requests (which
Claude Code sends). This script wraps the LiteLLM proxy app with raw ASGI
middleware that patches requests at the HTTP layer — before any endpoint
handler runs.

Four transformations:
  1. Strip unsupported Anthropic params (context_management) that
     LiteLLM's drop_params misses in the passthrough path.
  2. Override thinking param to disabled — prevents providers from
     entering reasoning mode that Claude Code can't round-trip.
  3. Strip thinking blocks from conversation history messages.
  4. Strip remote MCP tools (mcp__claude_ai_*) and fix malformed
     array schemas (missing `items`).

Approach: monkey-patch uvicorn.run to wrap the app AFTER LiteLLM has
fully initialized (config loaded, settings applied). This avoids
interfering with LiteLLM's startup sequence.

Usage (drop-in replacement for `litellm`):
  python3 start-proxy.py --config base.yaml --config provider.yaml --port 4000
"""

import json
import sys

_REMOTE_MCP_PREFIX = "mcp__claude_ai_"

# Anthropic-specific parameters that LiteLLM's drop_params misses in the
# experimental passthrough path. Strip them ourselves.
_UNSUPPORTED_PARAMS = {"context_management"}

# Parameters to override (not strip) — value replaces whatever Claude Code sent.
# thinking: must be explicitly disabled or DeepSeek models default to reasoning
# mode, which returns reasoning_content that Claude Code can't pass back.
_PARAM_OVERRIDES = {"thinking": {"type": "disabled"}}


def _fix_array_schemas(schema):
    """Walk a JSON Schema tree adding `items: {}` to bare array types. Returns fix count."""
    if not isinstance(schema, dict):
        return 0
    count = 0
    if schema.get("type") == "array" and "items" not in schema:
        schema["items"] = {}
        count += 1
    for val in schema.get("properties", {}).values():
        count += _fix_array_schemas(val)
    if isinstance(schema.get("items"), dict):
        count += _fix_array_schemas(schema["items"])
    if isinstance(schema.get("additionalProperties"), dict):
        count += _fix_array_schemas(schema["additionalProperties"])
    for key in ("anyOf", "allOf", "oneOf"):
        for sub in schema.get(key, []):
            count += _fix_array_schemas(sub)
    return count


def _tool_name(tool):
    """Extract name from any tool format (Anthropic, Chat Completions, Responses)."""
    func = tool.get("function")
    if isinstance(func, dict):
        return func.get("name", "")
    return tool.get("name", "")


def _patch_request(data):
    """Strip unsupported params, remote MCP tools, and fix schemas."""
    modified = False

    # Strip thinking blocks from messages — providers may return reasoning
    # content that gets translated to Anthropic thinking blocks, but Claude
    # Code can't round-trip them back to the provider's format.
    for msg in data.get("messages", []):
        content = msg.get("content")
        if isinstance(content, list):
            filtered = [b for b in content if b.get("type") != "thinking"]
            if len(filtered) < len(content):
                msg["content"] = filtered
                modified = True

    # Strip Anthropic-specific params that LiteLLM's drop_params misses
    for param in _UNSUPPORTED_PARAMS:
        if param in data:
            del data[param]
            modified = True

    # Override params that need explicit values (not just removal)
    for param, value in _PARAM_OVERRIDES.items():
        if data.get(param) != value:
            data[param] = value
            modified = True

    tools = data.get("tools")
    if not tools:
        return modified

    # Strip remote MCP tools (they only work via claude.ai infrastructure)
    original_count = len(tools)
    tools[:] = [t for t in tools if not _tool_name(t).startswith(_REMOTE_MCP_PREFIX)]
    stripped = original_count - len(tools)
    if stripped:
        print(
            f"[claude-code-bridge] Stripped {stripped} remote MCP tools ({original_count} → {len(tools)})",
            file=sys.stderr,
        )

    # Fix array schemas missing `items`
    schema_fixes = 0
    for tool in tools:
        for key in ("input_schema", "parameters"):
            if key in tool and isinstance(tool[key], dict):
                schema_fixes += _fix_array_schemas(tool[key])
        func = tool.get("function")
        if isinstance(func, dict) and "parameters" in func:
            schema_fixes += _fix_array_schemas(func["parameters"])

    if schema_fixes:
        print(
            f"[claude-code-bridge] Fixed {schema_fixes} array schema(s) missing 'items'",
            file=sys.stderr,
        )

    return modified or stripped > 0 or schema_fixes > 0


class _RequestPatcherMiddleware:
    """ASGI middleware that patches tool lists in POST request bodies."""

    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http" or scope.get("method") != "POST":
            await self.app(scope, receive, send)
            return

        body_parts = []
        while True:
            message = await receive()
            body_parts.append(message.get("body", b""))
            if not message.get("more_body", False):
                break

        body = b"".join(body_parts)
        patched = False

        try:
            data = json.loads(body)
            if _patch_request(data):
                body = json.dumps(data, ensure_ascii=False).encode("utf-8")
                patched = True
        except (json.JSONDecodeError, Exception):
            pass

        if patched:
            # Update content-length to match modified body
            new_headers = []
            for name, value in scope.get("headers", []):
                if name == b"content-length":
                    new_headers.append((b"content-length", str(len(body)).encode()))
                else:
                    new_headers.append((name, value))
            scope = {**scope, "headers": new_headers}

        body_sent = False

        async def patched_receive():
            nonlocal body_sent
            if not body_sent:
                body_sent = True
                return {"type": "http.request", "body": body, "more_body": False}
            return await receive()

        await self.app(scope, patched_receive, send)


# Monkey-patch uvicorn.run to wrap the app with our middleware AFTER
# LiteLLM has fully initialized (config loaded, drop_params set, etc.).
import uvicorn  # noqa: E402

_original_uvicorn_run = uvicorn.run


def _patched_uvicorn_run(app, **kwargs):
    # LiteLLM may pass app as an import string (e.g. "module:attr").
    # Resolve it to the actual object before wrapping.
    if isinstance(app, str):
        from importlib import import_module
        module_path, attr = app.split(":")
        app = getattr(import_module(module_path), attr)
    print("[claude-code-bridge] Wrapping LiteLLM app with request patcher", file=sys.stderr)
    wrapped = _RequestPatcherMiddleware(app)
    return _original_uvicorn_run(wrapped, **kwargs)


uvicorn.run = _patched_uvicorn_run

from litellm import run_server  # noqa: E402

run_server()
