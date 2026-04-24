"""claude-code-bridge — LiteLLM proxy handler that fixes tool schemas.

Some MCP servers emit JSON schemas that Anthropic tolerates but stricter
providers (OpenAI, Gemini) reject. The most common issue: array properties
missing the required `items` field.

This handler patches schemas in-transit before they reach the provider.
"""

from litellm.integrations.custom_logger import CustomLogger


class ToolSchemaFixer(CustomLogger):
    async def async_pre_call_hook(self, user_api_key_dict, cache, data, call_type):
        if "tools" in data:
            for tool in data["tools"]:
                func = tool.get("function", {})
                if "parameters" in func:
                    _fix_array_schemas(func["parameters"])
        return data


def _fix_array_schemas(schema):
    if not isinstance(schema, dict):
        return
    if schema.get("type") == "array" and "items" not in schema:
        schema["items"] = {}
    for val in schema.get("properties", {}).values():
        _fix_array_schemas(val)
    if isinstance(schema.get("items"), dict):
        _fix_array_schemas(schema["items"])
