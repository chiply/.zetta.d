;;; package-tutor.el --- package-tutor wrapper -*- lexical-binding: t; -*-

;; `package-tutor' lives in its own repo (chiply/package-tutor) and
;; relies only on Emacs built-ins.  `M-x package-tutor' prompts for a
;; package/feature and opens an org-mode tutorial buffer for it; `T' in
;; the package menu or a help buffer opens the relevant tutorial.

(use-package package-tutor
  :ensure (:host github :repo "chiply/package-tutor")
  :commands (package-tutor package-tutor-for-symbol-at-point))

;;; package-tutor.el ends here
