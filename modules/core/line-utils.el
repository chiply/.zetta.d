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
  (or
   (when (and (boundp 'evil-mode) evil-mode) "evil")
   (when (and (boundp 'meow-mode) meow-mode) "meow")
   (when (not (or (and (boundp 'evil-mode) evil-mode)
                  (and (boundp 'meow-mode) meow-mode)))
     "emacs")))

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
  (if (fboundp 'zetta-tab-bar-modal) (or (zetta-tab-bar-modal) "") ""))

(defun zetta-modeline-svg--ace ()
  (or (window-parameter (selected-window) 'ace-window-path) ""))

(defun zetta-modeline-svg--buffer ()
  (let ((n (buffer-name)))
    (if (> (length n) 40) (concat (substring n 0 39) "…") n)))

(defun zetta-modeline-svg--mode ()
  (format-mode-line mode-name))

(defun zetta-modeline-svg--vc ()
  (when (and (fboundp 'vc-git-root)
             (vc-git-root (or (buffer-file-name) default-directory)))
    (let ((repo   (ignore-errors (nth 0 (zetta-get-repo-name))))
          (branch (ignore-errors (vc-git--symbolic-ref
                                  (or (buffer-file-name) default-directory)))))
      (concat (or repo "") (and branch (concat ":" branch))))))

(defun zetta-modeline-svg--checkers ()
  (concat
   (when (and (boundp 'lsp-mode) lsp-mode) "lsp ")
   (when (and (boundp 'copilot-mode) copilot-mode) "copilot ")))

(defun zetta-modeline-svg--flycheck ()
  (if (fboundp 'flycheck-indicator--mode-line)
      (let ((text (flycheck-indicator--mode-line)))
        (if (string= " not-checked" text) "" (substring-no-properties text)))
    ""))

(defun zetta-modeline-svg--indicators ()
  (concat
   (when (bound-and-true-p repeat-in-progress) "R")
   (when (and (fboundp 'zetta-line-tramp-icon) (zetta-line-tramp-icon)) "T")
   (when (and (fboundp 'zetta-line-docker-icon) (zetta-line-docker-icon)) "D")
   (when (and (fboundp 'zetta-line-narrowed-icon) (zetta-line-narrowed-icon)) "N")
   (when (and (fboundp 'zetta-line-hydra-indicator-icon) (zetta-line-hydra-indicator-icon)) "H")))

(defun zetta-modeline-svg--docpos ()
  (cond
   ((and (eq major-mode 'pdf-view-mode) (fboundp 'pdf-view-current-page))
    (ignore-errors (format "%d/%d" (pdf-view-current-page) (pdf-cache-number-of-pages))))
   (t "")))

(defun zetta-modeline-svg--point ()
  (format-mode-line "%l:%c"))

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
     (let ((path (abbreviate-file-name default-directory)))
       (if (> (length path) 30) (zetta-minify-path default-directory) path)))
    " "
    "%c|%l(%p)")
  "Mode-line construct for header-line row 1 (path / position).")

(defvar zetta-header-line-svg-line2-format
  '((:eval
     (cond
      ((and (boundp 'lsp-mode) lsp-mode)
       (window-parameter nil 'lsp-headerline--string))
      ((string= major-mode "org-mode")
       (propertize
        (or (ignore-errors (org-display-outline-path nil t "/" t)) "/")
        'face '(:height 0.8)))
      ((or (equal major-mode 'jsonian-mode))
       (concat (jsonian--display-path (jsonian-path))))
      ((or (equal major-mode 'docker-compose-mode)
           (equal major-mode 'yaml-mode))
       (concat (jpt-yaml-path-to-point)))
      (t (when (fboundp 'breadcrumb-imenu-crumbs) (breadcrumb-imenu-crumbs))))))
  "Mode-line construct for header-line row 2 (lsp / org / imenu crumbs).")

(defun zetta-header-line-svg--line1 ()
  "Render the first breadcrumb row (path / position)."
  (format-mode-line zetta-header-line-svg-line1-format))

(defun zetta-header-line-svg--line2 ()
  "Render the second breadcrumb row (lsp / org / imenu crumbs)."
  (format-mode-line zetta-header-line-svg-line2-format))

;;;; File-type icons (shared by the SVG tab-bar and tab-line)
;; ----------------------------------------------------------------
;; Resolve a buffer to vector icon data (from svg-line-icons + svg-lib).
;; Deliberately NEVER fetches or loads svg-lib on the render path: returns
;; already-cached data or nil, warming the cache from an idle prefetch.
;; That keeps the redisplay path free of disk/network/library loads --
;; important given the tab-bar's history of redisplay freezes.

(defvar zetta-line-icons t
  "When non-nil, draw file-type icons in the SVG tab-bar and tab-line.")

(defvar zetta-line-icon-collection "material"
  "`svg-lib' icon collection used for file-type icons.")

(defvar zetta-line-icon-mode-alist
  '((emacs-lisp-mode       . "lambda")
    (lisp-interaction-mode . "lambda")
    (python-mode           . "language-python")
    (python-ts-mode        . "language-python")
    (js-mode               . "language-javascript")
    (js2-mode              . "language-javascript")
    (js-ts-mode            . "language-javascript")
    (typescript-mode       . "language-typescript")
    (typescript-ts-mode    . "language-typescript")
    (json-mode             . "code-json")
    (jsonian-mode          . "code-json")
    (yaml-mode             . "code-tags")
    (markdown-mode         . "language-markdown")
    (org-mode              . "file-document-outline")
    (sh-mode               . "console")
    (bash-ts-mode          . "console")
    (vterm-mode            . "console")
    (shell-mode            . "console")
    (eshell-mode           . "console")
    (dockerfile-mode       . "docker")
    (docker-compose-mode   . "docker")
    (sql-mode              . "database")
    (web-mode              . "language-html5")
    (html-mode             . "language-html5")
    (css-mode              . "language-css3")
    (magit-status-mode     . "git")
    (dired-mode            . "folder"))
  "Map major mode -> `svg-lib' icon NAME for the file-type icon.")

(defvar zetta-line-icon-ext-alist
  '(("el" . "lambda") ("py" . "language-python")
    ("js" . "language-javascript") ("jsx" . "language-javascript")
    ("ts" . "language-typescript") ("tsx" . "language-typescript")
    ("json" . "code-json") ("yml" . "code-tags") ("yaml" . "code-tags")
    ("md" . "language-markdown") ("org" . "file-document-outline")
    ("sh" . "console") ("sql" . "database") ("html" . "language-html5")
    ("css" . "language-css3") ("go" . "language-go") ("rs" . "language-rust")
    ("c" . "language-c") ("h" . "language-c") ("cpp" . "language-cpp")
    ("rb" . "language-ruby") ("java" . "language-java") ("php" . "language-php")
    ("lua" . "language-lua") ("toml" . "code-tags"))
  "Map file extension -> `svg-lib' icon NAME (fallback when mode is unknown).")

(defvar zetta-line-icon-default "file-outline"
  "Fallback `svg-lib' icon NAME when neither mode nor extension matches.")

(defun zetta-line-icon-name-for (buffer)
  "Return the `svg-lib' icon NAME for BUFFER (by major mode, then extension)."
  (with-current-buffer buffer
    (or (alist-get major-mode zetta-line-icon-mode-alist)
        (let ((ext (and buffer-file-name
                        (downcase (or (file-name-extension buffer-file-name) "")))))
          (and ext (> (length ext) 0)
               (cdr (assoc ext zetta-line-icon-ext-alist))))
        zetta-line-icon-default)))

(defun zetta-line-file-icon-data (buffer)
  "Return cached (VIEWBOX . PATHS) icon data for BUFFER, or nil.
Never loads svg-lib or fetches on the render path: if svg-lib is not yet
loaded, or the icon is not cached, schedule an idle prefetch and return
nil for now (the prefetch requests a redisplay when it lands)."
  (when (and zetta-line-icons (fboundp 'svg-line-icon-prefetch) (buffer-live-p buffer))
    (let ((name (zetta-line-icon-name-for buffer)))
      (when name
        (or (and (featurep 'svg-lib)
                 (svg-line-icon-data name zetta-line-icon-collection t))
            (progn (svg-line-icon-prefetch name zetta-line-icon-collection) nil))))))

;;; line-utils.el ends here
