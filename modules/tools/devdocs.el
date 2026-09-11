;;; devdocs.el --- Configure devdocs -*- lexical-binding: t; -*-

(use-package devdocs
  :config
  (require 'cl-lib)
  (setq zetta-devdocs-installed-langs (mapcar
                                   (lambda (it) (alist-get 'slug it))
                                   (devdocs--installed-docs)))

  (setq
   zetta-devdocs-langs-to-install
   '("javascript" "python~3.12" "svelte" "css" "vite" "typescript" "c"
     "r" "i3" "jq" "git" "man" "npm" "zsh" "bash" "d3~7" "html" "htmx"
     "http" "node" "rust" "yarn" "elisp" "cmake" "latex" "nginx"
     "react" "redis" "docker" "duckdb" "jquery" "sqlite" "fastapi"
     "homebrew" "markdown" "pandas~2" "jinja~3.1" "terraform"
     "tensorflow" "postgresql~18"))

  (setq zetta-devdocs-uninstalled-langs
        (cl-set-difference zetta-devdocs-langs-to-install
                           zetta-devdocs-installed-langs :test 'string=))

  ;; Install the missing doc sets.  Each is a network fetch, so: never
  ;; in batch (CI and `bin/zetta build' have no use for 36 downloads,
  ;; and one flaky fetch failed the Emacs 31 CI row once the use-package
  ;; error gate was tightened), and one failure must not abort the rest
  ;; of this :config or the other sets.
  (unless noninteractive
    (dolist (lang zetta-devdocs-uninstalled-langs)
      (condition-case err
          (devdocs-install lang)
        (error (message "devdocs: could not install %s: %s"
                        lang (error-message-string err)))))))
;;; devdocs.el ends here
