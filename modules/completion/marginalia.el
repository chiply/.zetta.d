;;; marginalia.el --- Configure marginalia -*- lexical-binding: t; -*-

;; for candidate metadata
(use-package marginalia
  :init
  (marginalia-mode)
  :bind (:map minibuffer-local-map
         ("M-A" . marginalia-cycle))
  :config
  ;; rich annotations for lsp completion candidates in minibuffer
  ;; sessions (C-SPC / corfu M-m): each candidate carries the full
  ;; CompletionItem; resolving fills in detail (defining module) and
  ;; documentation.  Cost is once per candidate — lsp caches the
  ;; resolve on the item, marginalia caches the annotation.  M-A
  ;; (marginalia-cycle) steps lsp-capf -> builtin "(Function)" -> none.
  (defun zetta-marginalia-annotate-lsp-capf (cand)
    "Annotate lsp-capf CAND with kind, defining module, first doc line."
    (when-let* ((item (or (get-text-property 0 'lsp-completion-item cand)
                          (get-text-property 0 'lsp-completion-unresolved-item
                                             cand))))
      (let* ((resolved (or (ignore-errors (lsp-completion--resolve cand)) cand))
             (ritem (or (get-text-property 0 'lsp-completion-item resolved)
                        item))
             (kind? (lsp:completion-item-kind? ritem))
             (kind (and kind? (aref lsp-completion--item-kind kind?)))
             (detail (lsp:completion-item-detail? ritem))
             (doc (lsp:completion-item-documentation? ritem))
             (doc-text (cond ((and doc (lsp-markup-content? doc))
                              (lsp:markup-content-value doc))
                             ((stringp doc) doc)))
             ;; first prose line: skip fenced code blocks entirely
             ;; (pylsp leads with the signature in a ```python fence)
             (doc-line (when doc-text
                         (let ((lines (split-string doc-text "\n"))
                               (in-fence nil)
                               result)
                           (while (and lines (not result))
                             (let ((l (pop lines)))
                               (cond ((string-prefix-p "```" l)
                                      (setq in-fence (not in-fence)))
                                     ((and (not in-fence)
                                           (not (string-empty-p l)))
                                      (setq result l)))))
                           result))))
        (marginalia--fields
         ((or kind "") :face 'marginalia-type :width 10)
         ((or detail "") :face 'marginalia-value :width 14)
         ((or doc-line "") :face 'marginalia-documentation :truncate 0.5)))))
  (add-to-list 'marginalia-annotators
               '(lsp-capf zetta-marginalia-annotate-lsp-capf builtin none)))
;;; marginalia.el ends here
