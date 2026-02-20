(use-package json-snatcher
  :config
  ;; adapted from the source code
  (defun jsons-get-path-python ()
    "Print the python path to the JSON value under point, and save it in the kill ring."
    (let ((path (save-excursion
                  (evil-first-non-blank)
                  (evil-forward-char)
                  (jsons-get-path)))
          (i 0)
          (python_str ""))
      (setq path (reverse path))
      (while (< i (length path))
        (if (numberp (elt path i))
            (progn
              (setq python_str (concat python_str "[" (number-to-string (elt path i)) "]"))
              (setq i (+ i 1)))
          (progn
            (setq python_str (concat python_str "[" (elt path i) "]"))
            (setq i (+ i 1)))))
      ;; this is what changes
      python_str)
    )
  )



