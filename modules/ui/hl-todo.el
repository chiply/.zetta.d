;;; hl-todo.el --- Configure hl-todo -*- lexical-binding: t; -*-

(use-package hl-todo
  :config
  ;; NOTE this should take precendence over org-mode highlighting
  ;; how do these colors change when changing themes?  is it somehow
  ;; doing math on the orginal colors?  does the theme contain todo
  ;; words?
  (setq hl-todo-keyword-faces
        '(("TODO"   . "#FF0000")
          ("FIXME"  . "#FF0000")
          ("GOTCHA" . "#FF4500")
          ("DEBUG"  . "#A020F0")
          ("STUB"   . "#1E90FF")
          ("LEFTOFF"   . "#0000FA")
          ("DONE"   . "#0000FA0F0000")
          ("NOTE"   . "#0000FA")
          ("PROMPT"   . "#9B9B3030FFFF")
          ("EXPLANATION"   . "PaleGreen4")
          ))
  :hook ((prog-mode markdown-mode org-mode yaml-mode) . hl-todo-mode))
;;; hl-todo.el ends here
