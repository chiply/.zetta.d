;;; orderless.el --- Configure orderless -*- lexical-binding: t; -*-

(use-package orderless
  :init
  ;; style dispatchers
  ;; All accept the dispatcher character as either prefix OR suffix of
  ;; the component, mirroring orderless's built-in `orderless-affix-dispatch'.

  (defun flex-if-twiddle (pattern _index _total)
    (cond
     ((string-prefix-p "~" pattern)
      `(orderless-flex . ,(substring pattern 1)))
     ((string-suffix-p "~" pattern)
      `(orderless-flex . ,(substring pattern 0 -1)))))

  (defun annotation-if-at (pattern _index _total)
    "Annotation-match `@P' or `P@'; flex-annotation-match `@~P', `~P@',
`@P~', or `P~@' (the inner `~' may also sit at either end)."
    (let ((rest
           (cond
            ((string-prefix-p "@" pattern) (substring pattern 1))
            ((string-suffix-p "@" pattern) (substring pattern 0 -1)))))
      (when rest
        (cond
         ((string-prefix-p "~" rest)
          (let ((re (mapconcat (lambda (c) (regexp-quote (char-to-string c)))
                               (string-to-list (substring rest 1)) ".*")))
            `(orderless-annotation . ,re)))
         ((string-suffix-p "~" rest)
          (let ((re (mapconcat (lambda (c) (regexp-quote (char-to-string c)))
                               (string-to-list (substring rest 0 -1)) ".*")))
            `(orderless-annotation . ,re)))
         (t `(orderless-annotation . ,rest))))))

  (defun my/orderless-dispatcher-initialism (pattern _index _total)
    (cond
     ((string-prefix-p "`" pattern)
      `(orderless-initialism . ,(substring pattern 1)))
     ((string-suffix-p "`" pattern)
      `(orderless-initialism . ,(substring pattern 0 -1)))))

  (defun without-if-bang (pattern _index _total)
    (cond
     ((equal "!" pattern)
      '(orderless-literal . ""))
     ((string-prefix-p "!" pattern)
      `(orderless-without-literal . ,(substring pattern 1)))
     ((string-suffix-p "!" pattern)
      `(orderless-without-literal . ,(substring pattern 0 -1)))))

  ;; NOTE important for things like search candidates with whitespace
  ;; or annotations with whitespace -- note that if the default " " is
  ;; used, it's more difficult to match patterns that contain
  ;; spaces. "," is safe as it is rarely if ever used in search
  ;; strings
  (setq orderless-component-separator ",")
  ;; orderless config
  (setq orderless-matching-styles '(orderless-regexp)
        ;; annotation-if-at must precede flex-if-twiddle: with suffix
        ;; support added, a compound like `@PATTERN~' (annotation+flex)
        ;; would otherwise fire flex on the trailing `~' before
        ;; annotation gets a chance to claim the leading `@'.
        orderless-style-dispatchers '(my/orderless-dispatcher-initialism
                                      annotation-if-at
                                      flex-if-twiddle
                                      without-if-bang)
        completion-styles '(orderless basic)
        completion-category-defaults nil
        completion-category-overrides '((file (styles basic partial-completion))))
  ;; to plase corfu
  (add-to-list 'completion-styles-alist
               '(tab completion-basic-try-completion ignore
                     "Completion style which provides TAB completion only."))
  ;; NOTE also gets set in prescient
  (setq completion-styles '(tab orderless basic))
  )
;;; orderless.el ends here
