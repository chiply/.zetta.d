;;; -*- lexical-binding: t; -*-


(require 'ht)


(fset 'alist-get-chain 'alist-get)
(defun alist-get-chain (symbols alist)
  "Look up the value for the chain of SYMBOLS in ALIST."
  (if symbols
      (alist-get-chain (cdr symbols)
                       (assoc (car symbols) alist))
    (cdr alist)))


(defun spot--alist-to-ht (alist)
  "Convert a JSON object to a hash table, handling nested structures."
  (cond
   ;; Handle cons cells (alists)
   ((and (consp alist) (consp (car alist)))
    (ht-from-alist
     (mapcar (lambda (pair)
               (cons (car pair)
                     (spot--alist-to-ht (cdr pair))))
             alist)))
   ;; Handle arrays
   ((vectorp alist)
    (mapcar #'spot--alist-to-ht alist))
   ;; Return primitive values as-is
   (t alist)))


(defun spot--propertize-items (tables)
  (-map
   (lambda (table) 
     (propertize
      (ht-get table 'name)
      ;; NOTE will be overridden anyway, could make this
      ;; 'spot--search-items
      'category (intern (ht-get table 'type))
      ;; NOTE CDR can be any arbitrary data that can be
      ;; used for multi-data
      'multi-data table))
   tables))


(defun spot--type-equals (cand type)
  (string= (ht-get (get-text-property 0 'multi-data cand) 'type) type))


(defun spot--filter (candidates type)
  (-filter (lambda (cand) (spot--type-equals cand type)) candidates))



(provide 'spot-util)

