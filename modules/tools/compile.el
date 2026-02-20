(use-package compile
  :ensure nil ;; builtin
  :config
  ;; TODO why does it still scroll the output?
  (setq compilation-scroll-output nil)
  (setq compilation-auto-jump-to-first-error t)
  (advice-add 'compile :after
            (lambda (&rest args)
              (append-to-zsh-history (car args))))
  :general (:keymaps '(override) "s-r" 'recompile)
  )


