
;; NOTE ht is the chosen lib for dealing with map structures

;; TODO interactive functions as action functions... need to figure out a way to do this or possibly obviate it
;; TODO get history working for consult omni!
;; TODO try multi cat
;; TODO more intuitive names
;; TODO process arguments passed in through completion UI
;; TODO dynamic group by function in consult omni
;; TODO dynamic group by function in consult
;; TODO dynamic group by function in built-in completion
;; TODO support for multiple groups and categories (at the metadata level?)
;; TODO consult--read passing a consult source as arg (prompt claude)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Completion Candidates
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; NOTE data model: cannot have multiple categories per consult source,
;; meaning you should not define category at the level of metadata in
;; the lists you produce.  Make the assumption that all elements in a
;; list are of the same overal 'type' in the semantic-type sense. This
;; is a sage assumption as these lists will most often be produced by
;; CLI commands or API requests which return lists of data elements.
;; The 'category' should correspond to one of those data types.

;; Good example -- spotify search API returns lists of tracks, albums,
;; artists... how do we deal with this response as each of the items
;; inside of tracks, albums, artitsts has a different datatype and
;; therefore should be assigned a different category?

;; point is these lists should be constructed at the granularity of
;; the underlying data type... So a single API search request will
;; return a single JSON payload, which an elisp funciton will parse
;; into potentially many lists, one per data type

(setq demo-list
      (-map (lambda (cand) 
              (propertize (car cand)
                          'category 'mycat3
                          ;; NOTE CDR can be any arbitrary data that
                          ;; can be used for multi-data
                          'multi-data (cdr cand)))
            ;; NOTE lacks category metadata
            '(("a" .  (:name "hello" :value a :m "foo a"))
              ("aaaaaaa" . (:name "hello" :value a :m "foo aa"))
              ("b" .  (:name "bye" :value b :m "bar b"))
              ("c" .  (:name "bye" :value c :m "baz c"))
              ("d" .  (:name "bye" :value d :m "qux d")))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Group Functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun demo-omni-group-function (sources cand transform &optional group-by)
  (plist-get (get-text-property 0 'multi-data cand) :name))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Completion Functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; For use with sync sources (like built-in completion or consult sync
;; sources)
;; TODO acn i tie these functions together an have the filtering in
;; the first function?  as predicate?  low priority -- can do this
;; later, but might be required for executing a ui where i can pass
;; args to the underlying collection function... in other words, how
;; do I implement an async variant of the built-in completion command?
;; Is there a way to do this?  Basically need to run collection as a
;; function and parameterize that with string
;; TODO add the category from the text properties
(defun demo-completion-function (&optional string predicate flag)
  (if (eq flag 'metadata) '(metadata (category . mycat3)) demo-list))

;; For use with async sources like consult async
(defun demo-completion-function-async (input)
  (sleep-for (+ 0.5 (random 1)))
  (-filter (lambda (x) (string-prefix-p input x)) demo-list))

;; For use with consult-omni dynamic sources
(cl-defun demo-completion-function-omni (input &rest args &key callback &allow-other-keys)
  (let ((annotated-results (demo-completion-function-async input)))
    (funcall callback annotated-results)
    annotated-results))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Embark
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun demo-action (cand)
  (let* ((multi-data (get-text-property 0 'multi-data (car demo-list)))
         (value (plist-get multi-data :value))
         (m (plist-get multi-data :m)))
    (message "%s %s %s" cand value m)
    cand))
(defvar-keymap embark-demo-keymap :parent embark-general-map)
(general-define-key :keymaps 'embark-demo-keymap "a" #'demo-action)
(add-to-list 'embark-keymap-alist '(mycat3 embark-demo-keymap))
(add-to-list 'embark-keymap-alist '(mycat2 embark-demo-keymap))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Annotations
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun annotate-mycat3 (cand) (format " <- %s" (plist-get (get-text-property 0 'multi-data cand) :m)))
(add-to-list 'marginalia-annotator-registry '(mycat3 annotate-mycat3))

(defun annotate-mycat2 (cand) (format " <- %s" (plist-get (get-text-property 0 'multi-data cand) :m)))
(add-to-list 'marginalia-annotator-registry '(mycat2 annotate-mycat2))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Consult Sources
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; NOTE no grouping is done here -- this is the data model of consult.
;; When suing multi source, each source is intended to be a single
;; category.  This is in contrast with consult-omni below where you
;; can pass dynamic group by functions to get grouping on the fly
;; TODO does grouping come with narrowing?  How to they relate?

;; Async sources
(defvar consult-demo-async-0-history nil)
(setq demo-source-async-0 `(:async ,(consult--dynamic-collection #'demo-completion-function-async :min-input 0) :name "demo-source-async-0" :narrow ?a :category mycat3 :history consult-demo-async-0-history))

(defvar consult-demo-async-1-history nil)
(setq demo-source-async-1 `(:async ,(consult--dynamic-collection #'demo-completion-function-async :min-input 0) :name "demo-source-async-1" :narrow ?b :category mycat3 :history consult-demo-async-1-history))

;; Sync sources
(defvar consult-demo-sync-0-history nil)
(setq demo-source-sync-0 `(:items ,#'demo-completion-function :name "demo-source-sync-0" :narrow ?a :category mycat3 :history consult-demo-sync-0-history))

(defvar consult-demo-sync-1-history nil)
(setq demo-source-sync-1 `(:items ,#'demo-completion-function :name "demo-source-sync-1" :narrow ?b :category mycat3 :history consult-demo-sync-1-history))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Consult commands
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defvar consult-demo-async-history nil)
(defun consult-demo-async () (interactive) (consult--multi '(demo-source-async-0 demo-source-async-1) :history '(:input consult-demo-async-history)))

(defvar consult-demo-sync-history nil)
(defun consult-demo-sync () (interactive) (consult--multi '(demo-source-sync-0 demo-source-sync-1) :history '(:input consult-demo-sync-history)))

(defvar consult-demo-mixed-history nil)
(defun consult-demo-mixed () (interactive) (consult--multi '(demo-source-async-0 demo-source-sync-0) :history '(:input consult-demo-mixed-history)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Consult omni
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; NOTE can do dynamic grouping unlike with define consult source
;; because this operates on top of consult--read
;; TODO get the select and search hist working
(defvar consult-demo-async-0-select-history (list))
(defvar consult-demo-async-0-search-history (list))
(consult-omni-define-source
 "demoasync0"
 :narrow-char ?f :min-input 0 :category 'mycat3 :require-match nil
 :type 'dynamic :request #'demo-completion-function-omni :preview-key consult-omni-preview-key
 :search-hist 'consult-demo-async-0-search-history :select-hist 'consult-demo-async-0-select-history
 :group #'demo-omni-group-function :interactive consult-omni-intereactive-commands-type
 :enabled t)

(defvar consult-demo-async-1-select-history nil)
(defvar consult-demo-async-1-search-history nil)
(consult-omni-define-source
 "demoasync1"
 :narrow-char ?f :min-input 0 :category 'mycat2 :require-match nil
 :type 'dynamic :request #'demo-completion-function-omni :preview-key consult-omni-preview-key
 :search-hist 'consult-demo-async-1-search-history :select-hist 'consult-demo-async-1-select-history
 :group #'demo-omni-group-function :interactive consult-omni-intereactive-commands-type
 :enabled t)

(defvar consult-demo-async-multi-select-history nil)
(defvar consult-demo-async-multi-search-history nil)
(setq consult-omni-demo-multi*-sources '("demoasync0" "demoasync1"))
(defun consult-omni-demo-multi* (&optional initial prompt sources no-callback &rest args)
  (interactive "P")
  (let ((sources (or sources consult-omni-demo-multi*-sources)))
    ;; NOTE min-input is specified here
    (consult-omni-multi initial prompt sources no-callback 0 args)))
(consult-customize consult-omni-demo-multi*
                    :select-hist 'consult-demo-async-multi-select-history
                    :search-hist 'consult-demo-async-multi-search-history)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Demo
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; built-in completion -- annotations and actions are enabled
;;(completing-read "Demo" #'demo-completion-function)

;; consult -- grouping, history, narrowing is present, ability to mix
;; sources is present
;;(consult-demo-async)
;;(consult-demo-sync)
;;(consult-demo-mixed)

;; consult-omni -- selection and search history
;;(consult-omni-demoasync0)
;;(consult-omni-demoasync1)

;; (consult-omni-demo-multi*)

