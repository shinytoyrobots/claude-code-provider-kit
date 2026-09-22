---
story-id: story-003
generated-at: 2026-04-24T00:00:00Z
generated-by: dt-qa-tester
awaiting: false
phase: completed
---

# HITL Required — Story 003 Phase A Blocked

Phase A feasibility checks found **3 blockers** that prevent automated E2E validation. The tests would
either fail for environmental reasons or — critically — validate old hook behavior rather than the
story-001/002 changes. All 3 blockers must be resolved before Phase B can run.

---

## Blocker 1 (CRITICAL): Installed hook is stale — tests would validate old behavior

**What was found:**

```
diff templates/hooks/morph-session ~/.claude/hooks/morph-session
```

The installed hook at `~/.claude/hooks/morph-session` is the **pre-story-001 version**. It is missing:

- The entire agent catalog enumeration block (stories 001 lines 39–98 in template): the `awk`-based
  frontmatter parser, the `parse_agent_frontmatter` function, and the loop over `~/.claude/commands/agents/*.md`
- The entire catalog injection block (story-002 lines 121–172 in template): the `CATALOG_SECTION`,
  `LAUNCH_SECTION`, 4000-char truncation guard, and `jq -n --arg` JSON emission

The installed hook emits a bare `cat <<MORPH` heredoc with no agent catalog or launch convention block.
Running E2E tests against this hook would test the **old version**, not the sprint deliverable.

**Fix (run this):**

```bash
cp /Users/shinytoyrobots/Development/personal/harness/templates/hooks/morph-session \
   /Users/shinytoyrobots/.claude/hooks/morph-session
chmod +x /Users/shinytoyrobots/.claude/hooks/morph-session
```

**Verify:**

```bash
diff /Users/shinytoyrobots/Development/personal/harness/templates/hooks/morph-session \
     /Users/shinytoyrobots/.claude/hooks/morph-session
# should produce no output
```

---

## Blocker 2: Shell functions `claude-openai` and `claude-gemini` not loaded

**What was found:**

```
type claude-deepseek   → shell function (from a shell snapshot)
type claude-openai     → not found
type claude-gemini     → not found
```

Only `claude-deepseek` is loaded (via `~/.claude/shell-snapshots/snapshot-zsh-*.sh`). The other two
functions exist in `templates/shell-functions.zsh` but are not sourced in the active shell environment.

**Fix (add to `~/.zshrc` or source manually each session):**

```bash
# Add to ~/.zshrc (permanent):
source /Users/shinytoyrobots/Development/personal/harness/templates/shell-functions.zsh

# Or source for this session only:
source /Users/shinytoyrobots/Development/personal/harness/templates/shell-functions.zsh
```

**Verify:**

```bash
type claude-openai claude-gemini claude-deepseek
# all three should report as shell functions
```

---

## Blocker 3: `OPENAI_API_KEY` and `GEMINI_API_KEY` are not set

**What was found:**

```
DEEPSEEK_API_KEY  → present
OPENAI_API_KEY    → NOT SET
GEMINI_API_KEY    → NOT SET
```

Without these keys the LiteLLM proxy cannot authenticate to OpenAI or Gemini, so `claude-openai`
and `claude-gemini` will fail at startup. DeepSeek can run (key is present).

**Fix:**

```bash
# Add to ~/.zshrc (load from secrets manager / 1Password / etc.):
export OPENAI_API_KEY="sk-..."
export GEMINI_API_KEY="..."
```

Note: the sprint-level pass rule is **2 of 3 providers**. If you can only set DeepSeek + one other,
the sprint can still pass. If only DeepSeek is available, document as 1-provider run and the sprint
verdict will be FAIL (1 < 2).

---

## Phase B: Manual test commands (run after all blockers are resolved)

After fixing the above, open a **new terminal** (or `exec zsh`) to pick up the hook change and sourced
functions, then run each block below. Each uses `claude -p` for non-interactive output and a 180-second
timeout.

**Set the probe prompt:**

```bash
PROBE="Launch the dt-codebase-indexer custom agent to index this small repo in quick mode. Return only: the agent name you invoked, the subagent_type you used, and whether the agent reported starting successfully. Do NOT actually run the full index — just confirm the agent launched and began executing. Keep your response under 3 sentences."
```

**DeepSeek:**

```bash
workdir=$(mktemp -d)
cd "$workdir"
mkdir -p src
echo "console.log('hello')" > src/index.js
echo "--- deepseek ---"
timeout 180 claude-deepseek -p "$PROBE" 2>&1 | tee /tmp/validation-deepseek.log
cd /Users/shinytoyrobots/Development/personal/harness
```

**OpenAI:**

```bash
workdir=$(mktemp -d)
cd "$workdir"
mkdir -p src
echo "console.log('hello')" > src/index.js
echo "--- openai ---"
timeout 180 claude-openai -p "$PROBE" 2>&1 | tee /tmp/validation-openai.log
cd /Users/shinytoyrobots/Development/personal/harness
```

**Gemini:**

```bash
workdir=$(mktemp -d)
cd "$workdir"
mkdir -p src
echo "console.log('hello')" > src/index.js
echo "--- gemini ---"
timeout 180 claude-gemini -p "$PROBE" 2>&1 | tee /tmp/validation-gemini.log
cd /Users/shinytoyrobots/Development/personal/harness
```

---

## Success criteria (per provider)

A provider PASSES if the log output shows the model:

1. Calling the Agent tool with `subagent_type: "general-purpose"` (not the agent name)
2. With a prompt referencing `~/.claude/commands/agents/dt-codebase-indexer.md` or the agent's definition
3. The subagent produced some output (any output — just that it started)

A provider FAILS if:
- Log shows `"type not found"` error
- Model never calls the Agent tool (just describes what it would do)
- Session times out (>180s)
- LiteLLM proxy fails to start (check `/tmp/litellm-*.log`)

If `-p` mode does not stream tool calls verbosely, and the model's final text response describes
launching the agent with no error, count as PASS with an advisory note.

**Sprint verdict rule:** PASS if 2 of 3 providers succeed. A single-provider failure is documented
but does not block.

---

## Validation report skeleton

Fill in `sprints/claude-code-bridge/sprint-2/validation-report.md` after running tests:

```markdown
---
story-id: story-003
sprint: 2
reviewed-by: qa-tester
generated-at: <ISO-8601 timestamp>
verdict: PASS | FAIL
providers-tested: [deepseek, openai, gemini]
providers-passed: []
providers-failed: []
providers-skipped: []
schema-version: "1.0"
---

## Summary

<one paragraph: overall verdict, which providers passed, any surprises>

## Environment

- API keys present: deepseek=yes, openai=<yes|no>, gemini=<yes|no>
- Hook version: template and installed hook in sync after copy (confirmed by diff)
- Claude Code version: 2.1.119
- `-p` / `--print` mode: supported (confirmed via `claude --help`)

## Per-provider results

| Provider | Status | Evidence | Time |
|----------|--------|----------|------|
| deepseek | PASS/FAIL | <log excerpt> | <seconds>s |
| openai   | PASS/FAIL/SKIP | <log excerpt or SKIP reason> | - |
| gemini   | PASS/FAIL/SKIP | <log excerpt or SKIP reason> | - |

## Failure analysis

<if any provider failed: what did the model do instead? wording issue in hook? provider-specific limitation?>

## Recommendations

<any changes to setup guides for story-004, provider-specific caveats>
```
