;;; embark-by-type-test.el --- ERT smoke tests -*- lexical-binding: t -*-

;; Run with:
;;   emacs -Q --batch -L .. -L <embark-load-path> -L <treesit-tap-load-path> \
;;        -l embark-by-type-test.el -f ert-run-tests-batch-and-exit
;; from the test/ directory.

(require 'ert)
(require 'cl-lib)
;; Load `embark-by-type' from the parent directory.
(add-to-list 'load-path
             (file-name-directory
              (directory-file-name
               (file-name-directory
                (or load-file-name buffer-file-name)))))
(require 'embark-by-type)


;;;; Sort

(ert-deftest embark-by-type/sort-by-bounds ()
  "Innermost-first sort puts the smallest-bounds target first."
  (let ((targets `((:type a :bounds (1 . 100))
                   (:type b :bounds (10 . 20))
                   (:type c :bounds (5 . 50))
                   (:type d))))
    (let ((sorted (embark-by-type--sort-targets-by-bounds targets)))
      (should (eq 'b (plist-get (nth 0 sorted) :type)))
      (should (eq 'c (plist-get (nth 1 sorted) :type)))
      (should (eq 'a (plist-get (nth 2 sorted) :type)))
      ;; Without bounds -- pushed to end.
      (should (eq 'd (plist-get (nth 3 sorted) :type))))))

(ert-deftest embark-by-type/sort-by-bounds-reverse ()
  "With dynamic reverse, outermost first."
  (let ((targets `((:type a :bounds (1 . 100))
                   (:type b :bounds (10 . 20))))
        (embark-by-type--sort-reverse t))
    (let ((sorted (embark-by-type--sort-targets-by-bounds targets)))
      (should (eq 'a (plist-get (nth 0 sorted) :type))))))


;;;; Type-key assignment

(ert-deftest embark-by-type/assign-type-keys ()
  "First free char of each type name wins; fallbacks for conflicts."
  (let ((result (embark-by-type--assign-type-keys
                 '(url org-url-link symbol function line))))
    (should (eq 'url (alist-get ?u result)))
    (should (eq 'org-url-link (alist-get ?o result)))  ; 'u' taken
    (should (eq 'symbol (alist-get ?s result)))
    (should (eq 'function (alist-get ?f result)))
    (should (eq 'line (alist-get ?l result)))))


;;;; Capture-mode

(ert-deftest embark-by-type/capture-mode-toggle ()
  "Toggling capture-mode installs and removes pre-action hook + rotate advice."
  (unwind-protect
      (progn
        (embark-by-type-capture-mode 1)
        ;; Hook installed.
        (should (memq #'embark-by-type--capture-target
                      (alist-get :always embark-pre-action-hooks)))
        ;; Rotate advice installed.
        (should (advice-member-p
                 #'embark-by-type--capture-on-rotate 'embark--rotate))
        ;; Toggle off.
        (embark-by-type-capture-mode -1)
        (should-not (memq #'embark-by-type--capture-target
                          (alist-get :always embark-pre-action-hooks)))
        (should-not (advice-member-p
                     #'embark-by-type--capture-on-rotate 'embark--rotate)))
    (embark-by-type-capture-mode -1)))

(ert-deftest embark-by-type/capture-mode-idempotent ()
  "Toggling on twice installs only one hook entry."
  (unwind-protect
      (progn
        (embark-by-type-capture-mode 1)
        (embark-by-type-capture-mode 1)
        (let ((count (cl-count #'embark-by-type--capture-target
                               (alist-get :always embark-pre-action-hooks))))
          (should (= 1 count))))
    (embark-by-type-capture-mode -1)))


;;;; Capture-mode guard

(ert-deftest embark-by-type/nav-without-capture-errors ()
  "Calling nav-next without capture-mode signals user-error."
  (embark-by-type-capture-mode -1)
  (should-error (embark-by-type-nav-next) :type 'user-error))


;;;; Sort-by-bounds-mode toggle

(ert-deftest embark-by-type/sort-by-bounds-mode-toggle ()
  "Toggling installs/removes the :filter-return advice."
  (unwind-protect
      (progn
        (embark-by-type-sort-by-bounds-mode 1)
        (should (advice-member-p
                 #'embark-by-type--sort-targets-by-bounds 'embark--targets))
        (embark-by-type-sort-by-bounds-mode -1)
        (should-not (advice-member-p
                     #'embark-by-type--sort-targets-by-bounds 'embark--targets)))
    (embark-by-type-sort-by-bounds-mode -1)))


;;;; Bridge B macro

(ert-deftest embark-by-type/deftap-finder-generates-fn ()
  "Macro generates `embark-by-type-target-<thing>-at-point' and adds to finders."
  (let ((embark-target-finders nil))
    (eval '(embark-by-type-deftap-finder paragraph))
    (should (fboundp 'embark-by-type-target-paragraph-at-point))
    (should (memq 'embark-by-type-target-paragraph-at-point
                  embark-target-finders))))


;;;; Collectors

(ert-deftest embark-by-type/collect-by-regex ()
  "Regex collector returns (BEG . END) for each match."
  (with-temp-buffer
    (insert "see https://a.com and https://b.io for more")
    (let ((results (embark-by-type-collect-bounds-by-regex
                    embark-by-type-url-regex (point-min) (point-max))))
      (should (= 2 (length results)))
      (should (equal "https://a.com"
                     (buffer-substring (car (car results))
                                       (cdr (car results))))))))

(ert-deftest embark-by-type/collect-org-links-visible-bounds ()
  "Org-link collector returns DESCRIPTION bounds when present."
  (with-temp-buffer
    (insert "before [[https://example.com][Docs]] middle [[https://other.com]] end")
    (let ((results (embark-by-type-collect-org-links-of-scheme
                    "\\`https?://" (point-min) (point-max))))
      (should (= 2 (length results)))
      ;; First link -- bounds cover "Docs".
      (should (equal "Docs"
                     (buffer-substring (car (car results))
                                       (cdr (car results)))))
      ;; Second link -- no DESC, bounds cover the URL itself.
      (should (equal "https://other.com"
                     (buffer-substring (car (cadr results))
                                       (cdr (cadr results))))))))


;;;; Word finder gating

(ert-deftest embark-by-type/word-finder-gates-on-modes ()
  "Word finder fires in elisp / text but not in random prog modes."
  (with-temp-buffer
    (emacs-lisp-mode)
    (insert "some-function-here")
    (goto-char 6)
    (should (consp (embark-by-type-target-word-at-point))))
  (with-temp-buffer
    (insert "alpha beta gamma")
    (goto-char 8)
    (setq major-mode 'java-mode)
    (should-not (embark-by-type-target-word-at-point))))


(provide 'embark-by-type-test)
;;; embark-by-type-test.el ends here
