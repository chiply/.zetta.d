(use-package epc)

(use-package org-supertag
  :demand t
  :after (org epc ht)
  :ensure (org-supertag :host github :repo "yibie/org-supertag"
                        :files (:defaults "simtag" ".venv")
                        :pre-build ("bash" "simtag/setup_uv.sh"))
  :config
  (let ((package-path (locate-library "org-supertag")))
    (when package-path
      (let* ((package-dir (file-name-directory package-path))
             ;; the venv should be located at the project root, not under `simtag/`
             (python-path (expand-file-name ".venv/bin/python" package-dir)))
        (when (file-exists-p python-path)
          (setq org-supertag-bridge-python-command python-path))))))

