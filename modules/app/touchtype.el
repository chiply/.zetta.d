;;; touchtype.el --- Configure touchtype -*- lexical-binding: t; -*-

(use-package touchtype
  ;; :ensure (:host github :repo "chiply/touchtype")
  :ensure (:repo "~/source_code/touchtype")
  :commands (touchtype
             touchtype-progressive
             touchtype-full-words
             touchtype-bigram-drill
             touchtype-letters
             touchtype-letters+numbers
             touchtype-letters+numbers+symbols
             touchtype-stats-view))
;;; touchtype.el ends here
