;;; svg-margin-test.el --- Tests for svg-margin -*- lexical-binding: t; -*-

;;; Commentary:
;; Pure-logic tests (column packing, colour, normalisation, grouping, shape
;; registry).  Rendering/overlay/margin behaviour needs a live graphical
;; frame and is not exercised here.

;;; Code:

(require 'ert)
(require 'svg-margin)

;;;; Colour

(ert-deftest svg-margin/color-passthrough-and-names ()
  (should (equal (svg-margin--color "#ab12ef") "#ab12ef"))
  (should (equal (svg-margin--color nil) nil))
  (should (string-prefix-p "#" (svg-margin--color "red")))
  ;; 12-digit form collapses to 6
  (should (string-match-p "\\`#[0-9a-f]\\{6\\}\\'" (svg-margin--color "#ffff00000000"))))

;;;; Column packing

(ert-deftest svg-margin/pack-auto-fills-lowest-free ()
  (let* ((inds (list (list :id 'a) (list :id 'b) (list :id 'c)))
         (packed (svg-margin--pack-columns inds))
         (cols (mapcar (lambda (c) (plist-get c :column)) packed)))
    (should (equal (sort cols #'<) '(0 1 2)))))

(ert-deftest svg-margin/pack-honours-explicit-column ()
  (let* ((inds (list (list :id 'a :column 2) (list :id 'b)))
         (packed (svg-margin--pack-columns inds))
         (by-id (lambda (id) (cl-find-if (lambda (c) (eq (plist-get (plist-get c :indicator) :id) id)) packed))))
    (should (= 2 (plist-get (funcall by-id 'a) :column)))
    ;; b takes the lowest free slot (0), not colliding with a's explicit 2
    (should (= 0 (plist-get (funcall by-id 'b) :column)))))

(ert-deftest svg-margin/pack-priority-orders-first ()
  ;; Higher priority is placed first, so it claims column 0.
  (let* ((inds (list (list :id 'lo :priority 1) (list :id 'hi :priority 9)))
         (packed (svg-margin--pack-columns inds))
         (hi (cl-find-if (lambda (c) (eq (plist-get (plist-get c :indicator) :id) 'hi)) packed)))
    (should (= 0 (plist-get hi :column)))))

(ert-deftest svg-margin/max-column-counts-slots ()
  (should (= 3 (svg-margin--max-column
                (list (list :column 0) (list :column 2) (list :column 1))))))

;;;; Normalisation + grouping

(ert-deftest svg-margin/normalize-line-to-bol-pos ()
  (with-temp-buffer
    (insert "line one\nline two\nline three\n")
    (let ((n (svg-margin--normalize '(:line 2 :shape dot))))
      (should n)
      (should (eq (plist-get n :side) 'left))
      ;; pos is beginning of line 2
      (should (= (plist-get n :pos)
                 (save-excursion (goto-char (point-min)) (forward-line 1) (point)))))))

(ert-deftest svg-margin/normalize-rejects-positionless ()
  (with-temp-buffer
    (insert "x\n")
    (should-not (svg-margin--normalize '(:shape dot)))))

(ert-deftest svg-margin/normalize-right-side ()
  (with-temp-buffer
    (insert "a\n")
    (should (eq 'right (plist-get (svg-margin--normalize '(:line 1 :side right)) :side)))))

(ert-deftest svg-margin/group-by-pos-and-side ()
  (let* ((a (list :pos 1 :side 'left)) (b (list :pos 1 :side 'left))
         (c (list :pos 1 :side 'right))
         (h (svg-margin--group (list a b c))))
    (should (= 2 (length (gethash '(1 . left) h))))
    (should (= 1 (length (gethash '(1 . right) h))))))

;;;; Shape registry

(ert-deftest svg-margin/builtin-shapes-registered ()
  (dolist (s '(dot circle bar box triangle))
    (should (functionp (gethash s svg-margin--shapes)))))

(ert-deftest svg-margin/define-shape-adds-entry ()
  (unwind-protect
      (progn
        (svg-margin-define-shape 'test-shape (lambda (&rest _) nil))
        (should (functionp (gethash 'test-shape svg-margin--shapes))))
    (remhash 'test-shape svg-margin--shapes)))

;;;; Provider registry

(ert-deftest svg-margin/register-and-unregister-provider ()
  (let ((svg-margin--providers nil))
    (cl-letf (((symbol-function 'svg-margin-refresh-all) #'ignore))
      (svg-margin-register-provider 'p (lambda (_b) nil))
      (should (assq 'p svg-margin--providers))
      (svg-margin-unregister-provider 'p)
      (should-not (assq 'p svg-margin--providers)))))

(provide 'svg-margin-test)
;;; svg-margin-test.el ends here
