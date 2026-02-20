;; -*- lexical-binding: t; -*-

;;; Completion source selector
;; Unified interface to trigger completion from specific sources.
;; All bindings under s-c prefix.

(use-package cape
  :general
  (:keymaps 'override
   :prefix "s-c"

   ;; === Text completion ===
   "d" '(cape-dabbrev :wk "dabbrev (buffer)")
   "l" '(cape-line :wk "line")
   "w" '(cape-dict :wk "dictionary/words")
   "h" '(cape-history :wk "history")
   "k" '(cape-keyword :wk "keyword")

   ;; === Path/file completion ===
   "f" '(cape-file :wk "file path")

   ;; === Code completion ===
   "s" '(cape-elisp-symbol :wk "elisp symbol")
   ":" '(cape-emoji :wk "emoji")
   "a" '(expand-abbrev :wk "abbrev")
   "y" '(yas-expand :wk "yasnippet")

   ;; === LSP completion (when in lsp-mode buffer) ===
   "p" '(zetta-cape-complete-lsp :wk "lsp")

   ;; === AI completion ===
   "g" '(zetta-cape-complete-gptel :wk "gptel (AI)")

   ;; === Meta/cascade ===
   "c" '(zetta-completion-at-point :wk "cascade (smart)")
   "TAB" '(completion-at-point :wk "default capf")))

;;; Wrapper functions for better UX

(defun zetta-cape-complete-lsp ()
  "Complete using LSP if available, with feedback."
  (interactive)
  (if (bound-and-true-p lsp-mode)
      (let ((completion-at-point-functions '(lsp-completion-at-point)))
        (completion-at-point))
    (message "LSP not active in this buffer")))

(defun zetta-cape-complete-gptel ()
  "Complete using gptel if available."
  (interactive)
  (if (fboundp 'gptel-complete)
      (gptel-complete)
    (message "gptel-autocomplete not available")))
