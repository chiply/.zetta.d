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

;; Extend python-ts-mode's `treesit-thing-settings' with extra things
;; that Bridge A in `tap.el' surfaces via thing-at-point / forward-thing
;; / embark. Python's stock settings define defun / sexp / list /
;; sentence / text; we add function, class, loop, conditional,
;; decorator, call, parameter, argument_list, string, and a generalised
;; `statement' (regex over node names ending in _statement or
;; _definition).
(defun zetta-python-ts-extend-things ()
  "Append zetta-tap things to `treesit-thing-settings' for python.
Idempotent: existing thing definitions are preserved untouched."
  (let ((extras
         '((function "function_definition")
           (class "class_definition")
           (method "function_definition")
           (loop (or "for_statement" "while_statement"))
           (conditional "if_statement")
           (decorator (or "decorator" "decorated_definition"))
           (call "call")
           (parameter (or "parameters" "default_parameter"
                          "lambda_parameters" "list_splat_pattern"
                          "dictionary_splat_pattern"))
           (argument_list "argument_list")
           ;; `str-lit' not `string': symbol collides with the built-in
           ;; `string' function and `treesit-node-match-p' (a C
           ;; function) tries to call it before consulting settings.
           ;; Anchored regex picks the full `string' node (including
           ;; quotes), not the inner `string_content'.
           (str-lit "\\`string\\'")
           (statement "_\\(statement\\|definition\\)\\'"))))
    (let ((existing (cdr (assq 'python treesit-thing-settings))))
      (dolist (extra extras)
        (unless (assq (car extra) existing)
          (setq existing (append existing (list extra)))))
      (setq-local treesit-thing-settings
                  (cons (cons 'python existing)
                        (assq-delete-all
                         'python
                         (copy-sequence treesit-thing-settings)))))))

;; Runs before `after-change-major-mode-hook', so by the time
;; `zetta-treesit-setup-buffer-forward-bridges' fires our extras are
;; already in `treesit-thing-settings' and the providers get installed.
(add-hook 'python-ts-mode-hook #'zetta-python-ts-extend-things)
;;; treesit.el ends here
