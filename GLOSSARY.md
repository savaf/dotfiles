# Local decision engine

Hand cheap, closed-ended decisions from Claude Code to a local "System 1" model (Clef-Flash)
instead of spending them on the big model.

## Language

**Decision**:
A question with a closed answer (pick from a fixed list, yes/no, or a scale) resolved without
generating free text.
_Avoid_: classification, routing (as a generic noun)

**Decision engine**:
The local service that resolves Decisions; today, Clef-Flash.
_Avoid_: router, classifier, Jev, Laya

**Fail open**:
When the engine does not answer in time or is unavailable, Claude Code keeps its default behaviour
as if the engine did not exist.
_Avoid_: fallback (that is a different term)

**Fallback**:
The secondary model (Haiku 5.5) that decides when the engine's confidence is below the threshold.
Written `respaldo` in code and logs.
_Avoid_: teacher, backup

**Suggested model**:
The `model:` an agent declares in its frontmatter. It is input to the `modelo-subagente`
Decision and the value that runs when the engine does not act; never a rule over the engine.
Logged as `suggested`.
_Avoid_: default model, forced model

**Reserve case**:
A use case for the engine that is documented as a possible improvement but not built in this effort.
_Avoid_: shadow case (clashes with Shadow mode)

**Shadow mode**:
The engine decides and its answer is logged, but Claude Code does not apply it.
