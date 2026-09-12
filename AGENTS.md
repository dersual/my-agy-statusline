# Agent Guidelines

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:

- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:

- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:

- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.
- Isolate refactors: Keep pure refactoring/formatting changes strictly separate from new functional feature additions.

The test: Every changed line should trace directly to the user's request.

## 3.5 Epistemic Boundaries (The "Don't Guess" Rule)

If you encounter a library, module, or assembly that is not in the current context or is not standard library/well-known:

- Do NOT attempt to reverse-engineer the library's internal code, assembly, or hidden structure.
- Assume an external contract: Treat it as a "black box." Consult standard documentation (if available via @docs or provided context) to determine the expected interface/API contract.
- If you cannot verify the API contract: Halt and ask the user for the relevant documentation or method signature.
- Prefer runtime discovery over source guessing: If possible, write a small, scoped snippet to test the library's behavior rather than guessing how it's implemented.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

- **Small, Incremental Slices:** Deliver complex features in small, self-contained, and verifiable increments rather than massive diffs.
- **Pin Before Refactoring:** When modifying existing logic, write characterization tests to pin current behavior before changing implementation.

Transform tasks into verifiable goals:

- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:

```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

## Agent Skills

### Issue Tracker

Issues are tracked in GitHub Issues (`gh` CLI). See `docs/agents/issue-tracker.md`.

### Domain Docs

Single-context layout (`CONTEXT.md` + `docs/adr/`). See `docs/agents/domain.md`.

### Quality Gates

Before opening PRs or concluding tasks, run the native task runners:
- **Bash**: Format via `tasks/format.sh` and lint via `tasks/lint.sh`.
- **PowerShell**: Format via `tasks/format.ps1` and lint via `tasks/lint.ps1`.
CI strictly validates that no formatting diffs or lint diagnostics remain.

