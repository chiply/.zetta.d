
(require 'consult-omni)

(setq demo-list-with-data
      (-map
       (lambda (cand) 
         (propertize (car cand) 'category 'mycat3
                     'multi-data (cdr cand)))
       '(("a" . (:value a :m "foo a"))
         ("aa" . (:value a :m "foo aa"))
         ("b" . (:value b :m "bar b"))
         ("c" . (:value c :m "baz c"))
         ("d" . (:value d :m "qux d")))))

;;(setq demo-list-with-data
;;'(("a" :name "foobar") ("aa") ("b") ("c") ("d")))


(defun filter-results (input)
  (progn
    ;; sleep for a random time between 0.5 and 1.5 seconds
    (sleep-for (+ 0.5 (random 1)))
    ;; NOTE this is a filter for the initial list of candidates pulled
    ;; into the minibuffer
    (-filter
     (lambda (x) (string-prefix-p input x))
     demo-list-with-data))
  )

(cl-defun consult-omni--demo-fetch-results (input &rest args &key callback &allow-other-keys)
  (let ((annotated-results (filter-results input)))
    (funcall callback annotated-results)
    annotated-results))

;; Define the Wikipedia source
(consult-omni-define-source "omnidemo"
                            :min-input 0
                            :narrow-char ?w
                            :type 'dynamic
                            :require-match nil
                            :request #'consult-omni--demo-fetch-results
                            :preview-key consult-omni-preview-key
                            ;; TODO replace
                            :search-hist 'consult-omni--search-history
                            :select-hist 'consult-omni--selection-history
                            :enabled t
                            :group #'consult-omni--group-function
                            :sort t
                            :type 'dynamic
                            :interactive consult-omni-intereactive-commands-type)

