# disabled/ — parked modules (not loaded)

Modules kept as a rollback reference rather than deleted. They are **not
loaded**: the module loader (`zetta--module-files` in
`source/bootstrap/bootstrap-modules.el`) globs only the top-level `*.el`
files of each category directory (`(directory-files dir nil "\\.el\\'")`,
non-recursive), so anything in a subdirectory like this one is never
discovered. Because the loader never sees them, their `use-package`
declarations never reach elpaca either — a parked module's package is not
installed on a fresh setup.

## Superseded by the `svg-line` UI

These are the **pre-`svg-line` originals** of the line UI.

| file            | replaced by                                            |
|-----------------|--------------------------------------------------------|
| `tab-bar.el`    | `../tab-bar-svg.el` (+ indicators in `core/line-utils.el`) |
| `line.el`       | `../modeline-svg.el` (+ indicators in `core/line-utils.el`) |
| `tab-line.el`   | `../tab-line-svg.el`                                    |
| `dual-header.el`| `../header-line-svg.el` (+ breadcrumb content in `core/line-utils.el`) |

## Retired

| file           | why                                                    |
|----------------|--------------------------------------------------------|
| `yascroll.el`  | the vertical scroll thumb in the right fringe — the only scroll bar here, the built-ins being off. Retired once the chrome went bar-less: it was the last always-on furniture, and the mode line already reports position. |

Restoring `yascroll.el` needs one extra step beyond the list below:
`zetta-svg-margin-activate` in `../svg-margin.el` used to re-enable
`global-yascroll-bar-mode` *after* init, so the mode came back even with the
module unloaded. That call was removed when the module was parked — put it
back, or the thumb will not appear.

## To switch back to one of these

1. Move the file up to its category dir (e.g. `mv tab-bar.el ../`).
2. Exclude its `-svg` replacement so they don't both load. In `~/.zetta.el`
   change `:ui` to an exclusion spec, e.g.
   `:ui (-tab-bar-svg -modeline-svg -tab-line-svg -header-line-svg)`.
3. Some content now lives in `core/line-utils.el` (the shared indicator
   library); the old files redefine those same names, so loading an old
   file alongside `line-utils.el` is fine (last definition wins), but
   review for drift before relying on it.
4. Restart and verify.
