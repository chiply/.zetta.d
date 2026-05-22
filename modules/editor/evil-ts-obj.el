;;; evil-ts-obj.el --- TS text objects for evil via builtin treesit -*- lexical-binding: t; -*-

;; https://github.com/dvzubarev/evil-ts-obj
;;
;; Purpose-built for Emacs's built-in tree-sitter.  Where
;; `evil-textobj-tree-sitter' translates helix / nvim queries (and
;; trips over Emacs's stricter `treesit-query-compile' parser),
;; this package leans on Emacs's own treesit thing machinery -- so
;; it composes naturally with the rest of our type-bridge stack.
;;
;; Four universal "things" instead of per-construct text objects:
;;
;;   | Thing     | Key | What it grabs                                |
;;   |-----------|-----|----------------------------------------------|
;;   | compound  | e   | function / loop / conditional / class / etc. |
;;   | statement | s   | simple statement, RHS, boolean expression    |
;;   | parameter | a   | function arg, list/tuple/mapping item        |
;;   | string    | q   | literal / raw / heredoc                      |
;;
;; Combined with evil's standard inner/outer modifiers: `vie' selects
;; inner compound (e.g. function body), `dae' deletes outer compound,
;; `cia' changes inner parameter, `yiq' yanks inner string, etc.
;;
;; Movement keys are bound by default (M-a / M-e / M-f / M-b /
;; M-n / M-p), plus structural-edit operators (drag/swap/raise/etc.)
;; -- see the upstream README for the full set.

(use-package evil-ts-obj
  :ensure (:host github :repo "dvzubarev/evil-ts-obj")
  :after evil
  :hook ((python-ts-mode bash-ts-mode sh-mode
          c-ts-mode c++-ts-mode rust-ts-mode
          nix-mode yaml-ts-mode)
         . evil-ts-obj-mode))
;;; evil-ts-obj.el ends here
