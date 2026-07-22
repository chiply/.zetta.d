;;; reader.el --- Configure emacs-reader -*- lexical-binding: t; -*-

;; darwin-only by construction: the recipe ships render-core.dylib and the
;; :pre-build make needs mupdf -- neither exists on a Linux CI runner.  The
;; :mode entries register in auto-mode-alist even when the package fails to
;; build, so an unguarded declaration makes any matching file visit crash
;; with (file-missing "render-core") -- which is exactly how the 29.4 CI job
;; failed its serious-errors check (run 29946929141) after an otherwise
;; clean cold build.
(when (eq system-type 'darwin)
  (use-package reader
    :ensure (:host codeberg :repo "MonadicSheep/emacs-reader"
             :files ("*.el" "render-core.dylib")
             :pre-build ("make" "all"))
    :commands (reader-mode reader-open-doc)
    :mode (("\\.epub\\'" . reader-mode)
           ("\\.mobi\\'" . reader-mode)
           ("\\.fb2\\'"  . reader-mode)
           ("\\.xps\\'"  . reader-mode)
           ("\\.cbz\\'"  . reader-mode))
    :config
    (setq reader-default-fit 'reader-fit-to-width)
    (add-hook 'reader-mode-hook (lambda ()
                                  (display-fill-column-indicator-mode -1)
                                  (display-line-numbers-mode -1)))))

;;; reader.el ends here
