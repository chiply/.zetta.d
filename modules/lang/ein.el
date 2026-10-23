;;; ein.el --- Configure ein -*- lexical-binding: t; -*-

;; Deferred to its entry points (OPTIMIZATIONS.org "145 eager use-package
;; blocks"); the .ipynb auto-mode entry comes from the autoloads either way.
(use-package ein
  :commands (ein:jupyter-server-start ein:jupyter-server-stop
             ein:notebook-open ein:notebooklist-open ein:notebooklist-login))
;;; ein.el ends here
