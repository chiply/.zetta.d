(use-package markdown-mode
  :hook (markdown-mode . (lambda () (progn
                                      (adaptive-wrap-prefix-mode t)
                                      (auto-fill-mode -1)
                                      (visual-line-mode t) 
                                      (progn
                                        (setq visual-fill-column-width 80)
                                        ;; interesting, but not necessary
                                        ;;(setq visual-fill-column-center-text t)
                                        (setq visual-fill-column-width 80)
                                        )
                                      ))
                       )
  )
