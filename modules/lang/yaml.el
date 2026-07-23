;;; yaml.el --- Configure yaml -*- lexical-binding: t; -*-

;; The elpaca order (with the zkry/yaml.el recipe) lives in
;; bootstrap-elpaca.el: ~/.private.el's swagg declaration loads before the
;; modules and pulls yaml as a dependency, so an order declared here always
;; arrived second (duplicate-queue warning, recipe ignored).
(use-package yaml
  :ensure nil)

(defun jpt-yaml-indentation-level (s)
  (if (string-match "^ " s)
      (+ 1 (jpt-yaml-indentation-level (substring s 1)))
    0))

(defun jpt-yaml-current-line ()
  (buffer-substring-no-properties (point-at-bol) (point-at-eol)))

(defun jpt-yaml-clean-string (s)
  (let* ((s (replace-regexp-in-string "^[ -:]*" "" s))
         (s (replace-regexp-in-string ":$" "" s)))
    s))

(defun jpt-yaml-not-blank-p (s)
  (string-match "[^[:blank:]]" s))

(defun jpt-yaml-path-to-point ()
  (save-excursion
    (let* ((line (jpt-yaml-current-line))
           (level (jpt-yaml-indentation-level line))
           result)
      (while (> (point) (point-min))
        (beginning-of-line 0)
        (setq line (jpt-yaml-current-line))

        (let ((new-level (jpt-yaml-indentation-level line)))
          (when (and (jpt-yaml-not-blank-p line)
                     (< new-level level))

            (setq level new-level)
            (setq result (push (jpt-yaml-clean-string line) result)))))

      (mapconcat 'identity result "/"))))

(defun jpt-yaml-show-path-to-point ()
  (interactive)
  (message (jpt-yaml-path-to-point)))

(eval-after-load 'yaml-mode
  '(progn
     (define-key yaml-mode-map (kbd "C-x p") 'jpt-yaml-show-path-to-point)))
;;; yaml.el ends here
