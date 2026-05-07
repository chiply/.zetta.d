# Compilation Strategy

Zetta.d uses three complementary compilation mechanisms to maximize Emacs
performance: byte-compilation, native-compilation, and automatic on-load
compilation via compile-angel.

## Byte-Compilation

Byte-compilation converts Elisp source (`.el`) into compact bytecode (`.elc`),
which Emacs loads and executes significantly faster than interpreting source.

**Where it happens:**

- **Elpaca packages** — elpaca byte-compiles each package during its build step.
  This is automatic and requires no manual intervention.
- **Zetta modules** — `bin/zetta install` and `bin/zetta sync` run
  `byte-recompile-directory` over the entire `modules/` tree. Stale `.elc` files
  are deleted first to avoid loading outdated bytecode.
- **Elpaca bootstrap** — when elpaca is first cloned, the installer
  byte-compiles its own directory with `byte-recompile-directory`.

**CLI commands:**

```
zetta install   # byte-compiles modules after package installation
zetta sync      # byte-compiles modules after config sync
```

Both commands delete existing `.elc` files before recompiling to ensure a clean
state.

## Native-Compilation

Native-compilation (Emacs 28+, `libgccjit`) compiles bytecode further into
machine code (`.eln` files), providing 2-5x speedups over bytecode for
compute-heavy operations.

**Where it happens:**

- **Elpaca packages** — `bin/zetta install` runs `native-compile-async` over
  `elpaca/builds/` recursively after package installation. This uses Emacs's
  async compilation subprocess pool and can take several minutes on first run.
- **Emacs built-ins** — Emacs natively compiles its own bundled Lisp files on
  first use (deferred native compilation). This happens in the background
  automatically.
- **On-load via compile-angel** — see below.

**Storage:**

Native-compiled `.eln` files are cached in `eln-cache/` within the Zetta
directory, organized by Emacs version.

**Configuration:**

- `warning-suppress-log-types` includes `(native-compiler)` in `init.el` to
  suppress noisy native-compiler warnings during startup.

## compile-angel (Automatic On-Load Compilation)

[compile-angel](https://github.com/jamescherti/compile-angel.el/) bridges the
gap between the batch compilation passes above and day-to-day editing. It
ensures files are compiled transparently at runtime without manual intervention.

**What it does:**

- `compile-angel-on-load-mode` hooks into `load` and `require` to
  byte-compile and native-compile `.el` files as they are loaded.
- It checks modification times and only recompiles when the source is newer
  than the existing `.elc`/`.eln`.

**What this covers that batch compilation misses:**

- **Edited modules** — if you modify a module and restart Emacs without running
  `zetta sync`, compile-angel compiles it on load.
- **Bootstrap files** — `source/bootstrap/*.el` are loaded via `require`.
- **User config files** — `~/.zetta.el` and tangled `.org` module outputs.
- **Any `.el` loaded via `load-file` or `require`** that doesn't already have a
  current `.elc`.

**Exclusions:**

`init.el`, `early-init.el`, `~/.zetta.el`, and `~/.private.el` are excluded
from automatic compilation. These files use macros (`use-package`, `elpaca`)
whose expansion depends on load order, and compiling them can cause
initialization issues. The `elpaca/` directory is also excluded — elpaca
already byte-compiles packages during its own build step, and many third-party
packages lack `lexical-binding` headers that would produce warnings.
`source/zettapkg/` is excluded for the same reason (missing headers).

**Configuration:**

Located in `source/bootstrap/bootstrap-compile-angel.el`, loaded immediately
after elpaca and use-package are ready (before any modules).

## early-init.el Performance Settings

Several settings in `early-init.el` complement the compilation strategy:

- **`load-prefer-newer nil`** — skips source-vs-bytecode mtime checks during
  init for faster startup. Safe because `zetta install`/`sync` keep bytecode
  current, and compile-angel handles the rest at runtime.
- **`gc-cons-threshold most-positive-fixnum`** — defers garbage collection
  during init (restored to 16MB after startup).
- **`file-name-handler-alist nil`** — bypasses TRAMP/compression handler
  regex checks during init (~90-120ms savings).
- **`read-process-output-max 4MB`** — faster subprocess I/O for compilation
  and LSP.

## Summary

| Mechanism | When | What | Trigger |
|---|---|---|---|
| Byte-compile (batch) | `zetta install` / `zetta sync` | `modules/` directory | Manual CLI |
| Native-compile (batch) | `zetta install` | `elpaca/builds/` directory | Manual CLI |
| Elpaca build-step | Package install/update | Individual packages | Automatic |
| compile-angel on-load | Every Emacs session | Any `.el` loaded without current `.elc`/`.eln` | Automatic |

The batch passes establish a compiled baseline. compile-angel maintains it
incrementally, so there's never a reason to load uncompiled Elisp.
