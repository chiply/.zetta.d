;;; present-test.el --- ERT smoke tests for present.el -*- lexical-binding: t -*-
;;
;; Run with:
;;   emacs -Q --batch -L .. -l present-test.el -f ert-run-tests-batch-and-exit
;; from the test/ directory.

(require 'ert)
(require 'cl-lib)
;; Load `present' from the parent directory.
(add-to-list 'load-path
             (file-name-directory
              (directory-file-name
               (file-name-directory
                (or load-file-name buffer-file-name)))))
(require 'present)

(ert-deftest present/subtype-basics ()
  (should (present-subtype-p 'url 'url))
  (should (present-subtype-p 'url 'string))
  (should (present-subtype-p 'integer 'number))
  (should (present-subtype-p 'integer 'string))     ; via number → string
  (should (present-subtype-p 'existing-file 'string)) ; via file-path → string
  (should (present-subtype-p 'function-name 'symbol))
  (should (present-subtype-p 'function-name 'string))
  (should-not (present-subtype-p 'url 'integer))
  (should-not (present-subtype-p 'string 'url)))

(ert-deftest present/all-subtypes ()
  (let ((subs (present--all-subtypes-of 'symbol)))
    (should (memq 'symbol subs))
    (should (memq 'function-name subs))
    (should (memq 'command-name subs))
    (should-not (memq 'url subs))))

(ert-deftest present/deftype-roundtrip ()
  (let ((present-types (copy-tree present-types)))
    (present-deftype http-url :parent url)
    (should (present-subtype-p 'http-url 'url))
    (should (present-subtype-p 'http-url 'string))))

(ert-deftest present/regex-scan-urls ()
  (with-temp-buffer
    (insert "see https://example.com and http://foo.bar/baz?x=1 also")
    (let* ((win (selected-window))  ; placeholder
           (results (present--scan-regex
                     'url (alist-get 'url present-types)
                     win (current-buffer) (point-min) (point-max))))
      (should (= 2 (length results)))
      (should (equal "https://example.com" (plist-get (car results) :text)))
      (should (equal 'url (plist-get (car results) :type))))))

(ert-deftest present/regex-scan-email ()
  (with-temp-buffer
    (insert "contact alice@example.com or bob@example.org for help")
    (let ((results (present--scan-regex
                    'email (alist-get 'email present-types)
                    (selected-window) (current-buffer)
                    (point-min) (point-max))))
      (should (= 2 (length results)))
      (should (equal "alice@example.com" (plist-get (car results) :text))))))

(ert-deftest present/regex-scan-uuid ()
  (with-temp-buffer
    (insert "id 550e8400-e29b-41d4-a716-446655440000 found")
    (let ((results (present--scan-regex
                    'uuid (alist-get 'uuid present-types)
                    (selected-window) (current-buffer)
                    (point-min) (point-max))))
      (should (= 1 (length results)))
      (should (equal "550e8400-e29b-41d4-a716-446655440000"
                     (plist-get (car results) :text))))))

(ert-deftest present/push-mode-text-property ()
  (with-temp-buffer
    (insert "before ")
    (let ((tagged (propertize "myref" 'present-type 'url)))
      (insert tagged))
    (insert " after")
    (let ((results (present--collect-push
                    (selected-window) (current-buffer)
                    (point-min) (point-max) nil)))
      (should (= 1 (length results)))
      (should (equal "myref" (plist-get (car results) :text)))
      (should (eq 'url (plist-get (car results) :type))))))

(ert-deftest present/push-mode-filter-by-expected ()
  (with-temp-buffer
    (insert (propertize "u" 'present-type 'url))
    (insert " ")
    (insert (propertize "i" 'present-type 'integer))
    ;; expect 'string — both url and integer subtype-of string, both kept
    (should (= 2 (length (present--collect-push
                          (selected-window) (current-buffer)
                          (point-min) (point-max) 'string))))
    ;; expect 'url — only url kept
    (should (= 1 (length (present--collect-push
                          (selected-window) (current-buffer)
                          (point-min) (point-max) 'url))))
    ;; expect 'integer — only integer kept
    (should (= 1 (length (present--collect-push
                          (selected-window) (current-buffer)
                          (point-min) (point-max) 'integer))))))

(ert-deftest present/symbol-predicate-function ()
  (with-temp-buffer
    (insert "try car cdr message no-such-fn-xyz print")
    (let* ((results (present--scan-symbols
                     'function-name (alist-get 'function-name present-types)
                     (selected-window) (current-buffer)
                     (point-min) (point-max)))
           (names (mapcar (lambda (p) (plist-get p :text)) results)))
      (should (member "car" names))
      (should (member "cdr" names))
      (should (member "message" names))
      (should (member "print" names))
      (should-not (member "no-such-fn-xyz" names))
      (should-not (member "try" names))))) ; 'try is not fboundp

(ert-deftest present/insert-typed ()
  (with-temp-buffer
    (present-insert-typed "https://foo" 'url)
    (should (equal "https://foo" (buffer-string)))
    (should (eq 'url (get-text-property 1 'present-type)))))

(ert-deftest present/insert-typed-with-value ()
  (with-temp-buffer
    (present-insert-typed "click me" 'url "https://real-target")
    (let ((raw (get-text-property 1 'present-type)))
      (should (consp raw))
      (should (eq 'url (car raw)))
      (should (equal "https://real-target"
                     (plist-get (cdr raw) :value))))))

(ert-deftest present/with-expected-type ()
  (present-with-expected-type 'url
    (should (eq 'url present--expected-type-override))))

(ert-deftest present/find-urls-via-shr ()
  "shr-url text property → URL presentation with description as :text
and the actual URL as :value (eww/nov/devdocs/elfeed pattern)."
  (with-temp-buffer
    (insert "Visit ")
    (insert (propertize "Anthropic" 'shr-url "https://anthropic.com"))
    (insert " for more.")
    (let ((results (present--find-urls-via-shr
                    (selected-window) (current-buffer)
                    (point-min) (point-max))))
      (should (= 1 (length results)))
      (should (equal "https://anthropic.com" (plist-get (car results) :value)))
      (should (equal "Anthropic" (plist-get (car results) :text)))
      (should (eq 'url (plist-get (car results) :type))))))

(ert-deftest present/find-urls-org ()
  "Org links `[[URL][DESC]]' → URL as :value, DESC as :text, bounds cover
the whole link so inserting yields the bare URL not the brackets."
  (with-temp-buffer
    (insert "See [[https://example.com][the docs]] and ")
    (insert "[[https://nodocs.com]] also.")
    (let* ((results (present--find-urls-org
                     (selected-window) (current-buffer)
                     (point-min) (point-max)))
           (r1 (car results))
           (r2 (cadr results)))
      (should (= 2 (length results)))
      (should (equal "https://example.com" (plist-get r1 :value)))
      (should (equal "the docs" (plist-get r1 :text)))
      (should (equal "https://nodocs.com" (plist-get r2 :value)))
      ;; No description -> text falls back to URL.
      (should (equal "https://nodocs.com" (plist-get r2 :text))))))

(ert-deftest present/find-urls-dispatch-eww-like ()
  "In an shr-rendered buffer (mocked via local major-mode), plain-text
regex is suppressed; only shr-url props produce results."
  (with-temp-buffer
    (setq major-mode 'eww-mode)
    (insert "raw https://should-not-match.com and ")
    (insert (propertize "click" 'shr-url "https://yes.com"))
    (let ((results (present--find-urls
                    (selected-window) (current-buffer)
                    (point-min) (point-max))))
      (should (= 1 (length results)))
      (should (equal "https://yes.com" (plist-get (car results) :value))))))

(ert-deftest present/find-urls-org-with-mixed-raw-and-bracketed ()
  "In an org buffer with both raw URLs and `[[URL][desc]]' links, the
dispatcher returns BOTH — the org-link as a bracketed presentation,
plus the raw URL as a plain-regex match — without double-counting the
URL inside the bracketed link."
  (with-temp-buffer
    (setq major-mode 'org-mode)
    (insert "raw https://example.com link, then ")
    (insert "[[https://bracketed.com][bracket-desc]] more.")
    (let* ((results (present--find-urls
                     (selected-window) (current-buffer)
                     (point-min) (point-max)))
           (values (mapcar (lambda (p) (plist-get p :value)) results)))
      ;; Both URLs appear exactly once.
      (should (= 2 (length results)))
      (should (member "https://example.com" values))
      (should (member "https://bracketed.com" values))
      ;; The bracketed one shows its description as :text.
      (should (cl-find-if (lambda (p)
                            (and (equal "https://bracketed.com"
                                        (plist-get p :value))
                                 (equal "bracket-desc"
                                        (plist-get p :text))))
                          results)))))

(ert-deftest present/find-urls-dispatch-plain-buffer ()
  "In a plain buffer, the regex layer fires."
  (with-temp-buffer
    (insert "see https://anthropic.com etc")
    (let ((results (present--find-urls
                    (selected-window) (current-buffer)
                    (point-min) (point-max))))
      (should (>= (length results) 1))
      (should (cl-find "https://anthropic.com" results
                       :key (lambda (p) (plist-get p :value))
                       :test #'equal)))))

(ert-deftest present/install-and-remove-highlights ()
  "Highlights paint overlays on each candidate's bounds and clean up."
  (with-temp-buffer
    (insert "hello world")
    (let* ((p1 (list :type 'url :buffer (current-buffer)
                     :window (selected-window)
                     :beg 1 :end 6 :text "hello"))
           (p2 (list :type 'url :buffer (current-buffer)
                     :window (selected-window)
                     :beg 7 :end 12 :text "world"))
           (overlays (present--install-highlights (list p1 p2))))
      (should (= 2 (length overlays)))
      (should (cl-every #'overlayp overlays))
      ;; Each overlay carries the marker prop so other code can find them.
      (should (cl-every (lambda (ov)
                          (overlay-get ov 'present-highlight))
                        overlays))
      ;; Cleanup removes them all.
      (present--remove-highlights overlays)
      (should-not (cl-some #'overlay-buffer overlays)))))

(ert-deftest present/collect-visible-end-to-end ()
  ;; Show a buffer containing a URL in a temporary frame-equivalent.
  ;; In batch we can't really walk-windows usefully, but we can verify
  ;; the function returns nil safely rather than erroring.
  (let ((result (present-collect-visible 'url)))
    (should (listp result))))

(provide 'present-smoke)
;;; present-smoke.el ends here
