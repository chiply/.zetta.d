;;; embark-consult.el --- Configure embark-consult -*- lexical-binding: t; -*-

(use-package embark-consult
  :after (embark consult)
  :config
  ;; required to get sorting to work: from llm

  ;;Yes, this is expected. The sorting issue is likely because
  ;;embark-consult-project-find-in-dir wraps the call in a let
  ;;binding, and vertico's history-based sorting may not carry over
  ;;correctly in that context — even though you set this-command, the
  ;;minibuffer history association can behave differently when the
  ;;call is wrapped.  You can't just bind consult-project-extra-find
  ;;directly in the embark keymap though, because embark passes the
  ;;target directory as an argument and consult-project-extra-find
  ;;doesn't accept one — it uses project-current from
  ;;default-directory. So you need the wrapper.  Moving this-command
  ;;out of the let and using setq instead means it's the actual value
  ;;of this-command when the minibuffer is entered, not just a lexical
  ;;binding. Consult and vertico both check this-command at minibuffer
  ;;entry time to determine sorting/history behavior, and a let-bound
  ;;value can get shadowed during the interactive call.

  (defun embark-consult-project-find-in-dir (dir)
    (let ((default-directory dir))
      (setq this-command 'consult-project-extra-find)
      (call-interactively 'consult-project-extra-find)))
  )
;;; embark-consult.el ends here
