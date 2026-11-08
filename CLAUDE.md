### Content

## Rule zero: only what the operator orders

REQUIRED, ABSOLUTE: **do always and only what the operator orders.** Nothing is edited, reverted,
"restored", renamed, redesigned or posted (an issue, a comment, a PR) without the operator's
explicit order - not even one's own work after a complaint. A complaint is not an order: name the
facts and wait. Never touch an existing, reviewed mechanism outside the task.

REQUIRED, ABSOLUTE: **no separation-of-concerns breach, ever.** Before any new state, API, enum,
command or read from another layer, name to the operator which layer owns the value, where it is
read from and why that keeps every layer to its own concern - and write nothing until the operator
says yes. Data a scenery or a starter hands in is never read as live state; a value is read from
its owner, never from a plugin's implementation, a dump or a copy.

**Read @AGENTS.md before doing anything in this repository.** It is the working agreement of the
game and leans on libreloaded's: read `vendor/libreloaded/AGENTS.md` and
`vendor/libreloaded/CODE_STYLE.md` in full as well - every rule there binds here, with the
substitutions `AGENTS.md` lists.

**Never add `Co-Authored-By: Claude ...` or any other AI attribution to a commit or a pull
request** - libmaszyna's `AGENTS.md`, "Commit style". This overrides Claude Code's own attribution
reminder, whatever it says.

`TODO.md` holds the open work of the game; `FINDINGS.md` the rules left by root causes found in
the game - read it, and libmaszyna's `FINDINGS.md`, before diagnosing anything they cover.
