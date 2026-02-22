;;; flycheck.el --- Configure flycheck -*- lexical-binding: t; -*-

(use-package flycheck-aspell
  :if (executable-find "aspell")
  :config
  ;;(setq ispell-dictionary "your_default_dictionary")
  (setq ispell-program-name "aspell")
  (setq ispell-silently-savep t)

  (add-to-list 'flycheck-checkers 'markdown-aspell-dynamic)

  (flycheck-aspell-define-checker "org"
    "Org" ("--add-filter" "url")
    (org-mode))

  (add-to-list 'flycheck-checkers 'org-aspell-dynamic)
  )

(use-package flycheck
  :config
  (setq flycheck-checker-error-threshold 5000)
  (flycheck-define-checker proselint
    "A linter for prose."
    :command ("proselint" source-inplace)
    :error-patterns
    ((warning line-start (file-name) ":" line ":" column ": "
              (id (one-or-more (not (any " "))))
              (message) line-end))
    :modes (text-mode markdown-mode gfm-mode org-mode))

  ;; NOTE: 10 seems to be the minimum width before the filter symbol
  ;; causes issues with overlap
  (setq flycheck-error-list-format
        [("File" 20)
         ("Line" 10 flycheck-error-list-entry-<)
         ("Col" 10 nil)
         ("Level" 15 flycheck-error-list-entry-level-<)
         ("ID" 26 t)
         (#("Message (Checker)" 0 7
            (face flycheck-error-list-error-message)
            9 16
            (face flycheck-error-list-checker-name))
          0 t)])

  ;; this is necessary!  eg run proselint after org-aspell-dynamic
  ;; from here https://github.com/flycheck/flycheck/issues/186
  (when (bound-and-true-p flycheck-aspell)
    (flycheck-add-next-checker 'org-aspell-dynamic 'proselint))

  ;;(use-package flycheck-overlay
    ;;:ensure (flycheck-overlay :type git :host github :repo "konrad1977/flycheck-overlay")
    ;;:config
    ;;(custom-set-faces
     ;;'(flycheck-overlay-error
       ;;((t :background "#ea8faa"
           ;;:foreground "#453246"
           ;;:height 0.8
           ;;:weight normal)))
    ;;
     ;;'(flycheck-overlay-warning
       ;;((t :background "#DCA561"
           ;;:foreground "#331100"
           ;;:height 0.8
           ;;:weight normal)))
    ;;
     ;;'(flycheck-overlay-info
       ;;((t :background "#a8e3a9"
           ;;:foreground "#374243"
           ;;:height 0.8
           ;;:weight normal))))
    ;;;;(defcustom flycheck-overlay-info-icon " " "Icon used for information.")
    ;;;;(defcustom flycheck-overlay-warning-icon " " "Icon used for warnings.")
    ;;;;(defcustom flycheck-overlay-error-icon " " "Icon used for errors.")
    ;;)

  ;;:brushup
  ;;(add-to-list 'brushup-styles
  ;;'(progn
  ;;(set-face-attribute 'flycheck-fringe-error nil
  ;;:foreground brushup-fg
  ;;:background (modus-themes-get-color-value 'bg-red-nuanced))
  ;;(set-face-attribute 'flycheck-fringe-warning nil
  ;;:foreground brushup-fg
  ;;:background (modus-themes-get-color-value 'bg-blue-nuanced))
  ;;(set-face-attribute 'flycheck-fringe-info nil
  ;;:foreground brushup-fg
  ;;:background brushup-bg-1_0)
  ;;)
  ;;)

  :display
  ;;(zetta-side "^\\*Flycheck*" 'top)

  :hook (
         (flycheck-error-list . (lambda () (text-scale-set -2)))
         ;;(flycheck-mode . flycheck-overlay-mode)
         ;; NOTE slows down org mode, so leave off my default
         ;; also adds a lot of visual cluttter
         ;;(org-mode . flycheck-mode)
         )
  )
;;; flycheck.el ends here
