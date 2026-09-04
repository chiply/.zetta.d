;;; hl-todo.el --- Configure hl-todo -*- lexical-binding: t; -*-

(use-package hl-todo
  :config
  ;; Keyword colours come from the theme rather than being fixed web
  ;; primaries.  The old list was #FF0000 / #0000FA / A020F0 etc -- saturated
  ;; sRGB corners that clash with any designed palette, and #0000FA is very
  ;; nearly unreadable on a dark background.
  ;;
  ;; Grouped by what the keyword MEANS, so the palette stays coherent:
  ;;   needs action  -> error      TODO FIXME GOTCHA
  ;;   in progress   -> warning    STUB LEFTOFF PROMPT
  ;;   informational -> accent     NOTE EXPLANATION DEBUG
  ;;   finished      -> success    DONE
  (defun zetta-hl-todo-refresh ()
    "Recompute `hl-todo-keyword-faces' from the current theme."
    (let ((c (lambda (k) (if (fboundp 'zetta-theme-color)
                             (zetta-theme-color k)
                           (face-foreground 'default nil t)))))
      (setq hl-todo-keyword-faces
            (list (cons "TODO"        (funcall c 'error))
                  (cons "FIXME"       (funcall c 'error))
                  (cons "GOTCHA"      (funcall c 'error))
                  (cons "STUB"        (funcall c 'warning))
                  (cons "LEFTOFF"     (funcall c 'warning))
                  (cons "PROMPT"      (funcall c 'warning))
                  (cons "NOTE"        (funcall c 'accent))
                  (cons "EXPLANATION" (funcall c 'accent))
                  (cons "DEBUG"       (funcall c 'accent))
                  (cons "DONE"        (funcall c 'success))))))
  (zetta-hl-todo-refresh)

  :brushup
  (add-to-list 'brushup-styles '(zetta-hl-todo-refresh) t)

  :hook ((prog-mode markdown-mode org-mode yaml-mode) . hl-todo-mode))
;;; hl-todo.el ends here
