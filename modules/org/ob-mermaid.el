;;; ob-mermaid.el --- Configure ob-mermaid -*- lexical-binding: t; -*-

(use-package ob-mermaid :config
  (setq ob-mermaid-cli-path (executable-find "mmdc"))
  )
;;; ob-mermaid.el ends here
