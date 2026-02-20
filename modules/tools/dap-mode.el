(use-package dap-mode
  :commands (dap-debug dap-hydra dap-mode dap-ui-mode)

  :config
  (setq dap-ui-variable-length 1000)

  ;; lang specific
  (require 'dap-python)

  (setq dap-python-debugger 'debugpy)
  (setq dap-auto-configure-features '())

  ;;(dap-tooltip-mode nil)
  ;;(tooltip-mode nil)

  ;; note this depends on python -- with-venv is str8 up broke
  (defun dap-python--pyenv-executable-find (command)
    (expand-file-name (concat pyvenv-activate "/bin/python")))

  (defun dap-pytest-at-point-program ()
    (let* ((function-name
            (nth 0 (last (split-string
                          (nth 0 (split-string (thing-at-point 'defun) "("))))))
           (current-file-path (buffer-file-name))
           (pytest-arg (concat current-file-path "::" function-name)))
      pytest-arg))

  (defun read-env-file (file)
    (with-temp-buffer
      (insert-file-contents file)
      (let ((env-vars (split-string (buffer-string) "\n" t)))
        ;;(mapcar (lambda (env-var)
        ;;(split-string env-var "=" t))
        ;;env-vars)
        (mapcar (lambda (env-var)
                  (cons (car (split-string env-var "=" t))
                        (cadr (split-string env-var "=" t))))
                env-vars)
        )))


  
  ;; TEMPLATES
  (defun dap-debug-python-pytest-at-point ()
    (interactive)
    (let ((program (dap-pytest-at-point-program))
          (env-vars (read-env-file
                     (expand-file-name
                      (concat (project-root (project-current nil default-directory)) ".env")))))
      (dap-debug
       (list :type "python"
             :cwd (project-root (project-current nil default-directory))
             :args "-vvv"
             :program program
             :module "pytest"
             :request "launch"
             :name "Python :: Run pytest (at point)"
             :env env-vars
             ))))

  :hook ((python-ts-mode . dap-ui-mode)
         (python-ts-mode . dap-mode))

  :general
  (
   :keymaps 'override
   "s-D" 'dap-hydra
   "C-S-s-d" 'dap-debug
   )
  )













