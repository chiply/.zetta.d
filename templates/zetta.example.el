;; -*- lexical-binding: t; -*-
;;
;; ~/.zetta.el — User configuration for Zetta Emacs
;;
;; Copy this file to ~/.zetta.el and customize it.
;; This file is loaded after the bootstrap but before module configs,
;; so variables set here are available to all modules.
;;
;; The only required section is `zetta-modules!' — everything else is optional.

;;; ————————————————————————————————————————————————
;;; Appearance
;;; ————————————————————————————————————————————————

;; Font family (must be installed on your system)
;; Terminus TTF: https://files.ax86.net/terminus-ttf/
;; Other good options: "JetBrains Mono", "Fira Code", "Iosevka", "Source Code Pro"
;; (setq zetta-font "Terminus (TTF)")

;; Color theme loaded at startup
;; Bundled themes: modus-operandi, modus-vivendi, nord, ef-themes variants,
;;   poet, heroku, jbeans, leuven, rebecca, zenburn, lavender, chocolate
;; (setq zetta-theme 'modus-operandi)

;;; ————————————————————————————————————————————————
;;; Editing
;;; ————————————————————————————————————————————————

;; Leader key for non-insert modal states (default: ",")
;; (setq launch-key ",")

;; Modal editing system: switch at runtime with s-z m (meow), s-z e (evil), s-z E (emacs)
;; Evil is enabled by default via the bootstrap.

;;; ————————————————————————————————————————————————
;;; Paths
;;; ————————————————————————————————————————————————

;; Bibliography and PDF storage for org-ref, citar, biblio
;; (setq zetta-literature-dir "~/.lit/")

;; Logseq pages directory for org-capture integration
;; (setq zetta-logseq-dir "~/logseq/pages/")

;;; ————————————————————————————————————————————————
;;; Package management
;;; ————————————————————————————————————————————————

;; Pin packages to lockfile versions for reproducibility (default: t)
;; Set to nil to use latest package versions from MELPA/GitHub
;; (setq zetta-use-lockfile nil)

;;; ————————————————————————————————————————————————
;;; Modules
;;; ————————————————————————————————————————————————

;; Declare which modules to load.
;;
;; :keyword           — load all files in that module category
;; :keyword (a b c)   — load only the listed files
;; :keyword (-a -b)   — load all except the listed files
;;
;; Omit a category entirely to skip it.

(zetta-modules!
 :core                          ; essential Emacs settings
 :completion                    ; vertico, consult, orderless, corfu, embark
 :ui                            ; themes, modeline, icons, treemacs, window mgmt
 :editor                        ; evil, smartparens, snippets, undo-tree, avy
 :lang                          ; python, yaml, typescript, terraform, sql, etc.
 :tools                         ; magit, lsp, docker, flycheck, dired, compile
 :app                           ; elfeed, bookmarks, spotify, mastodon, eww
 :org                           ; org-mode, org-ref, citar, pdf-tools
 :term                          ; vterm, shell, foreman
 )

;; Examples of selective loading:
;;
;; Load only specific languages:
;;   :lang (python yaml terraform typescript-ts-mode)
;;
;; Load all UI except some packages:
;;   :ui (-nyan-mode -parrot -minimap)
;;
;; Skip app and term modules entirely:
;;   ;; just don't include :app or :term above

;;; ————————————————————————————————————————————————
;;; User packages
;;; ————————————————————————————————————————————————

;; Add your own use-package declarations here.
;; They will be loaded after the distro modules.
;;
;; (use-package my-package
;;   :ensure t
;;   :config
;;   ...)

;;; ————————————————————————————————————————————————
;;; Keybinding overrides
;;; ————————————————————————————————————————————————

;; Override or extend keybindings via general.el.
;; Available prefix maps: launch-map, menu-window-map, menu-project-map,
;;   menu-vc-map, menu-lookup-map, menu-org-map, menu-run-map,
;;   menu-theme-map, menu-help-map, menu-smerge-map, menu-iedit-map
;;
;; (general-define-key
;;  :keymaps 'launch-map
;;  "x" 'my-custom-command)
