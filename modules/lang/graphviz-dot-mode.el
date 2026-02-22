;;; graphviz-dot-mode.el --- Configure graphviz-dot-mode -*- lexical-binding: t; -*-

(use-package graphviz-dot-mode
  :config
  (defun extract-requires (file)
    "Extract require statements from elisp FILE."
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (let (requires)
        (while (re-search-forward "(require '\\([^)]+\\))" nil t)
          (push (match-string 1) requires))
        requires))

    (defun build-dependency-graph (files)
      "Build DOT graph from elisp FILES."
      (with-temp-buffer
        (insert "digraph G {\n")
        (dolist (file files)
          (let* ((filename (file-name-base file))
                 (requires (extract-requires file)))
            (dolist (req requires)
              (insert (format "  \"%s\" -> \"%s\";\n" filename req)))))
        (insert "}\n")
        (write-file "deps.dot")
        (shell-command "dot -Tpng deps.dot -o deps.png")))

    ;; Usage example:
    ;; (build-dependency-graph
    ;; (directory-files "~/.emacs.d/lisp" t "\\.el$"))
    )
  )
;;; graphviz-dot-mode.el ends here
