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
         . evil-ts-obj-mode)
  :init
  ;; Aerospace owns the entire `alt-*' keyspace on this machine
  ;; (alt-hjkl focus, alt-shift-hjkl move, alt-r flatten, alt-e
  ;; balance, alt-t layout, etc.), so every M-* key evil-ts-obj
  ;; would bind in `generic-navigation' or as a top-level edit
  ;; operator gets eaten by the WM before Emacs sees it.
  ;;
  ;; Drop `generic-navigation' (M-a/e/n/p/f/b + their C-M-
  ;; variants) and keep just the groups that don't fight aerospace:
  ;;
  ;; - `navigation' uses paren-prefixes (`(', `)', `[', `]', `{',
  ;;   `}') for beginning/end/next/previous -- no modifier keys.
  ;; - `text-objects' lives under the standard evil inner/outer
  ;;   maps (`i', `a', `u', `U', `o', `O') in visual/operator
  ;;   state -- no modifier keys.
  ;; - `edit-operators' keeps the `z'-prefix commands (zx swap,
  ;;   zr raise, zc clone, etc.). Its M-* bindings (M-j/M-k drag,
  ;;   M-J/M-K swap-dwim, M-r raise-dwim, M-h/M-l extract,
  ;;   M-s/M-S inject) are unbound below and we re-bind drag onto
  ;;   `C-M-j' / `C-M-k' which aerospace ignores.
  ;; - `avy' integration stays on whatever `evil-ts-obj-avy-key-
  ;;   prefix' is.
  (setq evil-ts-obj-enabled-keybindings
        '(navigation text-objects edit-operators avy))

  :config
  ;; Strip the M-* edit-operator bindings aerospace would eat,
  ;; then re-bind drag onto a chord aerospace doesn't catch.
  (with-eval-after-load 'evil-ts-obj
    (dolist (k '("M-r" "M-j" "M-k" "M-J" "M-K"
                 "M-c" "M-C" "M-h" "M-l" "M-s" "M-S"
                 "M->" "M-<"))
      (evil-define-key 'normal 'evil-ts-obj-mode (kbd k) nil))
    (evil-define-key 'normal 'evil-ts-obj-mode
      (kbd "C-M-j") #'evil-ts-obj-drag-down
      (kbd "C-M-k") #'evil-ts-obj-drag-up
      (kbd "C-M-S-j") #'evil-ts-obj-swap-dwim-down
      (kbd "C-M-S-k") #'evil-ts-obj-swap-dwim-up)))
;;; evil-ts-obj.el ends here
