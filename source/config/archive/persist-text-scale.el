(use-package persist-text-scale
  :ensure (persist-text-scale
           :type git
           :host github
           :repo "jamescherti/persist-text-scale.el")
  :custom
  (persist-text-scale-autosave-interval (* 1 60))
  :config
  ;; TODO move text-scale configurations into this package?
  (persist-text-scale-mode 1)
  (defun my-persist-text-scale-function ()
    (let ((buffer-name (buffer-name)))
      (cond
       ;; Add things that should remain the same -- minibuffer,
       ;; treemacs, transient, which-key, etc... do this as needed
       ((string-prefix-p " *Minibuf" buffer-name) :ignore)
       ((string-prefix-p " *which-key" buffer-name) :ignore)
       ((string-prefix-p " *transient*" buffer-name) :ignore)
       ((equal major-mode 'vterm-mode) :ignore)
       )))

  (setq persist-text-scale-buffer-category-function 'my-persist-text-scale-function)
  ;; NOTE doesn't work
  (setq persist-text-scale-default-text-scale-amount 1.0)
  )
