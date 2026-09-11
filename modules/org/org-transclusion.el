;;; org-transclusion.el --- Configure org-transclusion -*- lexical-binding: t; -*-

;; Left at its defaults.
;;
;; This briefly carried a `,-o-x' menu of the package's commands, for a
;; generated buffer that gathered (todo) entries by transclusion and edited
;; them in place (`org-smart-tree', removed 2026-09-08).  That view is gone:
;; `org-transclusion-live-sync' -- the only mechanism that writes an edit
;; back to its source -- proved too fragile to build a daily workflow on.
;; It clones the transcluded and source regions as overlays that must
;; correspond exactly, and in testing `live-sync-exit' failed to complete,
;; leaving clone overlays behind that made the NEXT `live-sync-start' fail;
;; in a real buffer that surfaced as the transcluded content being
;; duplicated around the edit.  See time-management.org, "The smart tree".
;;
;; The package stays installed and unconfigured: it long predates that
;; experiment, and transcluding a section into a document by hand is a
;; different and much better-behaved use of it than assembling an editable
;; task view was.

(use-package org-transclusion :after org)
;;; org-transclusion.el ends here
