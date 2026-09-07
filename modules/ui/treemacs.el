;;; treemacs.el --- Configure treemacs -*- lexical-binding: t; -*-

;; Define commands before use-package so keybindings work before treemacs loads.
(defun zetta-refresh-treemacs ()
  (interactive)
  (let ((treemacs-buf (nth 0 (zetta-soda-mode-displayed-p "treemacs-mode")))
        (win (selected-window)))
    (when treemacs-buf
      (kill-buffer treemacs-buf)
      (treemacs)
      (select-window win))))

(defun zetta-soda-drink-treemacs ()
  (interactive)
  (let* ((win (selected-window))
         (treemacs-buf (nth 0 (zetta-soda-mode-displayed-p "treemacs-mode"))))
    (if treemacs-buf
        (select-window (get-buffer-window treemacs-buf))
      (treemacs)
      (select-window win))))

(defun zetta-soda-toggle-treemacs-follow-mode ()
  (interactive)
  (if treemacs-tag-follow-mode
      (progn
        (treemacs-tag-follow-mode -1)
        (treemacs-follow-mode 1))
    (treemacs-tag-follow-mode 1)))

;; Keybindings available immediately (not deferred to :config)
(general-define-key
 :keymaps 'menu-run-map
 "t" (** zetta-soda-drink-treemacs)
 "T" (** treemacs)
 "C-t" (** zetta-refresh-treemacs)
 "M-t" (** zetta-soda-toggle-treemacs-follow-mode))

(defun zetta-treemacs-buffer-name (scope)
  "Return the scope-specific part of a treemacs buffer name for SCOPE.

Empty, so the buffer is named by `treemacs-buffer-name-prefix' alone.
Treemacs keeps one buffer per scope -- a frame by default -- and normally
distinguishes them by appending the scope here, so with several frames open
they would now share a name and therefore a buffer.  With a single frame,
which is the case this is tuned for, there is nothing to distinguish."
  (ignore scope)
  "")

(use-package treemacs
  :ensure (treemacs
           :files ("src/elisp/*.el"
                   "src/extra/*.el"
                   "src/scripts/*.py"))
  :commands (treemacs treemacs-select-window treemacs-add-project)

  ;; Name the buffer " *T*" instead of " *Treemacs-Buffer-#<frame 0x...>".
  ;; The tab line trims the leading space, so it reads as "*T*" there and
  ;; stops crowding out the real buffers beside it.
  ;;
  ;; Two variables, not a rename: treemacs finds its own buffers and windows
  ;; with `s-starts-with?' against `treemacs-buffer-name-prefix'
  ;; (`treemacs-is-treemacs-window?' and friends), so renaming the buffer
  ;; behind its back would make it stop recognising its own tree.  The prefix
  ;; stays the whole name and the scope suffix goes away.
  ;;
  ;; Set in `:custom' rather than `:config' because treemacs-compatibility.el
  ;; bakes the prefix into `winum-ignored-buffers-regexp' AT LOAD TIME -- set
  ;; afterwards and winum would still be ignoring the old name.
  ;;
  ;; The leading space is kept: it is what marks the buffer as internal, so
  ;; dropping it would surface the tree in `consult-buffer' and every other
  ;; buffer list.
  :custom
  (treemacs-buffer-name-prefix " *T*")
  (treemacs-buffer-name-function #'zetta-treemacs-buffer-name)

  :config
  ;; "Idea" theme no longer exists upstream — use "Default".
  (treemacs-load-theme "Default")

  (treemacs-resize-icons nil)

  ;; Expanding a project no longer yanks it to the top of the window.
  ;; `on-visibility' -- the default -- recenters whenever the rows just
  ;; added do not fit below point, and it does that by asking for
  ;; (recenter (max 0 (round (- current-line (- new-lines lines-left)))))
  ;; (see `treemacs--maybe-recenter').  Expand a project with more
  ;; children than the window is tall and that argument clamps to 0, so
  ;; the node you expanded is pulled to the first line.  `on-distance'
  ;; is the middle setting if scrolling-to-fit is wanted back.
  (setq treemacs-recenter-after-project-expand nil)

  (setq aw-ignored-buffers '("*Calc Trail*" " *LV*"))

  (setq-default
   treemacs-file-follow-delay 0.5
   treemacs-file-event-delay 2000
   treemacs-tag-follow-delay 1.0
   treemacs-display-in-side-window t
   treemacs-width 35
   treemacs-width-is-initially-locked nil)

  ;; Disable expensive modes that treemacs auto-enables during its own
  ;; init (via `treemacs-only-during-init').  Must happen in :config
  ;; (not :init) because treemacs re-enables them at load time.
  ;;
  ;; git-mode spawns a python subprocess on every node expansion —
  ;; biggest perf hit and source of number-or-marker-p errors.
  (treemacs-git-mode -1)

  ;; Directory flattening is the OTHER half of that same init block:
  ;;
  ;;   (treemacs-only-during-init
  ;;     ...
  ;;     (when has-python (setf treemacs-collapse-dirs 3)))
  ;;
  ;; and it spawns the same kind of subprocess on every directory
  ;; expansion — treemacs-dirs-to-collapse.py — except this one is waited
  ;; on SYNCHRONOUSLY, in `treemacs--parse-flattened-dirs', via
  ;; `pfuture-await-to-finish'.  That wait is `accept-process-output',
  ;; which permits redisplay, and the expansion is at that moment inside
  ;; the `save-excursion' in `treemacs--button-open' with point left at
  ;; the end of the rows just inserted.  So Emacs redisplays over and over
  ;; — 13 times in one measured expansion — showing the cursor parked at
  ;; the end of the new block and the window scrolled to follow it, before
  ;; point is restored and everything snaps back.  That was the flicker,
  ;; and the node being yanked to the top of the window.
  ;;
  ;; Measured on this tree: 182ms and 98ms per expansion with flattening
  ;; on, 0ms with it off.
  ;;
  ;; The cost is real — a/b/c chains are three rows now instead of one.
  ;; The subprocess is not worth it for that.
  (setq treemacs-collapse-dirs 0)

  ;; Filewatch-mode exhausts macOS file descriptors in large trees.
  (treemacs-filewatch-mode -1)

  ;; The deferred annotation pass, off unless it has something to say.
  ;;
  ;; `treemacs--button-open' arms a 0.5s timer after every expansion.  When
  ;; it fires it walks every child of the node and, for each one, deletes
  ;; from the suffix annotation to end-of-line and writes the row back --
  ;; which is the text visibly re-settling a beat after an expand.  With
  ;; `treemacs-git-mode' off (above) and nothing in the annotation store
  ;; there is nothing to write: the whole pass is a delete and re-render
  ;; that changes nothing.
  ;;
  ;; It is also the source of
  ;;   Error running timer `treemacs--apply-annotations-deferred':
  ;;   (wrong-type-argument number-or-marker-p nil)
  ;; The timer captures the expanded button and half a second later does
  ;; (1+ (treemacs-button-get btn :depth)) on it.  Re-render the tree in
  ;; between -- resizing the window is enough -- and that button is gone,
  ;; `:depth' is nil, and (1+ nil) signals exactly that.
  ;;
  ;; The guard is on content, not on the mode, so enabling git-mode or
  ;; letting lsp-treemacs put diagnostics in the store brings it straight
  ;; back.
  (defun zetta-treemacs--annotations-pending-p ()
    "Non-nil when the tree has annotations worth applying."
    (or (bound-and-true-p treemacs--git-mode)
        (and (boundp 'treemacs--annotation-store)
             (> (ht-size treemacs--annotation-store) 0))))

  (defun zetta-treemacs--skip-empty-annotations (fn &rest args)
    "Apply FN to ARGS only when there is an annotation to apply."
    (when (zetta-treemacs--annotations-pending-p)
      (apply fn args)))

  (advice-add 'treemacs--apply-annotations-deferred :around
              #'zetta-treemacs--skip-empty-annotations)

  ;; Only file-follow — tag-follow adds expensive idle-timer overhead.
  ;; Do NOT call (treemacs-project-follow-mode -1) — its teardown
  ;; unconditionally cancels a timer that doesn't exist when the mode
  ;; was never enabled, throwing (wrong-type-argument timerp nil).
  (treemacs-follow-mode t)
  (treemacs-tag-follow-mode -1)

  :general
  (
   :keymaps '(treemacs-mode-map)
   "o" 'treemacs-visit-node-ace
   "h" 'treemacs-visit-node-ace-horizontal-split
   "v" 'treemacs-visit-node-ace-vertical-split
   "d" 'treemacs-delete-file
   )

  :hook ((use-package--treemacs--post-config . brushup)
         (treemacs-mode . (lambda ()
                            (text-scale-set -2)
                            (toggle-truncate-lines -1)
                            (zetta-treemacs-refresh-icons)))))

;;; --------------------------------------------------------------------
;;; Icons
;;; --------------------------------------------------------------------
;; The tree had no icons at all, for two reasons.  Treemacs' own
;; "Default" theme keeps its PNGs under icons/, which the :files spec
;; above does not pull into the build, so it has nothing to draw and
;; falls back to its text markers.  And the bundled
;; `treemacs-all-the-icons' cannot stand in: it is written against
;; upstream all-the-icons, not the SVG fork this config uses (see
;; modules/ui/all-the-icons.el).  It reads
;; `all-the-icons-extension-icon-alist' expecting a FUNCTION in the second
;; slot, where the fork keeps the icon SET name, and it calls the singular
;; `all-the-icons-octicon' / `-material' / `-faicon', none of which the
;; fork defines -- requiring it dies with "void-function octicons".
;;
;; So the theme is built here.  It uses NERD-ICONS glyphs rather than the
;; all-the-icons SVGs that dired and the minibuffer wear, because in a
;; tree the difference between a glyph and an image is not cosmetic:
;;
;;   - a glyph is text, so it scales with `text-scale' by itself.  An
;;     image carries a fixed pixel size and has to be rebuilt whenever the
;;     row height changes -- and this buffer runs text-scaled.
;;   - an image makes redisplay do layout work per row, and a row whose
;;     image cannot be loaded is laid out twice.  Expanding a directory
;;     inserts dozens of those at once.
;;
;; The glyphs still track the theme: they carry `:inherit nerd-icons-<hue>'
;; and `zetta-icons-refresh-colors' (modules/ui/all-the-icons.el) re-tints
;; that whole vocabulary off the theme's palette, so a .py is the same
;; colour here as it is in dired.
;;
;; The theme still extends "Default" so that the handful of symbols only
;; treemacs' own extensions use keep an entry -- but every one of those
;; entries names a missing PNG, so they are replaced below rather than
;; inherited as image specs that cannot load.

(eval-when-compile
  ;; `treemacs-create-theme' is a MACRO, and this module is read before the
  ;; deferred `use-package treemacs' above has loaded it.  Interpreted that
  ;; is harmless -- the macro is looked up when the defun below is first
  ;; called -- but byte-compiling without it would quietly compile the
  ;; macro call as a function call.
  (require 'treemacs nil t)
  (require 'nerd-icons nil t))

(defun zetta-treemacs--glyph (fn name plist &optional face)
  "The nerd-icons glyph NAME from FN, spaced for a treemacs row.
PLIST is passed through, FACE overrides the one it carries.  Nil when the
icon does not exist, so a name this version of nerd-icons does not carry
falls through to the inherited theme rather than erroring."
  (when (fboundp fn)
    (when-let* ((glyph (ignore-errors
                         (apply fn name (if face (list :face face) plist)))))
      (concat glyph " "))))

(defun zetta-treemacs-build-icon-theme ()
  "Build the treemacs icon theme from nerd-icons."
  ;; Dropped first: `treemacs-create-theme' pushes onto `treemacs--themes'
  ;; every time, so a rebuild would leave the old one behind under the
  ;; same name.
  (setq treemacs--themes
        (seq-remove (lambda (th) (equal (treemacs-theme->name th) "zetta"))
                    treemacs--themes))
  (treemacs-create-theme "zetta"
    :extends "Default"
    :config
    (let* ((dir-face 'treemacs-directory-face)
           (file-icon (zetta-treemacs--glyph #'nerd-icons-octicon "nf-oct-file" nil))
           (folder (ignore-errors
                     (nerd-icons-octicon "nf-oct-file_directory" :face dir-face)))
           (chev-open (ignore-errors
                        (nerd-icons-octicon "nf-oct-chevron_down" :face dir-face)))
           (chev-closed (ignore-errors
                          (nerd-icons-octicon "nf-oct-chevron_right" :face dir-face)))
           (dir-open (and folder (concat (or chev-open "") folder " ")))
           (dir-closed (and folder (concat (or chev-closed "") folder " "))))

      ;; File types, straight off nerd-icons' own extension table, so a
      ;; file wears the same hue here as in dired and the minibuffer.
      (dolist (item nerd-icons-extension-icon-alist)
        (let ((exts (list (nth 0 item)))
              (icon (zetta-treemacs--glyph (nth 1 item) (nth 2 item)
                                           (nthcdr 3 item))))
          (when icon
            (treemacs-create-icon :icon icon :extensions exts
                                  :fallback 'same-as-icon))))

      ;; NB: `:extensions' must be handed a bare VARIABLE.  The macro
      ;; quotes the form whole whenever its car is a symbol, so an
      ;; expression like (list 'fallback) or (nth 0 spec) is taken
      ;; literally -- it registers icons for extensions named "list" and
      ;; "fallback", or "nth" and "spec", and the icon you meant is
      ;; silently never installed.
      (when file-icon
        (let ((exts '(fallback)))
          (treemacs-create-icon :icon file-icon :extensions exts :fallback " ")))

      ;; Root and tags take treemacs' own faces, so they follow the theme
      ;; with the rest of the tree's chrome; the three diagnostic icons
      ;; take the theme's error/warning/success.
      (dolist (spec '(((root-closed root-open) "nf-oct-repo"    treemacs-root-face)
                      ((tag-open)   "nf-oct-package"            treemacs-directory-face)
                      ((tag-closed) "nf-oct-package"            treemacs-directory-face)
                      ((tag-leaf)   "nf-oct-tag"                treemacs-directory-face)
                      ((error)      "nf-oct-flame"              error)
                      ((warning)    "nf-oct-stop"               warning)
                      ((info)       "nf-oct-info"               success)))
        (let* ((exts (nth 0 spec))
               (icon (zetta-treemacs--glyph #'nerd-icons-octicon (nth 1 spec)
                                            nil (nth 2 spec))))
          (when icon
            (treemacs-create-icon :icon icon :extensions exts
                                  :fallback 'same-as-icon))))

      (when dir-open
        (let ((exts '(dir-open)))
          (treemacs-create-icon :icon dir-open :extensions exts
                                :fallback 'same-as-icon)))
      (when dir-closed
        (let ((exts '(dir-closed)))
          (treemacs-create-icon :icon dir-closed :extensions exts
                                :fallback 'same-as-icon)))

      ;; Two clean-ups over what "Default" contributed, both of which were
      ;; visible in the tree.
      ;;
      ;; A directory whose NAME treemacs knows -- src, test, docs, github
      ;; and a few dozen more -- never reaches the generic pair above:
      ;; `treemacs-icon-for-dir' looks up "<name>-open" / "<name>-closed"
      ;; first, and those inherited entries are missing PNGs.  Those were
      ;; the directories showing no icon at all.
      ;;
      ;; Every other inherited entry is a missing PNG too, and an image
      ;; spec that cannot load is not inert: Emacs lays the row out, fails
      ;; the load, and lays it out again.  Expanding a directory inserted
      ;; dozens of them at once, which is why the tree jittered there and
      ;; not when expanding a file's headings.
      ;;
      ;; Pointing the named directories at the generic pair also keeps
      ;; every directory icon the same LENGTH, which matters:
      ;; `treemacs--button-symbol-switch' swaps closed for open by deleting
      ;; exactly as many characters as it inserts.
      (let ((gui (treemacs-theme->gui-icons treemacs--current-theme))
            (named nil) (broken nil))
        (maphash
         (lambda (k v)
           (cond
            ((and (stringp k) (or (string-suffix-p "-open" k)
                                  (string-suffix-p "-closed" k)))
             (push k named))
            ((let ((d (get-text-property 0 'display v)))
               (and (eq 'image (car-safe d))
                    (plist-get (cdr d) :file)
                    (not (file-exists-p (plist-get (cdr d) :file)))))
             (push k broken))))
         gui)
        (dolist (key named)
          (let ((exts (list key))
                (icon (if (string-suffix-p "-open" key) dir-open dir-closed)))
            (when icon
              (treemacs-create-icon :icon icon :extensions exts
                                    :fallback 'same-as-icon))))
        (when file-icon
          (dolist (key broken)
            (let ((exts (list key)))
              (treemacs-create-icon :icon file-icon :extensions exts
                                    :fallback " "))))))))

(defun zetta-treemacs-refresh-icons ()
  "Build and load the treemacs icon theme, unless it is already loaded.
Nothing here depends on the row height: glyphs are text and scale with
`text-scale' on their own, which is the whole reason this theme is built
out of them."
  (interactive)
  (when (and (display-graphic-p)
             (require 'nerd-icons nil t)
             (not (equal (treemacs-theme->name treemacs--current-theme) "zetta")))
    (zetta-treemacs-build-icon-theme)
    (treemacs-load-theme "zetta")))

(use-package treemacs-magit
  :ensure nil
  :after (treemacs magit))

;; Treemacs uses a minimal custom mode line: just the path.  (Moved here
;; from line.el.)
;;
;; It has no header line.  It used to carry a repo:branch breadcrumb there,
;; but two bars around a column of one-line entries is mostly frame in a
;; pane this narrow, and the repo and branch are both on the mode line of
;; whatever you are actually editing.  The header line is switched off in
;; `zetta-window-chrome-rules' (modules/ui/window-chrome.el), which is where
;; the rest of the "which bars does this buffer get" decisions live -- the
;; format is not set here at all, because leaving it unset would inherit the
;; global SVG breadcrumb rather than nothing.
(defun zetta-treemacs-mode-line-path ()
  "The sidebar's directory, shortened when it will not fit."
  (let ((path (abbreviate-file-name default-directory)))
    (if (> (length path) 30)
        (zetta-minify-path default-directory)
      path)))

(add-hook 'treemacs-mode-hook
          (lambda ()
            (setq-local zetta-modeline-svg-bare-extra
                        '(zetta-treemacs-mode-line-path))))
;;; treemacs.el ends here
