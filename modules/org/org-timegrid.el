;;; org-timegrid.el --- SVG week calendar over the agenda files -*- lexical-binding: t; -*-

;; An editable SVG week grid (github.com/Gleek/org-timegrid) drawn from the
;; same Org files everything else here reads.  Drag out a block and it writes
;; a real timestamped heading; drag or resize one and it rewrites the
;; timestamp in place.
;;
;; SOURCES.  `org-timegrid-org-files' is left at `agenda', so the grid reads
;; `org-agenda-files' -- the (todo) files from `zetta-logseq-dir' plus
;; whatever `zetta-extra-agenda-files' adds in ~/.private.el (see
;; `zetta-logseq-update-agenda-files' in org.el).  That is the same set calfw
;; reads, so the two agree by construction: one calendar's worth of data, two
;; views of it.  They differ only in HOW they read it -- calfw goes through
;; `org-agenda-get-day-entries', which honours `org-agenda-entry-types' and so
;; also sees diary sexps; this parses the files with `org-element' and sees
;; only real timestamps.  Nothing is lost by that here: there are no `%%('
;; entries in any agenda file and no diary file.
;;
;; WRITES.  This is the part calfw does not do.  Blocks created on the grid
;; land in `zetta-org-timegrid-file', and edits to an existing block rewrite
;; the timestamp in whichever agenda file owns it -- including the ones under
;; ~/kb that Logseq also syncs.  That is the intended behaviour (time blocking
;; means moving blocks around), but it is worth knowing that this view is the
;; one that can change your files.

(defvar zetta-logseq-dir)

(defcustom zetta-org-timegrid-file
  (expand-file-name "(todo) calendar.org"
                    (or (bound-and-true-p zetta-logseq-dir) (zetta-kb-file "todo/")))
  "File new calendar blocks are written to.

The package's own default is `calendar.org' in `user-emacs-directory' --
a file that does not exist here and is not in `org-agenda-files', so
blocks created on the grid would land somewhere nothing else reads.  This
points it at the calendar file that already exists in the kb todo
directory, which IS an agenda file, so a block written on the grid is
immediately visible to the grid, to calfw and to the agenda without a
refile step.

Derived from `zetta-logseq-dir' -- vestigially named, pointing at
~/kb/todo since 2026-07 -- so it follows that directory rather than
hard-coding a second copy of the path."
  :type 'file :group 'zetta)


;; Brushup drives the event colours.  The chrome does not need us: the package
;; derives background, grid, weekend and now-marker from `default', `shadow',
;; `link', `error' and `cursor' (`org-timegrid--palette'), blending foreground
;; into background by fixed ratios so the result scales to any theme -- and it
;; consults `face-remapping-alist' before the global face, so it tracks
;; solaire-mode per buffer.  What it does NOT theme is the event blocks:
;; `org-timegrid-colors' ships the macOS system palette, thirteen saturated
;; hues fixed at every theme.
;;
;; So the hues go and the names stay.  Each maps to a rung on the brushup ink
;; ladder, chosen by how loud the name sounds rather than by hue -- red at the
;; top, graphite at the bottom -- which keeps a tag mapping written in
;; upstream's vocabulary meaningful while drawing it in the theme's own ink.
;; A block is a translucent wash of its colour with a bar down the left edge,
;; so a rung reads as weight rather than as a colour cue.

(defvar brushup-styles)
(defvar brushup-fg)
(defvar brushup-fg-1)
(defvar brushup-fg-2)
(defvar brushup-fg-3)
(defvar brushup-fg-4)
(defvar brushup-fg-5)
(defvar brushup-fg-6)
(defvar org-timegrid-colors)

(defcustom zetta-org-timegrid-palette-rungs
  '((red      . brushup-fg)
    (pink     . brushup-fg-1)
    (orange   . brushup-fg-1)
    (yellow   . brushup-fg-2)
    (blue     . brushup-fg-2)
    (indigo   . brushup-fg-3)
    (purple   . brushup-fg-3)
    (cyan     . brushup-fg-3)
    (teal     . brushup-fg-4)
    (lime     . brushup-fg-4)
    (green    . brushup-fg-4)
    (brown    . brushup-fg-5)
    (graphite . brushup-fg-6))
  "Map each `org-timegrid-colors' name to a brushup ink variable.

Keys are upstream's names, so `org-timegrid-org-tag-color-alist' can be
written in the vocabulary the package documents.  Values are symbols naming
a brushup variable, resolved afresh on every theme change.

Several names share a rung -- the ladder has seven steps and the palette
thirteen names -- and that collapse is the point: what survives a theme is
prominence, not hue.

`org-timegrid-default-color' is left at upstream's `blue', so whichever rung
`blue' carries is what every untagged event gets.  Today that is every
event, since `org-timegrid-org-tag-color-alist' is empty."
  :type '(alist :key-type symbol :value-type symbol)
  :group 'zetta)

(defun zetta-org-timegrid-apply-palette ()
  "Take `org-timegrid-colors' from the theme, per `zetta-org-timegrid-palette-rungs'.

Also redraw any live grid.  The package recomputes its chrome palette on
every draw and caches nothing, but it hooks no theme change -- its only
redraw triggers are a window resize, a text-scale change and a 300s data
timer -- so an open week would otherwise keep the old theme's colours for
up to five minutes."
  (let ((colors (delq nil
                      (mapcar (lambda (cell)
                                (and (boundp (cdr cell))
                                     (cons (car cell)
                                           (symbol-value (cdr cell)))))
                              zetta-org-timegrid-palette-rungs))))
    ;; `setq' rather than customising: this runs before the package loads on
    ;; a cold start, and `defcustom' leaves an already-set value alone -- the
    ;; same ordering the `:init' block below depends on.
    (when colors
      (setq org-timegrid-colors colors)))
  ;; `org-timegrid--refresh' rather than the public `org-timegrid-refresh'
  ;; (`g'): the public one re-reads every Org file and resets cursor and
  ;; viewport, and a theme change earns neither -- only a redraw that leaves
  ;; the reader where they were.  Private, hence guarded.
  (when (fboundp 'org-timegrid--refresh)
    (dolist (buffer (buffer-list))
      (with-current-buffer buffer
        (when (derived-mode-p 'org-timegrid-mode)
          (ignore-errors (org-timegrid--refresh t)))))))

(use-package org-timegrid
  :ensure (:host github :repo "Gleek/org-timegrid")
  :commands (org-timegrid-week org-timegrid-open org-timegrid-agenda-mode)
  :init
  ;; Set before load, not in `:config': these live in org-timegrid-org.el,
  ;; which is pulled in lazily by the autoloaded `org-timegrid-week'.
  ;; `defcustom' leaves an already-set value alone, so assigning here wins
  ;; and the package never installs its own default.
  (setq org-timegrid-org-capture-file zetta-org-timegrid-file
        ;; `agenda' = `org-agenda-files'.  The package's default already, but
        ;; stated because it is the whole point of the setup: every agenda
        ;; file is a source, not just the calendar one.  The capture file is
        ;; always queried in addition, and here it is an agenda file anyway.
        org-timegrid-org-files 'agenda
        ;; Save the file after an edit.  The default leaves the buffer
        ;; modified, which for a Logseq-synced file means the change sits in
        ;; Emacs where Logseq cannot see it -- and a later sync can then
        ;; overwrite it.
        org-timegrid-org-auto-save t)
  :brushup
  (add-to-list 'brushup-styles '(zetta-org-timegrid-apply-palette))

  :config
  ;; Once on load as well as on every theme change: `brushup-styles' may
  ;; already have run before this package existed.
  (zetta-org-timegrid-apply-palette)

  ;; The keymap is dense and single-letter: b/f day, n/p block, d delete,
  ;; e edit, t retime, j goto-date, g refresh, q quit -- every one of which
  ;; evil's normal state would shadow with a motion.  So the grid runs in
  ;; emacs state and keeps its own bindings, unlike calfw (a read-only grid
  ;; where hjkl navigation is worth rebinding for).
  (with-eval-after-load 'evil
    (evil-set-initial-state 'org-timegrid-mode 'emacs)))

;; `,oc' -- alongside the other org launchers under `o' (s/t/h are the
;; kb heading and TODO searches in org-capture.el).
(general-define-key
 :keymaps 'launch-map
 :prefix "o"
 "c" 'org-timegrid-week)

;;; org-timegrid.el ends here
