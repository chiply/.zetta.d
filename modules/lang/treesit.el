;;; treesit.el --- Configure treesit -*- lexical-binding: t; -*-

;; `M-x combobulate' (default: `C-c o o') to start using Combobulate
(use-package treesit
  :ensure nil ;; its builtin to emacs
  :preface
  (setq treesit-language-source-alist
        '((python "https://github.com/tree-sitter/tree-sitter-python")
          ;;(css "https://github.com/tree-sitter/tree-sitter-css")
          ;;(javascript . ("https://github.com/tree-sitter/tree-sitter-javascript" "master" "src"))
          (tsx . ("https://github.com/tree-sitter/tree-sitter-typescript" "master" "tsx/src"))
          (typescript . ("https://github.com/tree-sitter/tree-sitter-typescript" "master" "typescript/src"))
          ;;(yaml "https://github.com/ikatyang/tree-sitter-yaml")
          ))

  ;; Emacs 31: auto-install grammars when needed (no manual install step)
  (setq treesit-auto-install-grammar t)

  ;; Emacs 31: centralized control over which ts-modes auto-activate.
  ;; `t' means all available ts-modes activate; use a list to restrict.
  (setq treesit-enabled-modes t)

  :config
  ;; Do not forget to customize Combobulate to your liking:
  ;;
  ;;  M-x customize-group RET combobulate RET
  ;;
  (use-package combobulate
    :ensure (combobulate :host github :repo "mickeynp/combobulate")
    :preface
    ;; You can customize Combobulate's key prefix here.
    ;; Note that you may have to restart Emacs for this to take effect!
    (setq combobulate-key-prefix "C-c o")

    ;; Optional, but recommended.
    ;;
    ;; You can manually enable Combobulate with `M-x
    ;; combobulate-mode'.
    :hook (
           (python-ts-mode . combobulate-mode)
           ;;(js-ts-mode . combobulate-mode)
           ;;(css-ts-mode . combobulate-mode)
           ;;(yaml-ts-mode . combobulate-mode)
           ;;(json-ts-mode . combobulate-mode)
           ;;(typescript-ts-mode . combobulate-mode)
           ;;(tsx-ts-mode . combobulate-mode)
           )
    ;; Amend this to the directory where you keep Combobulate's source
    ;; code.
    ))

;; The per-language `treesit-thing-settings' extras table + the hook
;; that applies it now live in the `treesit-tap' package (under
;; `source/zettapkg/treesit-tap/').  Loaded via
;; `modules/completion/treesit-tap.el' before this file.

;;; treesit.el ends here
