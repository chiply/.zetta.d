;; (use-package eglot
;;   :straight nil

;;   :hook
;;   ((python-ts-mode) . eglot-ensure)

;;   :config
;;   (setq-default eglot-workspace-configuration
;;     (lambda (&rest args)
;;       (let ((venv-directory (string-trim (shell-command-to-string "pyenv prefix"))))
;;         ;; pylsp otpions https://gist.github.com/doolio/8c1768ebf33c483e6d26e5205896217f
;;         `((:pylsp .
;;                   (:plugins
;;                    (:jedi_completion (:include_params t
;;                                       :fuzzy t)
;;                     :jedi (:environment ,venv-directory)
;;                     ;; :flake8 (:enabled t)
;;                     :black (:enabled t)
;;                     :rope_autoimport (:enabled t
;;                                       :python_path ,venv-directory)))))))))
