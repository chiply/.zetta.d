# disabled/ — parked org modules (not loaded)

The module loader (`zetta--module-files` in
`source/bootstrap/bootstrap-modules.el`) globs only the top-level `*.el`
of each category directory (`(directory-files dir nil "\\.el\\'")`,
non-recursive), so nothing here is discovered — and because the loader
never sees them, their `use-package` declarations never reach elpaca
either. A parked module's packages are **not installed** on a fresh
setup.

_Nothing parked at the moment._ `org-other-agenda.el` was switched on 2026-09-09.

## To switch one on

1. `mv org-other-agenda.el ../`
2. Start Emacs and let elpaca clone the new recipes.
3. Pin them: `M-x elpaca-write-lock-file` (or add the pins by hand), so a
   cold CI build gets the same commits.
4. Verify the `org-other-agenda-series` shape against the package's own
   README — it is set from `org-agenda-custom-commands` on the strength
   of the upstream description, not a test.
