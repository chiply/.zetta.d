;;; citar.el --- Configure citar -*- lexical-binding: t; -*-

(use-package citar
  :ensure (:files (:defaults))
  :after all-the-icons
  :config
  (setq citar-symbols
        `((file ,(all-the-icons-faicon "file-o"
                                       :face 'all-the-icons-red
                                       :v-adjust -0.1) . " ")
          (note ,(all-the-icons-material "speaker_notes"
                                         :face 'all-the-icons-red
                                         :v-adjust -0.3) . " ")
          (link ,(all-the-icons-octicon "link"
                                        :face'all-the-icons-red
                                        :v-adjust 0.01) . " ")))
  (setq citar-symbol-separator "  ")

  ;; NOT RECURSIVE!!! Need to specify explicitly
  (setq
   citar-library-paths (list (expand-file-name "pdf" zetta-literature-dir))
   )

  :custom
  (citar-bibliography (list (expand-file-name "bibliography.bib" zetta-literature-dir)))
  )

(use-package citar-embark
  :ensure nil
  :after citar embark
  :no-require
  :config (citar-embark-mode))
;;; citar.el ends here
