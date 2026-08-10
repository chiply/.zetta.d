;;; compile.el --- Configure compile -*- lexical-binding: t; -*-

(use-package compile
  :ensure nil ;; builtin
  :config
  ;; TODO why does it still scroll the output?
  (setq compilation-scroll-output nil)
  (setq compilation-auto-jump-to-first-error t)
  ;; stop at EVERY message when navigating (TAB/S-TAB), even repeats
  ;; at the same file:line — the default collapses them, which suits
  ;; gcc-style multi-line errors but makes pytest's parametrized
  ;; failures (all on one assert line) unreachable ("Past last error")
  (setq compilation-skip-to-next-location nil)
  (advice-add 'compile :after
            (lambda (&rest args)
              (append-to-zsh-history (car args))))
  :general (:keymaps '(override) "s-r" 'recompile)
  )
;;; compile.el ends here
