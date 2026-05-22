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

;; Table-driven extension of `treesit-thing-settings' across languages.
;; Bridge A in `tap.el' surfaces a fixed taxonomy (function, class,
;; loop, conditional, decorator, call, parameter, argument_list,
;; str-lit, statement, ...) via thing-at-point / forward-thing /
;; embark. Each language's grammar names its AST nodes differently, so
;; we keep a per-language extras table and a single hook that applies
;; them whenever a treesit parser is created in a buffer.
;;
;; Caveats baked into the regexes:
;; - All anchored with \\` ... \\' so e.g. `string' matches only the
;;   `string' node, not `string_content' / `string_start' / `string_end'.
;; - Thing symbols must not collide with built-in function names --
;;   `treesit-node-match-p' (C) tries `funcall' before consulting
;;   settings. Hence `str-lit', not `string'.

(defvar zetta-treesit-language-extras
  (let ((typescript-extras
         '((function "\\`\\(function_declaration\\|function_expression\\|arrow_function\\|method_definition\\|generator_function_declaration\\)\\'")
           (class "\\`class_declaration\\'")
           (method "\\`method_definition\\'")
           (interface "\\`interface_declaration\\'")
           (loop "\\`\\(for_statement\\|while_statement\\|for_in_statement\\|do_statement\\)\\'")
           (conditional "\\`\\(if_statement\\|ternary_expression\\)\\'")
           (decorator "\\`decorator\\'")
           (call "\\`\\(call_expression\\|new_expression\\)\\'")
           (parameter "\\`\\(required_parameter\\|optional_parameter\\)\\'")
           (argument_list "\\`arguments\\'")
           (str-lit "\\`\\(string\\|template_string\\)\\'")
           (statement "_\\(statement\\|declaration\\)\\'"))))
    `((python
       (function "\\`function_definition\\'")
       (class "\\`class_definition\\'")
       (method "\\`function_definition\\'")
       (loop "\\`\\(for_statement\\|while_statement\\)\\'")
       (conditional "\\`if_statement\\'")
       (decorator "\\`\\(decorator\\|decorated_definition\\)\\'")
       (call "\\`call\\'")
       (parameter "\\`\\(parameters\\|default_parameter\\|lambda_parameters\\|list_splat_pattern\\|dictionary_splat_pattern\\)\\'")
       (argument_list "\\`argument_list\\'")
       (str-lit "\\`string\\'")
       (statement "_\\(statement\\|definition\\)\\'"))
      (typescript ,@typescript-extras)
      (tsx ,@typescript-extras)))
  "Alist of (LANG . EXTRAS) augmenting `treesit-thing-settings'.
Each EXTRAS is a list of (THING PREDICATE) entries in the same shape
`treesit-thing-settings' accepts. Applied by
`zetta-treesit-apply-language-extras' on `after-change-major-mode-hook'
for every language with a parser in the current buffer.
Add languages by pushing entries; the wiring is automatic.")

(defun zetta-treesit-extend-language-things (lang extras)
  "Append EXTRAS to LANG's section of `treesit-thing-settings'.
Buffer-local. Idempotent: existing thing definitions are preserved."
  (let ((existing (cdr (assq lang treesit-thing-settings))))
    (dolist (extra extras)
      (unless (assq (car extra) existing)
        (setq existing (append existing (list extra)))))
    (setq-local treesit-thing-settings
                (cons (cons lang existing)
                      (assq-delete-all
                       lang
                       (copy-sequence treesit-thing-settings))))))

(defun zetta-treesit-apply-language-extras ()
  "Apply `zetta-treesit-language-extras' to every parser language
in this buffer. Safe in non-treesit buffers (no-op)."
  (when (and (boundp 'treesit-thing-settings)
             (fboundp 'treesit-parser-list)
             (treesit-parser-list))
    (dolist (parser (treesit-parser-list))
      (when-let* ((lang (treesit-parser-language parser))
                  (extras (alist-get lang zetta-treesit-language-extras)))
        (zetta-treesit-extend-language-things lang extras)))))

(add-hook 'after-change-major-mode-hook
          #'zetta-treesit-apply-language-extras)
;;; treesit.el ends here
