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
  ;; copilot is shown as an icon (zetta-modeline-svg--copilot-icon), not text
  (concat
   (when (and (boundp 'lsp-mode) lsp-mode) "lsp ")))

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
  "Default `svg-lib' icon collection for file-type icons.
An entry in `zetta-line-icon-mode-alist' / `zetta-line-icon-ext-alist'
may override it per icon by giving a (COLLECTION . NAME) cons instead of
a bare NAME string -- e.g. the GNU Emacs logo lives in the brand-logo
collection \"simple\" as \"gnuemacs\".")

(defvar zetta-line-icon-mode-alist
  ;; Prefer official brand logos from the "simple" (simple-icons)
  ;; collection; fall back to neutral "material" glyphs for things with no
  ;; brand mark (generic terminal, SQL, folder).
  '((emacs-lisp-mode       . ("simple" . "gnuemacs"))
    (lisp-interaction-mode . ("simple" . "gnuemacs"))
    (python-mode           . ("simple" . "python"))
    (python-ts-mode        . ("simple" . "python"))
    (js-mode               . ("simple" . "javascript"))
    (js2-mode              . ("simple" . "javascript"))
    (js-ts-mode            . ("simple" . "javascript"))
    (rjsx-mode             . ("simple" . "react"))
    (typescript-mode       . ("simple" . "typescript"))
    (typescript-ts-mode    . ("simple" . "typescript"))
    (tsx-ts-mode           . ("simple" . "react"))
    (json-mode             . ("simple" . "json"))
    (json-ts-mode          . ("simple" . "json"))
    (jsonian-mode          . ("simple" . "json"))
    (yaml-mode             . ("simple" . "yaml"))
    (yaml-ts-mode          . ("simple" . "yaml"))
    (markdown-mode         . ("simple" . "markdown"))
    (org-mode              . ("simple" . "org"))
    (sh-mode               . ("simple" . "gnubash"))
    (bash-ts-mode          . ("simple" . "gnubash"))
    (shell-mode            . ("simple" . "gnubash"))
    (eshell-mode           . ("simple" . "gnubash"))
    (vterm-mode            . "console")
    (dockerfile-mode       . ("simple" . "docker"))
    (dockerfile-ts-mode    . ("simple" . "docker"))
    (docker-compose-mode   . ("simple" . "docker"))
    (terraform-mode        . ("simple" . "terraform"))
    (sql-mode              . "database")
    (web-mode              . ("simple" . "html5"))
    (html-mode             . ("simple" . "html5"))
    (mhtml-mode            . ("simple" . "html5"))
    (css-mode              . ("simple" . "css"))
    (css-ts-mode           . ("simple" . "css"))
    (go-mode               . ("simple" . "go"))
    (go-ts-mode            . ("simple" . "go"))
    (rust-mode             . ("simple" . "rust"))
    (rust-ts-mode          . ("simple" . "rust"))
    (ruby-mode             . ("simple" . "ruby"))
    (java-mode             . ("simple" . "openjdk"))
    (php-mode              . ("simple" . "php"))
    (lua-mode              . ("simple" . "lua"))
    (c-mode                . ("simple" . "c"))
    (c-ts-mode             . ("simple" . "c"))
    (c++-mode              . ("simple" . "cplusplus"))
    (c++-ts-mode           . ("simple" . "cplusplus"))
    (magit-status-mode     . ("simple" . "git"))
    (dired-mode            . "folder"))
  "Map major mode -> `svg-lib' icon, a NAME or a (COLLECTION . NAME) cons.")

(defvar zetta-line-icon-ext-alist
  '(("el"   . ("simple" . "gnuemacs"))
    ("py"   . ("simple" . "python"))
    ("js"   . ("simple" . "javascript")) ("mjs" . ("simple" . "javascript"))
    ("jsx"  . ("simple" . "react"))      ("tsx" . ("simple" . "react"))
    ("ts"   . ("simple" . "typescript"))
    ("json" . ("simple" . "json"))
    ("yml"  . ("simple" . "yaml"))       ("yaml" . ("simple" . "yaml"))
    ("md"   . ("simple" . "markdown"))   ("markdown" . ("simple" . "markdown"))
    ("org"  . ("simple" . "org"))
    ("sh"   . ("simple" . "gnubash"))    ("bash" . ("simple" . "gnubash"))
    ("sql"  . "database")
    ("html" . ("simple" . "html5"))      ("htm" . ("simple" . "html5"))
    ("css"  . ("simple" . "css"))
    ("go"   . ("simple" . "go"))         ("rs" . ("simple" . "rust"))
    ("c"    . ("simple" . "c"))          ("h"  . ("simple" . "c"))
    ("cpp"  . ("simple" . "cplusplus"))  ("cc" . ("simple" . "cplusplus"))
    ("hpp"  . ("simple" . "cplusplus"))
    ("rb"   . ("simple" . "ruby"))       ("java" . ("simple" . "openjdk"))
    ("php"  . ("simple" . "php"))        ("lua"  . ("simple" . "lua"))
    ("toml" . ("simple" . "toml"))       ("tf"   . ("simple" . "terraform")))
  "Map file extension -> `svg-lib' icon, a NAME or a (COLLECTION . NAME) cons.")

(defvar zetta-line-icon-default "file-outline"
  "Fallback `svg-lib' icon NAME when neither mode nor extension matches.")

(defun zetta-line-icon--spec (val)
  "Normalise an icon alist VAL to a (COLLECTION . NAME) cons, or nil.
VAL is either a bare NAME string (uses `zetta-line-icon-collection') or an
explicit (COLLECTION . NAME) cons."
  (cond ((null val) nil)
        ((consp val) val)
        ((stringp val) (cons zetta-line-icon-collection val))))

(defun zetta-line-icon-spec-for (buffer)
  "Return the (COLLECTION . NAME) icon spec for BUFFER (by mode, then extension)."
  (with-current-buffer buffer
    (zetta-line-icon--spec
     (or (alist-get major-mode zetta-line-icon-mode-alist)
         (let ((ext (and buffer-file-name
                         (downcase (or (file-name-extension buffer-file-name) "")))))
           (and ext (> (length ext) 0)
                (cdr (assoc ext zetta-line-icon-ext-alist))))
         zetta-line-icon-default))))

(defun zetta-line-icon-data-cached (collection name)
  "Return cached (VIEWBOX . PATHS) for icon NAME of COLLECTION, or nil.
Render-safe: never loads svg-lib or fetches; on a miss it schedules an
idle prefetch (which requests a redisplay when it lands) and returns nil."
  (when (and zetta-line-icons (fboundp 'svg-line-icon-prefetch))
    (or (and (featurep 'svg-lib) (svg-line-icon-data name collection t))
        (progn (svg-line-icon-prefetch name collection) nil))))

(defun zetta-line-file-icon-data (buffer)
  "Return cached (VIEWBOX . PATHS) file-type icon data for BUFFER, or nil."
  (when (buffer-live-p buffer)
    (let ((spec (zetta-line-icon-spec-for buffer)))
      (and spec (zetta-line-icon-data-cached (car spec) (cdr spec))))))

(defun zetta-line-icon-token (collection name &optional fill)
  "Return an inline icon token (:svg-icon DATA FILL) for NAME/COLLECTION, or nil.
For use as / inside a `svg-line' segment.  FILL nil inherits the side's
foreground colour."
  (let ((d (zetta-line-icon-data-cached collection name)))
    (and d (list :svg-icon d fill))))

(defun zetta-line-file-icon-token (buffer &optional fill)
  "Return an inline file-type icon token for BUFFER, or nil."
  (let ((d (zetta-line-file-icon-data buffer)))
    (and d (list :svg-icon d fill))))

;;;; Inline icon + progress-bar segments (SVG mode line / tab bar)
;; ----------------------------------------------------------------
;; Each returns an svg-line segment token -- (:svg-icon DATA FILL) or
;; (:svg-bar FRACTION WIDTH FILL BG) -- or nil to contribute nothing.
;; Bound into the line composition in modeline-svg.el / tab-bar-svg.el.
;; Icon segments are atomic (one icon); pair them with a sibling text
;; segment to show "icon + data".

;;; mode line
(defun zetta-modeline-svg--file-icon ()
  "Inline file-type icon for the current buffer."
  (zetta-line-file-icon-token (current-buffer)))

(defun zetta-modeline-svg--copilot-icon ()
  "Inline GitHub Copilot icon, shown when `copilot-mode' is on."
  (when (bound-and-true-p copilot-mode)
    (zetta-line-icon-token "simple" "githubcopilot")))

(defun zetta-modeline-svg--vc-icon ()
  "Inline git logo, shown when the file is under git version control."
  (when (and (buffer-file-name) (fboundp 'vc-git-root)
             (vc-git-root (buffer-file-name)))
    (zetta-line-icon-token "simple" "git")))

(defun zetta-modeline-svg--branch-icon ()
  "Inline branch icon, shown when the file is on a git branch."
  (when (and (buffer-file-name) (fboundp 'vc-git-root)
             (vc-git-root (buffer-file-name)))
    (zetta-line-icon-token "octicons" "git-branch")))

(defun zetta-modeline-svg--file-progress ()
  "Compact progress pie of point's position through the buffer."
  (let* ((total (max 1 (- (point-max) (point-min))))
         (frac (/ (float (- (point) (point-min))) total)))
    (list :svg-pie frac "#2a4d77" "#d4dcea")))

;;; tab bar
(defun zetta-tab-bar-file-icon ()
  "Inline file-type icon for the current buffer (tab bar)."
  (zetta-line-file-icon-token (current-buffer)))

(defun zetta-tab-bar-mu4e-icon ()
  "Mail icon, shown when mu4e has a non-empty modeline string."
  (when (and (fboundp 'mu4e--modeline-string)
             (let ((s (ignore-errors (mu4e--modeline-string))))
               (and s (> (length (string-trim s)) 0))))
    (zetta-line-icon-token "octicons" "mail")))

(defun zetta-tab-bar-mu4e-text ()
  "The mu4e modeline string (unread counts, etc.)."
  (when (fboundp 'mu4e--modeline-string)
    (ignore-errors (mu4e--modeline-string))))

(defun zetta-tab-bar-clock ()
  "The `display-time' clock string."
  (when (boundp 'display-time-string) display-time-string))

(defun zetta-tab-bar--battery-icon-name ()
  "Material battery icon name reflecting the current percentage."
  (let* ((s (and (boundp 'battery-mode-line-string) battery-mode-line-string))
         (pct (and s (string-match "\\([0-9]+\\)%" s)
                   (string-to-number (match-string 1 s)))))
    (cond ((null pct)   "battery")
          ((>= pct 95)  "battery")
          ((<= pct 10)  "battery-alert")
          (t (format "battery-%d0" (max 1 (round (/ pct 10.0))))))))

(defun zetta-tab-bar-battery-icon ()
  "Battery icon (percentage-aware) when `display-battery-mode' is on."
  (when (and (bound-and-true-p display-battery-mode)
             (boundp 'battery-mode-line-string))
    (zetta-line-icon-token "material" (zetta-tab-bar--battery-icon-name))))

(defun zetta-tab-bar-battery-text ()
  "The battery percentage string (kept as-is, including its trailing space)."
  (when (boundp 'battery-mode-line-string)
    battery-mode-line-string))

(defun zetta-tab-bar-workspace-icon ()
  "Workspace icon, shown when the space-tree lighter is active."
  (when (and (boundp 'space-tree-modeline-lighter) space-tree-modeline-lighter)
    (zetta-line-icon-token "material" "view-dashboard")))

;;; line-utils.el ends here
