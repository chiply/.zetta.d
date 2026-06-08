;;; line-utils.el --- Configure line utilities -*- lexical-binding: t; -*-

;;;;;; Utils
(defvar ml-selected-window nil)

(defun ml-record-selected-window ()
  (setq ml-selected-window (selected-window)))

(defun ml-update-all ()
  (force-mode-line-update t))

(add-hook 'post-command-hook 'ml-record-selected-window)
(add-hook 'buffer-list-update-hook 'ml-update-all)

;;;; functions for generating icons
(defun zetta-line-iedit-icon ()
  (when (and (boundp 'iedit-mode) iedit-mode)
    (all-the-icons-material
     "find_replace"
     :face 'mode-line )))

(defun zetta-line-github-icon ()
  (when vc-mode
    (all-the-icons-faicon
     "github"
     :face 'mode-line )))

(defun zetta-line-modified-icon ()
  (when (buffer-modified-p)
    (all-the-icons-material
     "change_history"
     :face 'mode-line
     )))

(defun zetta-line-tramp-icon ()
  (when (and (fboundp '4mn-get-tramp-hop-types)
             (member "ssh" (4mn-get-tramp-hop-types)))
    (all-the-icons-faicon "server"
                          :face 'mode-line)))

(defun zetta-line-docker-icon ()
  (when (and (fboundp '4mn-get-tramp-hop-types)
             (member "docker" (4mn-get-tramp-hop-types)))
    (all-the-icons-fileicon
     "dockerfile"
     :face 'mode-line)))

(defun zetta-line-hydra-indicator-icon ()
  (if (and
       ;; hydra loaded
       (boundp 'hydra-curr-map)
       ;; head active
       hydra-curr-map
       ;; on selected window
       (eq ml-selected-window (selected-window)))
      (all-the-icons-material
       "flare"

       ;; make invisible in other buffers
       :face 'mode-line
       )
    nil))

(defun zetta-line-narrowed-icon ()
  (when (buffer-narrowed-p) "N"))

(defun zetta-get-repo-name ()
  (last (split-string
         (nth 0 (split-string
                 (shell-command-to-string
                  "git rev-parse --show-toplevel")
                 "\n"))
         "/"
         ))
  )

(defun zetta-get-branch-name ()
  (nth 0 (split-string
          (shell-command-to-string
           "git rev-parse --abbrev-ref HEAD")
          "\n")))

(defun zetta-line-col ()
  (let ((col-length (length (int-to-string (current-column)))))
    (cond
     ((eq col-length 1) "%c%2 ")
     ((eq col-length 2) "%c%1 ")
     ((eq col-length 3) "%c")
     )
    )
  )

;;;; Indicators (segment functions, moved from the -svg config modules)
;; ----------------------------------------------------------------
;; Atomic display segments.  The -svg config modules in :ui bind these
;; into lines (they only compose, not define).  line-utils.el (:core)
;; loads before those :ui consumers, so the functions are defined first.

;; Interactive (clickable/hover/menu) segments are built with the svg-line
;; engine's `svg-line-seg'; `zetta-svg-seg' wraps it to give every segment a
;; per-window-unique id (so only the hovered window's copy of an indicator
;; highlights) and to no-op gracefully when the engine isn't loaded.
(declare-function svg-line-seg "svg-line")
(declare-function svg-line-segs "svg-line")

(defun zetta-svg-seg (text key &rest plist)
  "Return an interactive svg-line segment for TEXT, keyed by KEY.
The hover/identity id is (KEY . current-buffer) so a per-window bar only
highlights the indicator in the window under the mouse.  PLIST passes through
\(`:help' `:action' `:action-help' `:menu' `:color'/`:face').  Returns nil when
TEXT is empty or the engine is unavailable, so the segment then contributes
nothing."
  (when (and text (fboundp 'svg-line-seg)
             (> (length (format-mode-line text)) 0))
    (apply #'svg-line-seg text :id (cons key (current-buffer)) plist)))

(defun zetta-svg--crumb-target (str pos text)
  "Return a buffer position/marker the crumb at POS (text TEXT) in STR points to.
Reads the target breadcrumb already stashed on the crumb: `breadcrumb-region'
or `org-imenu-marker' on the crumb itself, else the crumb's entry in the
`breadcrumb-siblings' alist (matched by TEXT).  Returns nil when no target is
discoverable (e.g. lsp crumbs, whose own handler we keep instead)."
  (let ((reg  (get-text-property pos 'breadcrumb-region str))
        (om   (get-text-property pos 'org-imenu-marker str))
        (sibs (get-text-property pos 'breadcrumb-siblings str)))
    (cond
     ((consp reg) (car reg))                       ; (start . end) -> start
     ((markerp om) om)
     ((and (listp sibs) text)
      (let ((hit (assoc text (mapcar (lambda (e)
                                       (cons (and (stringp (car-safe e))
                                                  (substring-no-properties (car e)))
                                             (cdr-safe e)))
                                     sibs))))
        (let ((tgt (cdr hit)))
          (cond ((markerp tgt) tgt)
                ((numberp tgt) tgt)
                ((overlayp tgt) (overlay-start tgt)))))))))

(defun zetta-svg--crumb-jump (target)
  "Return an interactive command that navigates to TARGET (a marker or position).
Selects TARGET's window/buffer, pushes the mark, moves point and reveals it
\(unfolding in org), so a crumb click goes straight there -- no completing-read."
  (lambda ()
    (interactive)
    (let* ((m (if (markerp target) target nil))
           (buf (if m (marker-buffer m) (current-buffer)))
           (pos (if m (marker-position m) target)))
      (when (and buf pos (buffer-live-p buf))
        (let ((win (get-buffer-window buf)))
          (if win (select-window win)
            (pop-to-buffer buf)))
        (push-mark)
        (goto-char pos)
        (cond ((derived-mode-p 'org-mode)
               (ignore-errors (org-fold-show-context))
               (ignore-errors (org-fold-show-entry)))
              ((bound-and-true-p outline-minor-mode)
               (ignore-errors (outline-show-entry))))
        (recenter)))))

(defun zetta-svg-segs-from-propertized (str id-key)
  "Split propertized STR into an svg-line `:svg-segs' group of clickable crumbs.
Each maximal region carrying a clickable `keymap'/`local-map' (with a mouse-1
binding) becomes an interactive segment whose action invokes that binding;
regions without one stay plain text.  This harvests the crumb handlers that
breadcrumb.el and lsp-headerline already attach to header-line strings -- their
handlers either ignore the event (`breadcrumb-jump') or read the window from
its posn, which our header-line click provides correctly.  ID-KEY namespaces
the per-crumb hover ids.  Returns nil (no segment) for empty STR."
  (when (and (stringp str) (fboundp 'svg-line-segs) (> (length str) 0))
    (let ((parts nil) (i 0) (n (length str)) (idx 0) (buf (current-buffer)))
      (while (< i n)
        (let* ((km   (or (get-text-property i 'keymap str)
                         (get-text-property i 'local-map str)))
               (next (min (or (next-single-property-change i 'keymap str) n)
                          (or (next-single-property-change i 'local-map str) n)))
               (text (substring-no-properties str i next))
               ;; NB: `lookup-key' returns an integer (not nil) when a key is
               ;; "too long" for the map, so test each result for `functionp'
               ;; and take the first real command -- don't `or' the raw results.
               (handler (and (keymapp km)
                             (seq-some (lambda (k)
                                         (let ((b (lookup-key km k)))
                                           (and (functionp b) b)))
                                       (list [header-line mouse-1] [mouse-1]
                                             [mode-line mouse-1]))))
               ;; Prefer a DIRECT jump to the crumb's own target (org/imenu
               ;; crumbs stash a marker/region) over the package handler, which
               ;; for breadcrumb is a completing-read.  lsp crumbs expose no
               ;; target here, so they keep their own (already-direct) handler.
               (target (and handler (zetta-svg--crumb-target str i text)))
               (act  (cond (target (zetta-svg--crumb-jump target))
                           (handler handler)))
               (he   (get-text-property i 'help-echo str)))
          ;; Only a left-click action: these crumb handlers take (interactive
          ;; "e") and read the invoking mouse event, which a real header-line
          ;; click supplies but a right-click menu selection would not.
          (if (and act (> (length (string-trim text)) 0))
              (setq idx (1+ idx)
                    parts (cons (svg-line-seg
                                 text
                                 :id (list id-key buf idx)
                                 ;; clean, lightweight help -- for a direct jump
                                 ;; use the crumb text; else the handler's own
                                 ;; first help line (properties stripped, since
                                 ;; breadcrumb stuffs its sibling tree in there)
                                 :help (if target
                                           (concat "go to " (string-trim text))
                                         (if (stringp he)
                                             (substring-no-properties
                                              (car (split-string he "\n")))
                                           (format "%s" (string-trim text))))
                                 :action-help (if target "jump" "open")
                                 :action act)
                                parts))
            (push text parts))
          (setq i next)))
      (apply #'svg-line-segs (nreverse parts)))))

;;; tab-bar / status segments
(defun zetta-buffer-name ()
  (let ((name (if (buffer-file-name)
                  (abbreviate-file-name (buffer-file-name))
                (buffer-name))))
    (if (> (length name) 70)
        (concat (substring name 0 67) "…")
      name)))

(defun zmc-modeline-indicator ()
  (concat
   (when (boundp 'local-transient) local-transient)
   " "))

(defun zetta-pyvenv-activate-poetry-modeline ()
  (and (boundp 'zetta-pyvenv-virtual-env)
       (concat "{venv:"
               (zetta-minify-path zetta-pyvenv-virtual-env)
               "/"
               (car (last (split-string zetta-pyvenv-virtual-env "/")))
               "}")))

(defun zetta-tab-bar-spot-mode-line-string ()
  (if (fboundp 'spot-mode-line-string)
      (spot-mode-line-string)
    "*"))

(defun zetta-tab-bar-modal ()
  "The active modal SYSTEM (evil / meow / emacs)."
  (or
   (when (and (boundp 'evil-mode) evil-mode) "evil")
   (when (and (boundp 'meow-mode) meow-mode) "meow")
   (when (not (or (and (boundp 'evil-mode) evil-mode)
                  (and (boundp 'meow-mode) meow-mode)))
     "emacs")))

(defun zetta-line-modal-state ()
  "The current modal STATE (e.g. normal, insert, visual) as a string.
Works for evil and meow; \"emacs\" when neither is editing this buffer."
  (cond
   ((bound-and-true-p evil-state) (symbol-name evil-state))
   ((and (bound-and-true-p meow-mode) (fboundp 'meow--current-state)
         (meow--current-state))
    (symbol-name (meow--current-state)))
   (t "emacs")))

(defun zetta-gptel-processes ()
  (when (boundp 'gptel--request-alist)
    (let ((num-processes (length gptel--request-alist)))
      (if (> num-processes 0)
          (format " ai:%d " num-processes)
        ""))))

(defun tab-bar-keycast ()
  (let ((str (keycast--format keycast-mode-line-format)))
    (when str
      (set-text-properties 0 (length str) nil str))
    `((keycast menu-item ,(or str "") ignore))))

(defun zetta-tab-bar-current-thing ()
  "Tab-bar item: shows the effective treesit-tap thing at point.
Uses the accessor `treesit-tap--current-thing' rather than the raw
buffer-local `treesit-tap-current-thing', so it is always visible:
it falls back to `treesit-tap-default-thing' (e.g. [defun]) in buffers
where no local thing has been set via `treesit-tap-set-local'."
  (when (fboundp 'treesit-tap--current-thing)
    (format "[%s] " (treesit-tap--current-thing))))

(defun zetta-tab-bar-recursion-level ()
  (let ((recursion-level (minibuffer-depth)))
    (if (zerop recursion-level)
        "[R:0] "
      (format " [R:%d] " recursion-level))))

(defun zetta-tab-bar-svg--keycast ()
  "Keycast string with a caps-keyboard glyph sitting next to the keys.
Keycast right-pads the keys (`keycast-mode-line-format' is \"%10s...\"), so trim
that leading whitespace before prefixing the glyph -- otherwise the glyph ends
up far to the left of the actual key/command.  Returns nil when idle."
  (let ((str (string-trim-left (or (nth 2 (car (tab-bar-keycast))) ""))))
    (when (> (length str) 0)
      (let ((icon (and (featurep 'nerd-icons)
                       (zetta-line--glyph (ignore-errors (nerd-icons-mdicon "nf-md-keyboard_caps"))))))
        (concat (and icon (concat icon " ")) str)))))

(defun zetta-tab-bar-recursion-icon ()
  "Type-hierarchy glyph shown to the left of the recursion-depth indicator."
  (and (featurep 'nerd-icons)
       (zetta-line--glyph (ignore-errors (nerd-icons-codicon "nf-cod-type_hierarchy_sub")))))

(defun zetta-current-prefix ()
  (let ((descr (key-description
                (or
                 (and
                  (boundp 'my-this-command-keys-vector)
                  my-this-command-keys-vector)
                 (this-command-keys-vector)))))
    (if (string-match-p "mouse" descr)
        ""
      descr)))

;; otherwise prefix keys won't show up
(add-hook 'prefix-command-echo-keystrokes-functions 'force-mode-line-update)

;;; mode-line text segments
(defun zetta-modeline-svg--modal ()
  ;; show the modal STATE (normal/insert/...), not the modal system
  (let ((st (zetta-line-modal-state)))
    (zetta-svg-seg
     st 'ml-modal
     :help (format "modal state: %s" (string-trim (format "%s" st)))
     :action-help "show key bindings"
     :action #'describe-bindings
     :menu (list (cons "Describe bindings" #'describe-bindings)
                 (cons "Describe mode" #'describe-mode)
                 (cons "Command (M-x)" #'execute-extended-command)))))

(defun zetta-modeline-svg--ace ()
  (or (window-parameter (selected-window) 'ace-window-path) ""))

(defun zetta-modeline-svg--buffer ()
  (let* ((buf (current-buffer))
         (n (buffer-name buf))
         (label (if (> (length n) 40) (concat (substring n 0 39) "…") n)))
    (svg-line-seg
     label
     ;; id includes the buffer so only THIS window's name boxes on hover
     :id (list 'ml-buffer buf)
     :help (format "buffer: %s" n)
     :action-help "switch buffer"
     :action #'switch-to-buffer
     :menu (delq nil
                 (list
                  (cons "Switch buffer…" #'switch-to-buffer)
                  (cons "Save buffer"
                        (lambda () (interactive)
                          (with-current-buffer buf (save-buffer))))
                  (and (buffer-file-name buf)
                       (cons "Rename file…"
                             (lambda () (interactive)
                               (with-current-buffer buf
                                 (call-interactively #'rename-visited-file)))))
                  (cons "Revert buffer"
                        (lambda () (interactive)
                          (with-current-buffer buf (revert-buffer))))
                  (cons "Copy buffer name"
                        (lambda () (interactive) (kill-new n)))
                  (cons "Kill buffer"
                        (lambda () (interactive)
                          (when (buffer-live-p buf) (kill-buffer buf)))))))))

(defun zetta-modeline-svg--mode ()
  (zetta-svg-seg
   (format-mode-line mode-name) 'ml-mode
   :help (format "major mode: %s" major-mode)
   :action-help "describe mode"
   :action #'describe-mode
   :menu (list (cons "Describe mode" #'describe-mode)
               (cons "Describe bindings" #'describe-bindings)
               (cons "Customize mode" #'customize-mode))))

;; The vc cluster (git glyph + branch glyph + repo:branch) is one clickable
;; segment so the whole thing opens magit -- the separate icon segments are
;; folded in here and dropped from the mode-line content.
(defun zetta-modeline-svg--vc ()
  (when (and (fboundp 'vc-git-root)
             (vc-git-root (or (buffer-file-name) default-directory)))
    (let* ((repo   (ignore-errors (nth 0 (zetta-get-repo-name))))
           (branch (ignore-errors (vc-git--symbolic-ref
                                   (or (buffer-file-name) default-directory))))
           (vcg (and (buffer-file-name) (featurep 'nerd-icons)
                     (zetta-line--glyph (ignore-errors (nerd-icons-devicon "nf-dev-git")))))
           (brg (and (buffer-file-name) (featurep 'nerd-icons)
                     (zetta-line--glyph (ignore-errors (nerd-icons-octicon "nf-oct-git_branch")))))
           (text (concat (and vcg (concat vcg " "))
                         (and brg (concat brg " "))
                         (or repo "") (and branch (concat ":" branch)))))
      (zetta-svg-seg
       text 'ml-vc
       :help (format "git: %s%s" (or repo "?") (if branch (concat " @ " branch) ""))
       :action-help "open magit"
       :action (if (fboundp 'magit-status) #'magit-status #'vc-dir)
       :menu (delq nil
                   (list (and (fboundp 'magit-status) (cons "Magit status" #'magit-status))
                         (and (fboundp 'magit-log-current) (cons "Magit log" #'magit-log-current))
                         (and (fboundp 'magit-blame) (cons "Magit blame" #'magit-blame))
                         (and (fboundp 'magit-file-dispatch) (cons "File dispatch" #'magit-file-dispatch))
                         (cons "VC dir" #'vc-dir)
                         (and branch (cons "Copy branch name"
                                           (let ((b branch))
                                             (lambda () (interactive) (kill-new b)))))))))))

(defun zetta-modeline-svg--checkers ()
  ;; copilot is shown as an icon (zetta-modeline-svg--copilot-icon), not text
  (when (and (boundp 'lsp-mode) lsp-mode)
    (zetta-svg-seg
     (or (and (featurep 'nerd-icons)
              (zetta-line--glyph (ignore-errors (nerd-icons-devicon "nf-dev-vscode"))))
         "lsp")
     'ml-lsp
     :help "LSP session"
     :action-help "LSP diagnostics"
     :action (cond ((fboundp 'consult-lsp-diagnostics) #'consult-lsp-diagnostics)
                   ((fboundp 'lsp-treemacs-errors-list) #'lsp-treemacs-errors-list)
                   ((fboundp 'flymake-show-buffer-diagnostics) #'flymake-show-buffer-diagnostics)
                   (t #'ignore))
     :menu (delq nil
                 (list (and (fboundp 'lsp-describe-session) (cons "Describe session" #'lsp-describe-session))
                       (and (fboundp 'lsp-rename) (cons "Rename symbol" #'lsp-rename))
                       (and (fboundp 'lsp-find-references) (cons "Find references" #'lsp-find-references))
                       (and (fboundp 'lsp-organize-imports) (cons "Organize imports" #'lsp-organize-imports))
                       (and (fboundp 'lsp-workspace-restart) (cons "Restart workspace" #'lsp-workspace-restart)))))))

(defun zetta-modeline-svg--flycheck ()
  "Flycheck indicator: a bug glyph plus error/warning/info counts.
Coloured red when there are errors, orange for warnings, green when clean.
Shown whenever `flycheck-mode' is active."
  (when (and (bound-and-true-p flycheck-mode) (fboundp 'flycheck-count-errors))
    (let* ((counts (flycheck-count-errors flycheck-current-errors))
           (err  (or (cdr (assq 'error counts)) 0))
           (warn (or (cdr (assq 'warning counts)) 0))
           (info (or (cdr (assq 'info counts)) 0))
           (bug  (and (featurep 'nerd-icons)
                      (zetta-line--glyph (ignore-errors (nerd-icons-codicon "nf-cod-bug")))))
           (parts (delq nil (list (and (> err 0)  (format "%de" err))
                                  (and (> warn 0) (format "%dw" warn))
                                  (and (> info 0) (format "%di" info)))))
           (label (concat (or bug "fc")
                          (and parts (concat " " (string-join parts " "))))))
      (zetta-svg-seg
       label 'ml-flycheck
       :color (cond ((> err 0) "#f85149") ((> warn 0) "#d29922") (t "#3fb950"))
       :help (format "flycheck: %d error(s), %d warning(s), %d info" err warn info)
       :action-help "list errors"
       :action (if (fboundp 'flycheck-list-errors) #'flycheck-list-errors #'ignore)
       :menu (delq nil
                   (list (and (fboundp 'flycheck-list-errors) (cons "List errors" #'flycheck-list-errors))
                         (and (fboundp 'flycheck-next-error) (cons "Next error" #'flycheck-next-error))
                         (and (fboundp 'flycheck-previous-error) (cons "Previous error" #'flycheck-previous-error))
                         (and (fboundp 'flycheck-buffer) (cons "Recheck buffer" #'flycheck-buffer))
                         (and (fboundp 'flycheck-verify-setup) (cons "Verify setup" #'flycheck-verify-setup))))))))

(defun zetta-modeline-svg--indicators ()
  (let* ((flags (delq nil
                      (list (and (bound-and-true-p repeat-in-progress) (cons "R" "repeat in progress"))
                            (and (fboundp 'zetta-line-tramp-icon) (zetta-line-tramp-icon) (cons "T" "remote (TRAMP)"))
                            (and (fboundp 'zetta-line-docker-icon) (zetta-line-docker-icon) (cons "D" "docker"))
                            (and (buffer-narrowed-p) (cons "N" "buffer narrowed"))
                            (and (fboundp 'zetta-line-hydra-indicator-icon) (zetta-line-hydra-indicator-icon) (cons "H" "hydra active")))))
         (text (mapconcat #'car flags "")))
    (when (> (length text) 0)
      (zetta-svg-seg
       text 'ml-flags
       :help (concat "flags: " (mapconcat #'cdr flags ", "))
       :action-help (if (buffer-narrowed-p) "widen buffer" "describe")
       :action (if (buffer-narrowed-p) #'widen #'ignore)
       :menu (delq nil
                   (list (and (buffer-narrowed-p) (cons "Widen buffer" #'widen))
                         (and (bound-and-true-p repeat-in-progress) (cons "Repeat help" #'describe-bindings))))))))

(defun zetta-modeline-svg--docpos ()
  (cond
   ((and (eq major-mode 'pdf-view-mode) (fboundp 'pdf-view-current-page))
    (let ((text (ignore-errors (format "%d/%d" (pdf-view-current-page)
                                       (pdf-cache-number-of-pages)))))
      (when text
        (zetta-svg-seg
         text 'ml-docpos
         :help "PDF page"
         :action-help "go to page"
         :action (if (fboundp 'pdf-view-goto-page) #'pdf-view-goto-page #'ignore)
         :menu (delq nil
                     (list (and (fboundp 'pdf-view-goto-page) (cons "Go to page…" #'pdf-view-goto-page))
                           (and (fboundp 'pdf-view-first-page) (cons "First page" #'pdf-view-first-page))
                           (and (fboundp 'pdf-view-last-page) (cons "Last page" #'pdf-view-last-page))))))))
   (t "")))

(defun zetta-modeline-svg--point ()
  (zetta-svg-seg
   (format-mode-line "%l:%c") 'ml-point
   :help "line:column"
   :action-help "go to line"
   :action #'goto-line
   :menu (list (cons "Go to line…" #'goto-line)
               (cons "What cursor position" #'what-cursor-position)
               (cons "Go to char…" #'goto-char))))

;;; header-line breadcrumb content
(defvar zetta-header-line-svg-line1-format
  '((:eval (when (or
                  (eq major-mode 'docker-image-mode)
                  (eq major-mode 'docker-container-mode)
                  (eq major-mode 'docker-volume-mode)
                  (eq major-mode 'embark-collect-mode))
             (propertize
              (window-parameter (selected-window) 'ace-window-path)
              'face 'focus-focused)))
    " "
    (:eval (when (fboundp 'spinner-print) (spinner-print spinner-current)))
    " "
    (:eval
     (let* ((dir default-directory)
            (path (abbreviate-file-name dir))
            (disp (if (> (length path) 30) (zetta-minify-path dir) path)))
       ;; clickable: a keymap (which the header-line harvester picks up) that
       ;; opens dired on the directory; no breadcrumb target prop, so the
       ;; harvester keeps this handler rather than building a jump.
       (propertize disp
                   'keymap (let ((m (make-sparse-keymap)))
                             (define-key m [header-line mouse-1]
                               (lambda () (interactive) (dired dir)))
                             m)
                   'help-echo (format "mouse-1: dired %s" dir))))
    " "
    "%c|%l(%p)")
  "Mode-line construct for header-line row 1 (path / position).")

(defvar zetta-header-line-svg-line2-format
  '((:eval
     (cond
      ((and (boundp 'lsp-mode) lsp-mode)
       (window-parameter nil 'lsp-headerline--string))
      ((derived-mode-p 'org-mode)
       ;; Prefer breadcrumb's imenu crumbs (each carries a clickable keymap our
       ;; header-line harvests) over `org-display-outline-path' (no per-crumb
       ;; keymap, so it would render as plain, non-clickable text).
       (if (fboundp 'breadcrumb-imenu-crumbs)
           (breadcrumb-imenu-crumbs)
         (propertize
          (or (ignore-errors (org-display-outline-path nil t "/" t)) "/")
          'face '(:height 0.8))))
      ((or (equal major-mode 'jsonian-mode))
       (concat (jsonian--display-path (jsonian-path))))
      ((or (equal major-mode 'docker-compose-mode)
           (equal major-mode 'yaml-mode))
       (concat (jpt-yaml-path-to-point)))
      (t (when (fboundp 'breadcrumb-imenu-crumbs) (breadcrumb-imenu-crumbs))))))
  "Mode-line construct for header-line row 2 (lsp / org / imenu crumbs).")

(defun zetta-header-line-svg--line1 ()
  "Render the first breadcrumb row (path / position), crumbs clickable."
  (zetta-svg-segs-from-propertized
   (format-mode-line zetta-header-line-svg-line1-format) 'hl1))

(defun zetta-header-line-svg--line2 ()
  "Render the second breadcrumb row (lsp / org / imenu crumbs), crumbs clickable."
  (zetta-svg-segs-from-propertized
   (format-mode-line zetta-header-line-svg-line2-format) 'hl2))

;;;; Nerd-font glyph icons for the SVG bars
;; ----------------------------------------------------------------
;; The bars render in a scalable Nerd Font (`zetta-svg-line-font'), so
;; icons are just text glyphs (nerd-icons codepoints): they flow inline
;; with the text in one native SVG <text>, font-accurate -- no separate
;; positioning, no char-advance estimation, no svg-lib path injection.
;; Each segment returns the bare glyph string (properties stripped) or nil.

(defvar zetta-svg-line-font "Terminess Nerd Font Mono"
  "Font family for the SVG bars (tab-bar, mode-line, tab-line, header-line).
A single-width Nerd Font carrying the icon glyphs, so icons render inline
as ordinary text.  Terminess is the Nerd-patched Terminus, keeping that
look; any Nerd Font works (e.g. \"JetBrainsMono Nerd Font Mono\").  Buffers
keep their own font (`zetta-font').")

(defun zetta-line--glyph (s)
  "Return nerd-icons glyph string S without text properties, or nil if empty."
  (and (stringp s)
       (let ((g (substring-no-properties s)))
         (and (> (length (string-trim g)) 0) g))))

;; Text-scale responsiveness now lives in the svg-line package
;; (`svg-line-scale-with-text-scale'): the engine scales line sizes with
;; the default-face height, so the bars track default-text-scale without
;; any config-side helper.

(defun zetta-line-buffer-glyph (&optional buffer)
  "Nerd-font file-type glyph for BUFFER (current by default), or nil."
  (and (featurep 'nerd-icons)
       (with-current-buffer (or buffer (current-buffer))
         (zetta-line--glyph (ignore-errors (nerd-icons-icon-for-buffer))))))

;;; mode line
(defun zetta-modeline-svg--file-icon ()
  "File-type glyph for the current buffer."
  (zetta-line-buffer-glyph))

(defun zetta-modeline-svg--copilot-icon ()
  "GitHub Copilot glyph, shown when `copilot-mode' is on.  Click toggles it."
  (when (bound-and-true-p copilot-mode)
    (let ((g (and (featurep 'nerd-icons)
                  (zetta-line--glyph (ignore-errors (nerd-icons-octicon "nf-oct-copilot"))))))
      (when g
        (zetta-svg-seg
         g 'ml-copilot
         :help "GitHub Copilot (on)"
         :action-help "toggle Copilot"
         :action (if (fboundp 'copilot-mode) #'copilot-mode #'ignore)
         :menu (delq nil
                     (list (and (fboundp 'copilot-mode) (cons "Toggle Copilot" #'copilot-mode))
                           (and (fboundp 'copilot-complete) (cons "Complete now" #'copilot-complete))
                           (and (fboundp 'copilot-diagnose) (cons "Diagnose" #'copilot-diagnose)))))))))

(defun zetta-modeline-svg--vc-icon ()
  "Git glyph, shown when the file is under git version control."
  (when (and (buffer-file-name) (fboundp 'vc-git-root) (vc-git-root (buffer-file-name)))
    (and (featurep 'nerd-icons)
         (zetta-line--glyph (ignore-errors (nerd-icons-devicon "nf-dev-git"))))))

(defun zetta-modeline-svg--branch-icon ()
  "Branch glyph, shown when the file is on a git branch."
  (when (and (buffer-file-name) (fboundp 'vc-git-root) (vc-git-root (buffer-file-name)))
    (and (featurep 'nerd-icons)
         (zetta-line--glyph (ignore-errors (nerd-icons-octicon "nf-oct-git_branch"))))))

(defun zetta-modeline-svg--file-progress ()
  "Compact progress pie of point's position through the buffer."
  (let* ((total (max 1 (- (point-max) (point-min))))
         (frac (/ (float (- (point) (point-min))) total)))
    (list :svg-pie frac "#2a4d77" "#d4dcea")))

;;; tab bar
(defun zetta-tab-bar-file-icon ()
  "File-type glyph for the current buffer (tab bar)."
  (zetta-line-buffer-glyph))

(defun zetta-tab-bar-mu4e-icon ()
  "Mail glyph, shown when mu4e has a non-empty modeline string."
  (when (and (fboundp 'mu4e--modeline-string)
             (let ((s (ignore-errors (mu4e--modeline-string))))
               (and s (> (length (string-trim s)) 0))))
    (and (featurep 'nerd-icons)
         (zetta-line--glyph (ignore-errors (nerd-icons-mdicon "nf-md-email_outline"))))))

(defun zetta-tab-bar-mu4e-text ()
  "The mu4e modeline string (unread counts, etc.), trimmed."
  (when (fboundp 'mu4e--modeline-string)
    (string-trim (or (ignore-errors (mu4e--modeline-string)) ""))))

(defun zetta-tab-bar-clock ()
  "The `display-time' clock string, trimmed."
  (when (boundp 'display-time-string) (string-trim (or display-time-string ""))))

(defcustom zetta-tab-bar-battery-low 20
  "At or below this battery percentage the indicator is drawn red."
  :type 'integer :group 'zetta)
(defcustom zetta-tab-bar-battery-medium 50
  "At or below this battery percentage the indicator is drawn orange (red wins
below `zetta-tab-bar-battery-low'); above it the indicator is green."
  :type 'integer :group 'zetta)
(defcustom zetta-tab-bar-battery-colors '((low . "#f85149")
                                          (medium . "#d29922")
                                          (full . "#3fb950"))
  "Colours for low / medium / full battery levels."
  :type '(alist :key-type symbol :value-type color) :group 'zetta)

(defun zetta-tab-bar--battery-data ()
  "Return (PCT . PLUGGED) from `battery-status-function', or nil.
PCT is the integer charge percentage; PLUGGED is non-nil when on AC power."
  (when (and (boundp 'battery-status-function) (functionp battery-status-function))
    (let ((data (ignore-errors (funcall battery-status-function))))
      (when data
        (cons (string-to-number (or (cdr (assq ?p data)) "0"))
              (and (member (cdr (assq ?L data)) '("AC" "on-line" "on")) t))))))

(defun zetta-tab-bar--battery-fa-glyph (pct)
  "Font-Awesome battery glyph (nf-fa-battery_0..4) for PCT, or nil."
  (let ((n (cond ((>= pct 88) 4) ((>= pct 63) 3) ((>= pct 38) 2)
                 ((>= pct 13) 1) (t 0))))
    (and (featurep 'nerd-icons)
         (zetta-line--glyph (ignore-errors
                              (nerd-icons-faicon (format "nf-fa-battery_%d" n)))))))

(defun zetta-tab-bar--battery-color (pct)
  "Return the level colour (red/orange/green) for PCT."
  (cdr (assq (cond ((<= pct zetta-tab-bar-battery-low) 'low)
                   ((<= pct zetta-tab-bar-battery-medium) 'medium)
                   (t 'full))
             zetta-tab-bar-battery-colors)))

(defun zetta-tab-bar-workspace-lighter ()
  "The space-tree lighter string, or nil.
NB: `space-tree-modeline-lighter' is a FUNCTION (it returns the current-space
string like \"{ 1' }\"), not a variable -- so it must be called."
  (and (fboundp 'space-tree-modeline-lighter)
       (let ((s (ignore-errors (space-tree-modeline-lighter))))
         (and (stringp s) (> (length (string-trim s)) 0)
              (substring-no-properties s)))))

(defun zetta-tab-bar-workspace-icon ()
  "Workspace glyph, shown when space-tree has a lighter."
  (when (zetta-tab-bar-workspace-lighter)
    (and (featurep 'nerd-icons)
         (zetta-line--glyph (ignore-errors (nerd-icons-mdicon "nf-md-view_dashboard"))))))

(defun zetta-tab-bar-workspace-text ()
  "The space-tree workspace lighter string."
  (zetta-tab-bar-workspace-lighter))

(defun zetta-tab-bar-spotify-icon ()
  "Spotify glyph, sits to the left of the spot mode-line string."
  (and (featurep 'nerd-icons)
       (zetta-line--glyph (ignore-errors (nerd-icons-faicon "nf-fa-spotify")))))

(defun zetta-tab-bar-emacs-icon ()
  "Emacs-logo glyph for the full-height tab-bar masthead, or nil."
  (and (featurep 'nerd-icons)
       (zetta-line--glyph (ignore-errors (nerd-icons-sucicon "nf-custom-emacs")))))

;;; tab-bar interactive (svg-only) wrappers
;; ----------------------------------------------------------------
;; The base tab-bar segments above are shared with the *text* `tab-bar-format'
;; fallback, so they must keep returning plain strings.  These wrappers add
;; click/hover/menu for the SVG tab bar only; `zetta-tab-bar-svg-lines' uses
;; them in place of the plain segments (and folds in adjacent glyph icons).

(defun zetta-tab-bar-svg--buffer ()
  "Clickable tab-bar buffer name (switch buffer; menu of buffer/file actions)."
  (zetta-svg-seg
   (zetta-buffer-name) 'tb-buffer
   :help (format "buffer: %s" (buffer-name))
   :action-help "switch buffer"
   :action (if (fboundp 'consult-buffer) #'consult-buffer #'switch-to-buffer)
   :menu (delq nil
               (list (cons "Switch buffer…" (if (fboundp 'consult-buffer)
                                                #'consult-buffer #'switch-to-buffer))
                     (cons "Find file…" #'find-file)
                     (and (fboundp 'consult-recent-file)
                          (cons "Recent files…" #'consult-recent-file))
                     (cons "Save buffer" #'save-buffer)))))

(defun zetta-tab-bar-svg--modal ()
  "Clickable tab-bar modal-system indicator (keyboard glyph; describe bindings)."
  (let ((kbd (and (featurep 'nerd-icons)
                  (zetta-line--glyph (ignore-errors (nerd-icons-mdicon "nf-md-keyboard_variant"))))))
    (zetta-svg-seg
     (concat (and kbd (concat kbd " ")) (zetta-tab-bar-modal)) 'tb-modal
     :help "modal system"
     :action-help "describe bindings"
     :action #'describe-bindings
     :menu (list (cons "Describe bindings" #'describe-bindings)
                 (cons "Command (M-x)" #'execute-extended-command)))))

(defun zetta-tab-bar-svg--spotify ()
  "Clickable Spotify cluster (glyph + spot string): play/pause; transport menu."
  (let* ((icon (ignore-errors (zetta-tab-bar-spotify-icon)))
         (txt  (zetta-tab-bar-spot-mode-line-string))
         (label (concat (and icon (concat icon " ")) txt)))
    (zetta-svg-seg
     label 'tb-spotify
     :help "Spotify"
     :action-help "pause/play"
     :action (cond ((fboundp 'spot-player-pause) #'spot-player-pause)
                   ((fboundp 'spot-player-play) #'spot-player-play)
                   (t #'ignore))
     :menu (delq nil
                 (list (and (fboundp 'spot-player-play) (cons "Play" #'spot-player-play))
                       (and (fboundp 'spot-player-pause) (cons "Pause" #'spot-player-pause))
                       (and (fboundp 'spot-player-next) (cons "Next" #'spot-player-next))
                       (and (fboundp 'spot-player-previous) (cons "Previous" #'spot-player-previous))
                       (and (fboundp 'spot-consult-search) (cons "Search…" #'spot-consult-search))
                       (and (fboundp 'spot-add-current-track-to-playlist)
                            (cons "Add to playlist…" #'spot-add-current-track-to-playlist)))))))

(defun zetta-tab-bar-svg--mu4e ()
  "Clickable mail cluster (glyph + counts): open mu4e; mail menu."
  (let* ((icon (ignore-errors (zetta-tab-bar-mu4e-icon)))
         (txt  (zetta-tab-bar-mu4e-text))
         (label (concat (and icon (concat icon " ")) txt)))
    (when (and label (> (length (string-trim label)) 0))
      (zetta-svg-seg
       label 'tb-mu4e
       :help "email (mu4e)"
       :action-help "open mail"
       :action (if (fboundp 'mu4e) #'mu4e #'ignore)
       :menu (delq nil
                   (list (and (fboundp 'mu4e) (cons "Open mu4e" #'mu4e))
                         (and (fboundp 'mu4e-update-mail-and-index)
                              (cons "Update mail"
                                    (lambda () (interactive) (mu4e-update-mail-and-index t))))
                         (and (fboundp 'mu4e-compose-new) (cons "Compose" #'mu4e-compose-new))))))))

(defun zetta-tab-bar-svg--clock ()
  "Clickable clock (clock glyph + time): world clock; calendar menu."
  (let* ((txt (zetta-tab-bar-clock))
         (icon (and (featurep 'nerd-icons)
                    (zetta-line--glyph (ignore-errors (nerd-icons-mdicon "nf-md-clock_outline"))))))
    (when (and txt (> (length (string-trim txt)) 0))
      (zetta-svg-seg
       (concat (and icon (concat icon " ")) txt) 'tb-clock
       :help "time"
       :action-help "world clock"
       :action (if (fboundp 'world-clock) #'world-clock #'display-time-world)
       :menu (delq nil
                   (list (and (fboundp 'world-clock) (cons "World clock" #'world-clock))
                         (cons "Calendar" #'calendar)
                         (and (fboundp 'org-agenda) (cons "Agenda" #'org-agenda))))))))

(defun zetta-tab-bar-svg--battery ()
  "Clickable battery cluster: a Font-Awesome battery glyph coloured by level
\(red/orange/green), a plug glyph when on AC, and the percentage.  Click shows
the full battery status."
  (when (bound-and-true-p display-battery-mode)
    (let ((d (zetta-tab-bar--battery-data)))
      (when d
        (let* ((pct (car d)) (plugged (cdr d))
               (batt (zetta-tab-bar--battery-fa-glyph pct))
               (plug (and plugged (featurep 'nerd-icons)
                          (zetta-line--glyph (ignore-errors (nerd-icons-faicon "nf-fa-plug")))))
               (label (concat (and plug (concat plug " "))
                              (and batt (concat batt " "))
                              (format "%d%%" pct))))
          (when (> (length (string-trim label)) 0)
            (zetta-svg-seg
             label 'tb-battery
             :color (zetta-tab-bar--battery-color pct)
             :help (format "battery: %d%%%s" pct (if plugged " (plugged in)" ""))
             :action-help "battery status"
             :action #'battery
             :menu (list (cons "Battery status" #'battery)
                         (cons "Toggle battery display" #'display-battery-mode)))))))))

(defun zetta-tab-bar-svg--workspace ()
  "Clickable workspace cluster (glyph + name): switch space; space-tree menu."
  (let* ((icon (ignore-errors (zetta-tab-bar-workspace-icon)))
         (txt  (zetta-tab-bar-workspace-text))
         (label (concat (and icon (concat icon " ")) (and (stringp txt) txt))))
    (when (and label (> (length (string-trim label)) 0))
      (zetta-svg-seg
       label 'tb-workspace
       :help "workspace"
       :action-help "switch workspace"
       :action (cond ((fboundp 'space-tree-switch-space-by-name) #'space-tree-switch-space-by-name)
                     ((fboundp 'space-tree-switch-current-level) #'space-tree-switch-current-level)
                     (t #'ignore))
       :menu (delq nil
                   (list (and (fboundp 'space-tree-switch-space-by-name)
                              (cons "Switch by name…" #'space-tree-switch-space-by-name))
                         (and (fboundp 'space-tree-go-left) (cons "Previous space" #'space-tree-go-left))
                         (and (fboundp 'space-tree-go-right) (cons "Next space" #'space-tree-go-right))
                         (and (fboundp 'space-tree-create-space-current-level)
                              (cons "New space (here)" #'space-tree-create-space-current-level))
                         (and (fboundp 'space-tree-create-space-top-level)
                              (cons "New space (top)" #'space-tree-create-space-top-level))
                         (and (fboundp 'space-tree-name-current-space)
                              (cons "Rename space…" #'space-tree-name-current-space))
                         (and (fboundp 'space-tree-delete-space)
                              (cons "Delete space" #'space-tree-delete-space))))))))

;;; line-utils.el ends here
