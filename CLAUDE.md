# CLAUDE.md

## Agent skills

| Before you | Read |
|---|---|
| file, read, label or close an issue | `docs/agents/issue-tracker.md` |
| apply a triage role | `docs/agents/triage-labels.md` |
| name a domain concept or contradict a recorded decision | `docs/agents/domain.md` |

## Map

The territory map is [`docs/map/README.md`](docs/map/README.md). Read it before designing a change (in `read-it`), and follow the blast radius of every territory the change touches. After it lands (in `sweep`), update the notes whose claims it changed. When a fix reveals a fact, ask whether it holds at every site that shares the same assumption; if it does, the fix lands with an invariant note.

## Comments

A comment says what the code is. Why it is this way, what it deliberately leaves out, the trap and the measured value go to the territory note under `docs/map/`. Where none seems to hold it, search the folder and the code symbol first; only then start a new note, named for what the system does there, not for the file. History goes to the commit message. Comments written before this rule still carry the rest: never delete one whose content the map does not yet hold — move it there first.
