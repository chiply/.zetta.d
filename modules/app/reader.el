;;; reader.el --- Configure emacs-reader -*- lexical-binding: t; -*-

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
                                (display-line-numbers-mode -1))))

;;; reader.el ends here
