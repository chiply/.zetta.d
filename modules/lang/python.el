;;; python.el --- Configure pyvenv -*- lexical-binding: t; -*-

;; write a function that finds the first parent directory with a pyproject.toml
;; the function should return nil if no such directory is found
(defun zetta-find-poetry-project-root ()
  (interactive)
  (let ((dir (file-name-directory (buffer-file-name))))
    (while (and
            dir
            (not (file-exists-p (concat dir "pyproject.toml")))
            (not (string= dir "/")))
      (setq dir (file-name-directory (directory-file-name dir))))
    (if (string= dir "/") nil dir)))

(use-package pyvenv
  :commands (pyvenv-mode pyvenv-activate pyvenv-deactivate)
  :hook (python-ts-mode . pyvenv-mode)
  :config
  ;;(setq pyvenv-post-activate-hooks '())
  (defun zetta-pyvenv-activate-poetry ()
    (interactive)
    (when (and (eq major-mode 'python-ts-mode)
               (zetta-find-poetry-project-root))
      (if (and (boundp 'zetta-pyvenv-virtual-env) zetta-pyvenv-virtual-env)
          (pyvenv-activate zetta-pyvenv-virtual-env)
        (let* ((_ (pyvenv-deactivate))
               (cmd "poetry env info --path")
               (output (shell-command-to-string cmd))
               (venv (replace-regexp-in-string "\n" "" output)))
          (pyvenv-activate venv)
          (setq-local zetta-pyvenv-virtual-env venv)))
      (unless lsp-mode (lsp-deferred))))
  ;; Use python-ts-mode-hook instead of buffer-list-update-hook for performance
  (add-hook 'python-ts-mode-hook 'zetta-pyvenv-activate-poetry))

(use-package poetry)

(use-package python
  :ensure nil
  :mode ("\\.py\\'" . python-ts-mode)
  :init
  (setq python-shell-interpreter "python3")
  (setq python-indent-guess-indent-offset t)
  (setq python-indent-guess-indent-offset-verbose 4)

  :config
  ;; Debugging - defer to when dap-mode is actually loaded
  (with-eval-after-load 'dap-mode
    (require 'dap-python)
    (setq dap-python-executable "python3")
    (setq dap-python-debugger 'debugpy)
    (defun dap-python--pyenv-executable-find (command)
      (concat pyvenv-virtual-env "bin/python3")))

  :general
  (
   :keymaps 'python-ts-mode-map
   "C-c =" '(lambda () (interactive)
              (save-excursion
                (evil-indent (point-min) (point-max))))
   )

  :hook (
         (python-ts-mode . flycheck-mode)
         (python-ts-mode . dap-ui-mode)
         (python-ts-mode . dap-mode)
         (dap-stopped . (lambda (arg) (call-interactively #'dap-hydra)))
         )
  )

;; autoformatting
(use-package blacken)

;; not the greatest, but it's one of the better solutions that
;; actually supports type hinting
(use-package numpydoc
  :config
  (setq numpydoc-insertion-style nil)
  :bind (:map python-ts-mode-map
              ("C-c C-n" . numpydoc-generate)))
;;; python.el ends here
