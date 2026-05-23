;;; avy.el --- Configure avy -*- lexical-binding: t; -*-

(use-package avy
  :ensure t
  :commands (avy-goto-char-timer evil-avy-goto-char-timer)
  :config
  (setq avy-ignored-modes
        '(image-mode doc-view-mode pdf-view-mode))

  (general-define-key :keymaps 'override
                      "C-s-o" 'evil-avy-goto-char-timer)

  ;; "Avy can do anything" -- press `.' during any avy session to run
  ;; `embark-act' on the landed target.  After embark exits, returns
  ;; to the originating window via `avy-ring' so the prompt feels
  ;; like a handoff rather than a navigation.
  ;; https://karthinks.com/software/avy-can-do-anything/
  (defun avy-action-embark (pt)
    "Dispatch `embark-act' on PT after avy lands."
    (unwind-protect
        (save-excursion
          (goto-char pt)
          (embark-act))
      (select-window
       (cdr (ring-ref avy-ring 0))))
    t)

  (with-eval-after-load 'embark
    (setf (alist-get ?. avy-dispatch-alist) #'avy-action-embark))

  :hook (use-package--avy--post-config . brushup))
;;; avy.el ends here
