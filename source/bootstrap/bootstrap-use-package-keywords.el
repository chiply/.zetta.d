;;; bootstrap-use-package-keywords.el --- Custom use-package keywords -*- lexical-binding: t; -*-

;; Shared handler for custom use-package keywords.
;; Each keyword follows the same pattern: defalias handler + normalizer, then register.

(defun use-package-handle-forms (name _keyword arg rest state)
  (let* ((body (use-package-process-keywords name rest state))
         (name-symbol (use-package-as-symbol name)))
    (use-package-concat
     (when use-package-compute-statistics
       `((use-package-statistics-gather :config ',name nil)))
     (if (and (or (null arg) (equal arg '(t))) (not use-package-inject-hooks))
         body
       (use-package-with-elapsed-timer
           (format "Configuring package %s" name-symbol)
         (funcall use-package--hush-function :config
                  (use-package-concat
                   (use-package-hook-injector
                    (symbol-name name-symbol) :config arg)
                   body
                   (list t)))))
     (when use-package-compute-statistics
       `((use-package-statistics-gather :config ',name t))))))

;;; :evil — runs forms inline (used by modules/editor/evil.el and others)
(defalias 'use-package-handler/:evil 'use-package-handle-forms)
(defalias 'use-package-normalize/:evil 'use-package-normalize-forms)
(add-to-list 'use-package-keywords :evil t)

;;; :display — runs forms inline (used by display-related modules)
(defalias 'use-package-handler/:display 'use-package-handle-forms)
(defalias 'use-package-normalize/:display 'use-package-normalize-forms)
(add-to-list 'use-package-keywords :display t)

;;; :brushup — registered by the external chiply/brushup package, not here.

(provide 'bootstrap-use-package-keywords)
;;; bootstrap-use-package-keywords.el ends here
