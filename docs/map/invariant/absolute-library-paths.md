# Absolute library paths

## The fact
Every native library is opened by an absolute system path, never by a bare name the loader would search for.

## Why it is cross-cutting
The two platform bindings each open their own libraries and share no loader. The macOS loader's comment says it "mirrors Windows System32 policy". A bare `DynamicLibrary.open('dwrite.dll')` at either site would reopen the DLL-hijacking hole the Windows fix closed.

## Territories it holds in
- [directwrite-bindings](../territory/directwrite-bindings.md) — `_system32Path`, `loadOle32`, `loadDWrite`.
- [coretext-bindings](../territory/coretext-bindings.md) — `_loadCoreFoundation`, `_loadCoreText`, `_loadObjc`.

## What a violation looks like
Nothing visible in normal use: a library with the same name earlier on the search path is loaded instead of the system one.

## Discovery history
- The Windows side was introduced in `57aee37` (2026-04-03, "DLL 절대경로"), tagged `W-1: prevent DLL hijacking` in `dwrite_bindings.dart`. The macOS side followed in `1c23f96` (2026-04-21).

## Where it will recur
Any new `DynamicLibrary.open` call is subject to this: `git grep -n 'DynamicLibrary.open'`.
