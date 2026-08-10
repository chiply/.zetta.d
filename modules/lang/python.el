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
  ;; Prefers ROOT/.venv directly (uv and in-project poetry layouts) so
  ;; no subprocess is needed; falls back to asking poetry from the
  ;; project root.  Never deactivates first, and validates the result
  ;; before activating: a failed lookup must not poison the active
  ;; venv (poetry's error text once got activated as a literal path
  ;; here, knocking pylsp off exec-path for every later buffer).
  (defun zetta-pyvenv-activate-project ()
    (interactive)
    (when (eq major-mode 'python-ts-mode)
      (when-let* ((root (zetta-find-poetry-project-root))
                  (venv (or (let ((dot-venv (expand-file-name ".venv" root)))
                              (and (file-directory-p dot-venv) dot-venv))
                            (let* ((default-directory root)
                                   (out (string-trim
                                         (shell-command-to-string
                                          "poetry env info --path"))))
                              (and (file-directory-p out) out)))))
        (unless (and (bound-and-true-p pyvenv-virtual-env)
                     (string= (file-name-as-directory (expand-file-name venv))
                              (file-name-as-directory
                               (expand-file-name pyvenv-virtual-env))))
          (pyvenv-activate venv))
        (unless lsp-mode (lsp-deferred)))))
  ;; Use python-ts-mode-hook instead of buffer-list-update-hook for performance
  (add-hook 'python-ts-mode-hook 'zetta-pyvenv-activate-project))

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
    (setq dap-python-debugger 'debugpy))
  ;; NOTE the venv interpreter resolver
  ;; (dap-python--pyenv-executable-find) lives in tools/dap-mode.el —
  ;; a duplicate here once shadowed it and the two drifted

  :general
  (
   :keymaps 'python-ts-mode-map
   "C-c =" '(lambda () (interactive)
              (save-excursion
                (if (fboundp 'evil-indent)
                    (evil-indent (point-min) (point-max))
                  (indent-region (point-min) (point-max)))))
   )

  :hook (
         (python-ts-mode . (lambda () (when (fboundp 'flycheck-mode) (flycheck-mode 1))))
         (python-ts-mode . (lambda () (when (fboundp 'dap-ui-mode) (dap-ui-mode 1))))
         (python-ts-mode . (lambda () (when (fboundp 'dap-mode) (dap-mode 1))))
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
