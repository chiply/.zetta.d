;;; embark-scope-test.el --- ERT smoke tests -*- lexical-binding: t -*-

;; Run with:
;;   emacs -Q --batch -L .. -L <embark-load-path> -L <treesit-tap-load-path> \
;;        -l embark-scope-test.el -f ert-run-tests-batch-and-exit
;; from the test/ directory.

(require 'ert)
(require 'cl-lib)
;; Load `embark-scope' from the parent directory.
(add-to-list 'load-path
             (file-name-directory
              (directory-file-name
               (file-name-directory
                (or load-file-name buffer-file-name)))))
(require 'embark-scope)


;;;; Sort

(ert-deftest embark-scope/sort-by-bounds ()
  "Innermost-first sort puts the smallest-bounds target first."
  (let ((targets `((:type a :bounds (1 . 100))
                   (:type b :bounds (10 . 20))
                   (:type c :bounds (5 . 50))
                   (:type d))))
    (let ((sorted (embark-scope--sort-targets-by-bounds targets)))
      (should (eq 'b (plist-get (nth 0 sorted) :type)))
      (should (eq 'c (plist-get (nth 1 sorted) :type)))
      (should (eq 'a (plist-get (nth 2 sorted) :type)))
      ;; Without bounds -- pushed to end.
      (should (eq 'd (plist-get (nth 3 sorted) :type))))))

(ert-deftest embark-scope/sort-by-bounds-reverse ()
  "With dynamic reverse, outermost first."
  (let ((targets `((:type a :bounds (1 . 100))
                   (:type b :bounds (10 . 20))))
        (embark-scope--sort-reverse t))
    (let ((sorted (embark-scope--sort-targets-by-bounds targets)))
      (should (eq 'a (plist-get (nth 0 sorted) :type))))))


;;;; Type-key assignment

(ert-deftest embark-scope/assign-type-keys ()
  "First free char of each type name wins; fallbacks for conflicts."
  (let ((result (embark-scope--assign-type-keys
                 '(url org-url-link symbol function line))))
    (should (eq 'url (alist-get ?u result)))
    (should (eq 'org-url-link (alist-get ?o result)))  ; 'u' taken
    (should (eq 'symbol (alist-get ?s result)))
    (should (eq 'function (alist-get ?f result)))
    (should (eq 'line (alist-get ?l result)))))


;;;; Capture-mode

(ert-deftest embark-scope/capture-mode-toggle ()
  "Toggling capture-mode installs and removes pre-action hook + rotate advice."
  (unwind-protect
      (progn
        (embark-scope-capture-mode 1)
        ;; Hook installed.
        (should (memq #'embark-scope--capture-target
                      (alist-get :always embark-pre-action-hooks)))
        ;; Rotate advice installed.
        (should (advice-member-p
                 #'embark-scope--capture-on-rotate 'embark--rotate))
        ;; Toggle off.
        (embark-scope-capture-mode -1)
        (should-not (memq #'embark-scope--capture-target
                          (alist-get :always embark-pre-action-hooks)))
        (should-not (advice-member-p
                     #'embark-scope--capture-on-rotate 'embark--rotate)))
    (embark-scope-capture-mode -1)))

(ert-deftest embark-scope/capture-mode-idempotent ()
  "Toggling on twice installs only one hook entry."
  (unwind-protect
      (progn
        (embark-scope-capture-mode 1)
        (embark-scope-capture-mode 1)
        (let ((count (cl-count #'embark-scope--capture-target
                               (alist-get :always embark-pre-action-hooks))))
          (should (= 1 count))))
    (embark-scope-capture-mode -1)))


;;;; Capture-mode guard

(ert-deftest embark-scope/nav-without-capture-errors ()
  "Calling nav-next without capture-mode signals user-error."
  (embark-scope-capture-mode -1)
  (should-error (embark-scope-nav-next) :type 'user-error))


;;;; Sort-by-bounds-mode toggle

(ert-deftest embark-scope/sort-by-bounds-mode-toggle ()
  "Toggling installs/removes the :filter-return advice."
  (unwind-protect
      (progn
        (embark-scope-sort-by-bounds-mode 1)
        (should (advice-member-p
                 #'embark-scope--sort-targets-by-bounds 'embark--targets))
        (embark-scope-sort-by-bounds-mode -1)
        (should-not (advice-member-p
                     #'embark-scope--sort-targets-by-bounds 'embark--targets)))
    (embark-scope-sort-by-bounds-mode -1)))


;;;; Bridge B macro

(ert-deftest embark-scope/deftap-finder-generates-fn ()
  "Macro generates `embark-scope-target-<thing>-at-point' and adds to finders."
  (let ((embark-target-finders nil))
    (eval '(embark-scope-deftap-finder paragraph))
    (should (fboundp 'embark-scope-target-paragraph-at-point))
    (should (memq 'embark-scope-target-paragraph-at-point
                  embark-target-finders))))


;;;; Collectors

(ert-deftest embark-scope/collect-by-regex ()
  "Regex collector returns (BEG . END) for each match."
  (with-temp-buffer
    (insert "see https://a.com and https://b.io for more")
    (let ((results (embark-scope-collect-bounds-by-regex
                    embark-scope-url-regex (point-min) (point-max))))
      (should (= 2 (length results)))
      (should (equal "https://a.com"
                     (buffer-substring (car (car results))
                                       (cdr (car results))))))))

(ert-deftest embark-scope/collect-org-links-visible-bounds ()
  "Org-link collector returns DESCRIPTION bounds when present."
  (with-temp-buffer
    (insert "before [[https://example.com][Docs]] middle [[https://other.com]] end")
    (let ((results (embark-scope-collect-org-links-of-scheme
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

(ert-deftest embark-scope/word-finder-gates-on-modes ()
  "Word finder fires in elisp / text but not in random prog modes."
  (with-temp-buffer
    (emacs-lisp-mode)
    (insert "some-function-here")
    (goto-char 6)
    (should (consp (embark-scope-target-word-at-point))))
  (with-temp-buffer
    (insert "alpha beta gamma")
    (goto-char 8)
    (setq major-mode 'java-mode)
    (should-not (embark-scope-target-word-at-point))))


;;;; Capture-on-rotate updates last-target vars

(ert-deftest embark-scope/capture-on-rotate-updates-vars ()
  "`--capture-on-rotate' updates `-last-target-type'/`-bounds' from
the head of the rotated list and returns it unchanged."
  (let ((embark-scope-last-target-type nil)
        (embark-scope-last-target-bounds nil)
        (rotated '((:type url :bounds (10 . 25) :target "https://x"))))
    (let ((ret (embark-scope--capture-on-rotate rotated)))
      (should (eq 'url embark-scope-last-target-type))
      (should (equal '(10 . 25) embark-scope-last-target-bounds))
      ;; Returns list unchanged (filter-return contract).
      (should (eq rotated ret)))))

(ert-deftest embark-scope/capture-on-rotate-empty-noop ()
  "`--capture-on-rotate' on an empty list leaves vars alone."
  (let ((embark-scope-last-target-type 'pre)
        (embark-scope-last-target-bounds '(1 . 2)))
    (embark-scope--capture-on-rotate nil)
    (should (eq 'pre embark-scope-last-target-type))
    (should (equal '(1 . 2) embark-scope-last-target-bounds))))


;;;; require-capture-mode guards every nav/act command

(ert-deftest embark-scope/all-guarded-commands-error-without-capture ()
  "Every `nav-*'/`act-*' command must `user-error' when capture-mode
is off.  Catches drift from the guard pattern."
  (embark-scope-capture-mode -1)
  (dolist (cmd '(embark-scope-nav-next
                 embark-scope-nav-prev
                 embark-scope-nav-beg
                 embark-scope-nav-end
                 embark-scope-act-focus
                 embark-scope-act-set-current-thing
                 embark-scope-act-highlight-instances
                 embark-scope-act-select-as-region
                 embark-scope-act-narrow
                 embark-scope-pick-instance
                 embark-scope-avy-pick-instance))
    (should-error (funcall cmd) :type 'user-error)))


;;;; collect-visible-instances dispatcher
;; In batch the temp buffer isn't displayed in a window, so
;; `(window-start)' / `(window-end)' return the selected window's
;; bounds instead of the temp buffer's.  Stub them to (point-min) /
;; (point-max) so the dispatcher scans the temp buffer.

(defmacro embark-scope-test--with-stubbed-window-bounds (&rest body)
  `(cl-letf (((symbol-function 'window-start) (lambda (&rest _) (point-min)))
             ((symbol-function 'window-end) (lambda (&rest _) (point-max))))
     ,@body))

(ert-deftest embark-scope/collect-visible-dispatch-url ()
  "Dispatcher for `'url' uses the regex sweep."
  (with-temp-buffer
    (insert "alpha https://x.io beta")
    (embark-scope-test--with-stubbed-window-bounds
     (let ((results (embark-scope-collect-visible-instances 'url 'url)))
       (should (= 1 (length results)))
       (should (equal "https://x.io"
                      (buffer-substring (car (car results))
                                        (cdr (car results)))))))))

(ert-deftest embark-scope/collect-visible-dispatch-email ()
  (with-temp-buffer
    (insert "from alice@example.com to bob@example.org")
    (embark-scope-test--with-stubbed-window-bounds
     (let ((results (embark-scope-collect-visible-instances 'email 'email)))
       (should (= 2 (length results)))))))

(ert-deftest embark-scope/collect-visible-dispatch-org-url-link ()
  "`'org-url-link' dispatcher runs BOTH the URL regex AND the
bracketed-org-link scan -- so a buffer with one raw URL + one
`[[URL][DESC]]' yields THREE hits: regex catches the raw URL +
the URL inside the brackets; bracket scan adds the whole link."
  (with-temp-buffer
    (insert "raw https://a.com and [[https://b.com][Docs]] end")
    (embark-scope-test--with-stubbed-window-bounds
     (let ((results (embark-scope-collect-visible-instances
                     'org-url-link 'org-url-link)))
       (should (= 3 (length results)))))))


;;;; --collect-bounds-by-scan captures nested bounds

(ert-deftest embark-scope/collect-bounds-by-scan-nested-sexps ()
  "Per-position scan captures EVERY nesting level (inner sexps inside
outer ones), unlike the forward-thing walker which skips nested."
  (with-temp-buffer
    (emacs-lisp-mode)
    (insert "(outer (middle (inner)))")
    (let ((results (embark-scope-collect-bounds-by-scan
                    'sexp (point-min) (point-max))))
      ;; outer + middle + inner -- 3 distinct nesting levels.
      (should (>= (length results) 3)))))


;;;; --collect-symbols-of-embark-type

(ert-deftest embark-scope/collect-symbols-by-embark-type ()
  "Walks symbols, keeps those classified as the requested embark type."
  (with-temp-buffer
    (insert "car cdr nilxyz cl-loop")
    (let ((results (embark-scope--collect-symbols-of-embark-type 'function)))
      ;; Each result is (BEG . END); extract the symbol names.
      (let ((names (mapcar (lambda (b)
                             (buffer-substring (car b) (cdr b)))
                           results)))
        (should (member "car" names))
        (should (member "cdr" names))
        (should (member "cl-loop" names))
        (should-not (member "nilxyz" names))))))


;;;; --jump-type-at-point-p is O(1)

(ert-deftest embark-scope/jump-type-at-point-p-cheap ()
  "`--jump-type-at-point-p' is one O(1) probe -- no walking."
  (with-temp-buffer
    (insert "hello world")
    (goto-char 3)
    (should (embark-scope--jump-type-at-point-p 'word))
    (should (embark-scope--jump-type-at-point-p 'sentence))
    ;; A thing not at point: returns nil (or whatever
    ;; bounds-of-thing-at-point returns for it -- which for a
    ;; URL in a non-URL buffer is nil).
    (should-not (embark-scope--jump-type-at-point-p 'url))))


;;;; back-cycle-mode toggle (symmetry with capture-mode test)

(ert-deftest embark-scope/back-cycle-mode-toggle ()
  "Toggling installs/removes binding + two advices."
  (unwind-protect
      (progn
        (embark-scope-back-cycle-mode 1)
        (should (eq (lookup-key embark-general-map (kbd "C-,"))
                    #'embark-scope-back-cycle))
        (should (advice-member-p
                 #'embark-scope--keymap-prompter-back-cycle
                 'embark-keymap-prompter))
        (should (advice-member-p
                 #'embark-scope--reset-prefix-arg-after-rotate
                 'embark--rotate))
        (embark-scope-back-cycle-mode -1)
        (should-not (eq (lookup-key embark-general-map (kbd "C-,"))
                        #'embark-scope-back-cycle))
        (should-not (advice-member-p
                     #'embark-scope--keymap-prompter-back-cycle
                     'embark-keymap-prompter))
        (should-not (advice-member-p
                     #'embark-scope--reset-prefix-arg-after-rotate
                     'embark--rotate)))
    (embark-scope-back-cycle-mode -1)))


;;;; install-default-bindings

(ert-deftest embark-scope/install-default-bindings ()
  "Every binding in `embark-scope-default-bindings' lands in
`embark-general-map'."
  (unwind-protect
      (let ((orig (copy-keymap embark-general-map)))
        (embark-scope-install-default-bindings)
        (dolist (b embark-scope-default-bindings)
          (should (eq (cdr b)
                      (lookup-key embark-general-map (kbd (car b)))))))
    ;; Cleanup: remove bindings we installed.
    (dolist (b embark-scope-default-bindings)
      (define-key embark-general-map (kbd (car b)) nil))))


;;;; deftap-finder macro: gating + clamping

(ert-deftest embark-scope/deftap-finder-gates-on-minibuffer ()
  "Generated finder returns nil in completion-list-mode."
  (eval '(embark-scope-deftap-finder paragraph))
  (with-temp-buffer
    (insert "hello world.\n\nanother paragraph.")
    (goto-char 5)
    (should (consp (embark-scope-target-paragraph-at-point)))
    (setq major-mode 'completion-list-mode)
    (should-not (embark-scope-target-paragraph-at-point))))


;;;; --assign-type-keys fallback path

(ert-deftest embark-scope/assign-type-keys-falls-back-when-name-exhausted ()
  "When every char of a type's name collides, falls through to a-z scan."
  (let ((result (embark-scope--assign-type-keys
                 ;; 'aa' has only 'a'; if 'a' is taken by first type,
                 ;; second's only chars exhaust -> a-z fallback fires.
                 '(a aa))))
    (should (eq 'a (alist-get ?a result)))
    ;; Second symbol gets some other char (b -- next free in a-z).
    (should (eq 'aa (alist-get ?b result)))))


;;;; Nav commands are repeatable embark actions

(ert-deftest embark-scope/repeat-actions-lists-nav-family ()
  "`embark-scope-repeat-actions' covers the whole nav family."
  (dolist (cmd '(embark-scope-nav-next embark-scope-nav-prev
                 embark-scope-nav-beg embark-scope-nav-end))
    (should (memq cmd embark-scope-repeat-actions))))

(ert-deftest embark-scope/nav-registered-as-embark-repeatable ()
  "Registering `embark-scope-repeat-actions' makes embark treat the
nav commands as repeatable (so it stays active after the action)."
  (let ((embark-repeat-actions (copy-sequence embark-repeat-actions)))
    (dolist (cmd embark-scope-repeat-actions)
      (add-to-list 'embark-repeat-actions cmd))
    (should (embark--action-repeatable-p 'embark-scope-nav-next))
    (should (embark--action-repeatable-p 'embark-scope-nav-prev))
    (should (embark--action-repeatable-p 'embark-scope-nav-beg))
    (should (embark--action-repeatable-p 'embark-scope-nav-end))))


(provide 'embark-scope-test)
;;; embark-scope-test.el ends here
