# Domain Documentation: Single-Context

This repository uses a **single-context** domain layout.

## Structure

- **System Context**: `CONTEXT.md` at the repo root describes overall system architecture, key boundaries, component roles, and domain concepts.
- **Architectural Decision Records (ADRs)**: Stored in `docs/adr/` as numbered Markdown files (e.g. `0001-record-architecture-decisions.md`).

## Consumer Rules for Agents

1. **Read context before non-trivial changes**: Read `CONTEXT.md` to understand system architecture, module boundaries, and domain invariants.
2. **Record architectural choices**: When making non-trivial architectural decisions, create a new ADR in `docs/adr/` using standard ADR structure (Title, Status, Context, Decision, Consequences).
3. **Keep context current**: Update `CONTEXT.md` when introducing new subsystems, updating major dependencies, or altering core interfaces.
