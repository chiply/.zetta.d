;;; bootstrap-modules.el --- Configure module loading system -*- lexical-binding: t; -*-

;; Module system for zetta.d
;; Provides `zetta-modules!' macro for declaring which modules to load.
;; Also defines user-configurable variables for distro customization.

;;; User-configurable variables
;; These can be set in ~/.zetta.el before `zetta-modules!' is called.

(defvar zetta-font "Terminus (TTF)"
  "Default font family.  Set in ~/.zetta.el.
Download Terminus TTF from https://files.ax86.net/terminus-ttf/")

(defvar zetta-theme 'modus-operandi
  "Default color theme to load at startup.  Set in ~/.zetta.el.")

(defvar zetta-literature-dir "~/.lit/"
  "Directory for bibliography files and PDFs.  Set in ~/.zetta.el.")

(defvar zetta-logseq-dir "~/logseq/pages/"
  "Directory containing Logseq pages.  Set in ~/.zetta.el.")

(defvar zetta-use-lockfile t
  "When non-nil, pin packages to versions in elpaca-lock.el.
Set to nil in ~/.zetta.el for bleeding-edge packages.")

;; Apply lockfile preference (elpaca-lock-file is set in bootstrap-elpaca.el)
(unless zetta-use-lockfile
  (setq elpaca-lock-file nil))

;;; Module system

(defvar zetta-modules-dir (expand-file-name "modules" user-emacs-directory)
  "Directory containing module subdirectories.")

(defvar zetta-modules nil
  "Alist of enabled modules after `zetta-modules!' is called.
Each entry is (CATEGORY . SPEC) where SPEC is t for all files,
a list of symbols to include, or a list with -prefixed symbols
for exclusions.")

(defvar zetta-module-load-order
  '(core completion ui editor lang tools app org term)
  "Order in which module categories are loaded.
Categories not in this list are loaded after those that are,
in the order they appear in the `zetta-modules!' declaration.")

;; Default file ordering per module.
;; When a category is loaded with `t' (all files), files are loaded in
;; this order.  Files present on disk but not listed here are appended
;; alphabetically at the end.
(defvar zetta--default-file-order
  '((core . ("emacs.el" "simple.el" "utility.el" "interface.el" "desktop.el"
             "remote.el" "security.el" "keys.el" "xref.el" "project.el"
             "persist.el" "smerge-mode.el" "repeat-mode.el" "saveplace.el"
             "savehist.el" "comint.el" "cleanup.el" "buffer.el" "ibuffer.el"
             "bufler.el" "line-utils.el" "helpful.el" "elisp-mode.el" "prose.el"))
    (completion . ("completion.el" "cape.el" "dabbrev.el" "recursion-indicator.el"
                   "helm.el" "marginalia.el" "orderless.el" "embark.el"
                   "embark-consult.el" "consult.el" "tap.el"
                   "vertico.el" "corfu.el" "prescient.el" "mono-complete.el"
                   "consult-gh.el" "consult-lsp.el" "consult-dash.el" "consult-ls-git.el"))
    (ui . ("display.el" "hud.el" "highlight-indent-guides.el" "ultra-scroll.el"
           "color-identifiers-mode.el" "volatile-highlights.el"
           "display-fill-column-indicator.el" "display-line-numbers.el"
           "face.el" "dimmer.el" "focus.el" "face-remap.el"
           "default-text-scale.el" "hl-line.el"
           "all-the-icons.el" "minimalize.el" "treemacs.el"
           "all-the-icons-dired.el" "all-the-icons-ibuffer.el" "theme.el"
           "modern-fringes.el" "rainbow-mode.el" "image-mode.el" "browse-url.el"
           "mermaid-mode.el" "minimap.el" "unicode-fonts.el" "spinner.el"
           "yascroll.el" "nyan-mode.el" "popper.el" "window.el"
           "rainbow-delimiters.el" "symbol-overlay.el" "hi-lock.el"
           "beacon.el" "outline-indent.el" "hl-todo.el" "svg-line.el" "header-line-svg.el"
           "svg-margin.el"
           "breadcrumb.el" "parrot.el" "hl-block.el" "awesome-tray.el"
           "telephone-line.el" "ef-themes.el" "doric-themes.el"
           "adaptive-wrap.el" "svg-lib.el" "explain-pause-mode.el" "spacetree.el"))
    (editor . ("super-save.el" "editing.el" "smartparens.el"
               "hungry-delete.el" "vimish-fold.el" "narrow.el" "ov.el" "iedit.el"
               "dumb-jump.el" "snippets.el" "ace-mc.el" "move-text.el"
               "undo-tree.el" "macrostep.el" "highlight.el" "ace-window.el"
               "windmove.el" "avy.el" "evil.el" "evil-anzu.el" "evil-surround.el"
               "evil-collection.el" "evil-exchange.el" "evil-indent-plus.el"
               "evil-search-highlight-persist.el" "evil-fringe-mark.el"
               "text-manipulation.el" "markdown-toc.el"))
    (lang . ("treesit.el" "csv-mode.el" "python.el" "web-mode.el" "js2-mode.el"
             "rjsx-mode.el" "emmet-mode.el" "sh-script.el" "yaml-mode.el"
             "yaml-path.el" "yaml.el" "yaml-pro.el" "text-mode.el" "jmespath.el"
             "terraform.el" "json-mode.el" "jsonian.el" "typescript-ts-mode.el"
             "typescript-mode.el" "biome.el" "graphviz-dot-mode.el" "svelte.el"
             "sql.el" "sqlite.el" "ein.el"))
    (tools . ("grep.el" "replace.el" "ag.el" "wgrep.el" "vc.el" "transient.el"
              "magit.el" "forge.el" "git-gutter.el" "docker.el" "dockerfile-mode.el"
              "docker-compose-mode.el" "convention.el" "tree-mode.el" "dap-mode.el"
              "dired.el" "dired-subtree.el" "dired-ranger.el" "tokei.el" "lsp.el"
              "lark.el" "apheleia.el" "flycheck.el" "flycheck-indicator.el"
              "python-pytest.el" "multi-compile.el" "multi-compile-executors.el"
              "multi-compile-targets.el" "compile.el"
              "fancy-compilation.el" "detached.el" "git-link.el"
              "browse-at-remote.el" "git-timemachine.el" "blamer.el" "devdocs.el"
              "color-rg.el" "osx-lib.el" "spotlight.el" "gha.el" "jira.el"
              "pr-review.el" "embark-vc.el" "treesit-fold.el" "kubernetes-el.el"
              "kubel.el" "magneto.el" "know-your-http-well.el" "ai.el" "alert.el"
              "ddp.el" "gnus.el"))
    (app . ("pocket-reader.el" "unidecode.el" "define-word.el" "mw-thesaurus.el"
            "sx.el" "pubmed.el" "helm-wikipedia.el" "bookmark-view.el"
            "bookmark.el" "bookmark+.el" "bookmark-in-project.el" "dogears.el"
            "olivetti.el" "activities.el" "spot4e.el" "elfeed.el" "wombag.el"
            "whisper.el" "say.el" "md4rd.el" "wttrin.el" "nov.el" "eca-emacs.el"
            "mastodon.el" "erc.el" "eww.el" "flappy-fish.el" "speed-type.el"
            "spray.el" "touchtype.el" "key-quiz.el"))
    (org . ("org.el" "org-ql.el" "org-capture.el" "org-ref.el" "ob-mermaid.el"
            "pdf-tools.el" "biblio.el" "citar.el" "org-remark.el"
            "org-tree-slide.el" "org-transclusion.el"))
    (term . ("shell.el" "foreman.el" "foreman-conf.el" "vterm.el")))
  "Default load order for files within each module category.
Derived from the curated order in init-data.el.  Files on disk
but not listed here are appended alphabetically at the end.")

(defun zetta--module-files (category)
  "Return list of .el filenames in module CATEGORY directory.
Files are returned in the default load order defined in
`zetta--default-file-order', with any unlisted files appended
alphabetically."
  (let* ((dir (expand-file-name (symbol-name category) zetta-modules-dir))
         (default-order (alist-get category zetta--default-file-order))
         (disk-files (when (file-directory-p dir)
                       (cl-remove-if (lambda (f) (string-prefix-p "." f))
                                     (directory-files dir nil "\\.el\\'")))))
    (when disk-files
      (let* ((ordered (cl-remove-if-not (lambda (f) (member f disk-files))
                                        default-order))
             (remaining (cl-remove-if (lambda (f) (member f ordered))
                                      disk-files))
             (remaining-sorted (sort remaining #'string<)))
        (append ordered remaining-sorted)))))

(defun zetta--resolve-module-spec (category spec)
  "Resolve SPEC for CATEGORY into a list of \"category/file.el\" paths.

SPEC can be:
- t — load all .el files in the category directory (in default order)
- A list of symbols — load only those (e.g., (python yaml))
- A list with -prefixed symbols — load all except those (e.g., (-nyan-mode))"
  (let* ((all-files (zetta--module-files category))
         (cat-name (symbol-name category)))
    (cond
     ;; Load all files in default order
     ((eq spec t)
      (mapcar (lambda (f) (concat cat-name "/" f)) all-files))

     ;; Exclusion list (any element starts with -)
     ((and (listp spec)
           (cl-some (lambda (s) (string-prefix-p "-" (symbol-name s))) spec))
      (let ((excludes (mapcar (lambda (s)
                                (concat (substring (symbol-name s) 1) ".el"))
                              (cl-remove-if-not
                               (lambda (s) (string-prefix-p "-" (symbol-name s)))
                               spec))))
        (mapcar (lambda (f) (concat cat-name "/" f))
                (cl-remove-if (lambda (f) (member f excludes)) all-files))))

     ;; Inclusion list (load in specified order)
     ((listp spec)
      (mapcar (lambda (s) (format "%s/%s.el" cat-name (symbol-name s))) spec))

     (t (error "Invalid module spec for %s: %S" category spec)))))

(defun zetta--parse-module-specs (specs)
  "Parse SPECS into an alist of (CATEGORY . SPEC).
SPECS is a plist-like structure: :keyword [optional-list] :keyword ..."
  (let (result current-key)
    (dolist (item specs)
      (cond
       ((keywordp item)
        ;; Previous keyword with no list means \"load all\"
        (when current-key
          (push (cons (intern (substring (symbol-name current-key) 1)) t)
                result))
        (setq current-key item))
       ((listp item)
        ;; This list belongs to the current keyword
        (when current-key
          (push (cons (intern (substring (symbol-name current-key) 1)) item)
                result)
          (setq current-key nil)))
       (t (error "Unexpected element in zetta-modules! spec: %S" item))))
    ;; Handle trailing keyword with no list
    (when current-key
      (push (cons (intern (substring (symbol-name current-key) 1)) t)
            result))
    (nreverse result)))

(defun zetta--resolve-all-modules (module-alist)
  "Resolve MODULE-ALIST into a flat list of file paths to load.
Respects `zetta-module-load-order' for ordering."
  (let (result)
    ;; Load categories in defined order first
    (dolist (category zetta-module-load-order)
      (let ((spec (alist-get category module-alist)))
        (when spec
          (setq result (append result
                               (zetta--resolve-module-spec category spec))))))
    ;; Then load any categories not in the standard load order
    (dolist (entry module-alist)
      (unless (memq (car entry) zetta-module-load-order)
        (setq result (append result
                             (zetta--resolve-module-spec (car entry) (cdr entry))))))
    result))

(defmacro zetta-modules! (&rest specs)
  "Declare which modules to load.

Each argument is either:
- A keyword `:category` — loads all files in that module category
- A keyword `:category` followed by a list — loads only/except those files

Examples:

  ;; Load everything in all categories:
  (zetta-modules!
   :core
   :completion
   :ui
   :editor
   :lang
   :tools
   :app
   :org
   :term)

  ;; Selective loading:
  (zetta-modules!
   :core                          ; all core files
   :completion                    ; all completion files
   :ui (-nyan-mode -treemacs)     ; all ui except nyan-mode and treemacs
   :editor
   :lang (python yaml terraform)  ; only these language configs
   :tools (magit lsp docker)      ; only these tools
   :app (elfeed)                  ; only elfeed
   :org
   :term)"
  `(progn
     (setq zetta-modules (zetta--parse-module-specs ',specs))
     (setq user-files (zetta--resolve-all-modules zetta-modules))))

;;; Init-critical utility functions

(defun zetta-load-config-file (file)
  "Load a module FILE relative to `zetta-modules-dir'."
  (interactive)
  (message file)
  (let* ((emacsdir (expand-file-name user-emacs-directory))
         (sourcefile-path (format "%smodules/%s" emacsdir file))
         (file-extension (file-name-extension file))
         (root (file-name-sans-extension file)))
    (cond
     ((string= "el" file-extension)
      (load-file sourcefile-path))
     ((string= "org" file-extension)
      (let* ((tanglefile-path (format "%smodules/tangled/%s.el" emacsdir root)))
        (org-babel-tangle-file sourcefile-path tanglefile-path)
        (load-file tanglefile-path))))))

(defun zetta-touch-maybe (path)
  "Create file or directory at PATH if it doesn't already exist.
If PATH has an extension, creates a file; otherwise creates a directory."
  (if (file-exists-p path)
      (message "{%s} already exists" path)
    (if (string-match-p
         (regexp-quote ".")
         (file-name-nondirectory path))
        (progn
          (make-directory (file-name-directory path) t)
          (with-temp-file path (insert ""))
          (message "Created file: %s" path))
      (progn
        (make-directory path t)
        (message "Created directory: %s" path)))))

(provide 'bootstrap-modules)
;;; bootstrap-modules.el ends here
