;;; orderless.el --- Configure orderless -*- lexical-binding: t; -*-

(use-package orderless
  :init
  ;; style dispatchers
  (defun flex-if-twiddle (pattern _index _total)
    (when (string-prefix-p "~" pattern)
      `(orderless-flex . ,(substring pattern 1))))

  (defun annotation-if-at (pattern _index _total)
    (when (string-prefix-p "@" pattern)
      (let ((rest (substring pattern 1)))
        (if (string-prefix-p "~" rest)
            ;; @~ → flex match on annotation
            (let ((re (mapconcat (lambda (c) (regexp-quote (char-to-string c)))
                                 (string-to-list (substring rest 1)) ".*")))
              `(orderless-annotation . ,re))
          `(orderless-annotation . ,rest)))))

  (defun my/orderless-dispatcher-initialism (pattern index _total)
    (when (string-prefix-p "`" pattern)
      `(orderless-initialism . ,(substring pattern 1))))

  (defun without-if-bang (pattern _index _total)
    (cond
     ((equal "!" pattern)
      '(orderless-literal . ""))
     ((string-prefix-p "!" pattern)
      `(orderless-without-literal . ,(substring pattern 1)))))

  ;; NOTE important for things like search candidates with whitespace
  ;; or annotations with whitespace -- note that if the default " " is
  ;; used, it's more difficult to match patterns that contain
  ;; spaces. "," is safe as it is rarely if ever used in search
  ;; strings
  (setq orderless-component-separator ",")
  ;; orderless config
  (setq orderless-matching-styles '(orderless-regexp)
        orderless-style-dispatchers '(my/orderless-dispatcher-initialism
                                      flex-if-twiddle
                                      annotation-if-at
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
