#!/usr/bin/env python3
"""claude-code-bridge — LiteLLM proxy launcher with request-patching middleware.

LiteLLM's callback hooks don't fire for Anthropic-format requests (which
Claude Code sends). This script wraps the LiteLLM proxy app with raw ASGI
middleware that patches requests at the HTTP layer — before any endpoint
handler runs.

Two transformations:
  1. Strip remote MCP tools (mcp__claude_ai_*) — they only work via
     claude.ai and add noise for other providers.
  2. Fix malformed array schemas (missing `items`) that strict providers
     like OpenAI reject.

Usage (drop-in replacement for `litellm`):
  python3 start-proxy.py --config base.yaml --config provider.yaml --port 4000
"""

import json
import sys

_REMOTE_MCP_PREFIX = "mcp__claude_ai_"


def _fix_array_schemas(schema):
    """Walk a JSON Schema tree adding `items: {}` to bare array types."""
    if not isinstance(schema, dict):
        return
    if schema.get("type") == "array" and "items" not in schema:
        schema["items"] = {}
    for val in schema.get("properties", {}).values():
        _fix_array_schemas(val)
    if isinstance(schema.get("items"), dict):
        _fix_array_schemas(schema["items"])
    if isinstance(schema.get("additionalProperties"), dict):
        _fix_array_schemas(schema["additionalProperties"])
    for key in ("anyOf", "allOf", "oneOf"):
        for sub in schema.get(key, []):
            _fix_array_schemas(sub)


def _tool_name(tool):
    """Extract name from any tool format (Anthropic, Chat Completions, Responses)."""
    func = tool.get("function")
    if isinstance(func, dict):
        return func.get("name", "")
    return tool.get("name", "")


def _patch_request(data):
    """Strip remote MCP tools and fix schemas. Returns True if modified."""
    tools = data.get("tools")
    if not tools:
        return False

    modified = False

    # Strip remote MCP tools (they only work via claude.ai infrastructure)
    original_count = len(tools)
    tools[:] = [t for t in tools if not _tool_name(t).startswith(_REMOTE_MCP_PREFIX)]
    stripped = original_count - len(tools)
    if stripped:
        print(
            f"[claude-code-bridge] Stripped {stripped} unavailable tools ({original_count} → {len(tools)})",
            file=sys.stderr,
        )
        modified = True

    # Fix array schemas missing `items`
    for tool in tools:
        for key in ("input_schema", "parameters"):
            if key in tool and isinstance(tool[key], dict):
                _fix_array_schemas(tool[key])
        func = tool.get("function")
        if isinstance(func, dict) and "parameters" in func:
            _fix_array_schemas(func["parameters"])

    return modified or bool(tools)


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

        try:
            data = json.loads(body)
            if _patch_request(data):
                body = json.dumps(data).encode("utf-8")
        except (json.JSONDecodeError, Exception):
            pass

        body_sent = False

        async def patched_receive():
            nonlocal body_sent
            if not body_sent:
                body_sent = True
                return {"type": "http.request", "body": body, "more_body": False}
            return await receive()

        await self.app(scope, patched_receive, send)


from litellm.proxy.proxy_server import app  # noqa: E402

app.add_middleware(_RequestPatcherMiddleware)

from litellm.proxy.proxy_cli import run_server  # noqa: E402

run_server()
