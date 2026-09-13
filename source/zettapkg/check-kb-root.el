;;; check-kb-root.el --- No "~/kb" literal outside docstrings and comments -*- lexical-binding: t; -*-

;; WP-Z9's acceptance test.  The knowledge-base root is ONE variable,
;; `zetta-kb-dir' (source/bootstrap/bootstrap-modules.el), and every kb
;; path in modules/ and source/zettapkg/ derives from it.  This reads
;; every .el under both trees as Lisp and reports each string literal
;; containing "~/kb" that is not a docstring, so a literal that creeps
;; back fails run-tests.sh.  Allowed, and recognised structurally: the
;; standalone packages' fallback `(or (bound-and-true-p zetta-kb-dir)
;; "~/kb/")', because they must load under emacs -Q for their tests,
;; where the config's variable is unbound.
;;
;;   emacs -Q --batch -l source/zettapkg/check-kb-root.el
;;
;; Exit 0 when nothing is found, 1 otherwise.  Comments are not read.

(require 'cl-lib)

(defvar check-kb-root-skip
  '("source/zettapkg/smoke-modules.el" "source/zettapkg/check-kb-root.el")
  "Test harnesses: they stub the root on purpose.")

(defvar check-kb-root--hits nil)

(defconst check-kb-root-fallback '(or (bound-and-true-p zetta-kb-dir) "~/kb/")
  "The one allowed literal: a standalone package's fallback for the root.")

(defun check-kb-root--scan (form file)
  "Collect every non-docstring string in FORM that mentions ~/kb."
  (cond
   ((stringp form)
    (when (string-match-p "~/kb" form)
      (push (cons file form) check-kb-root--hits)))
   ((vectorp form)
    (mapc (lambda (x) (check-kb-root--scan x file)) form))
   ((not (consp form)) nil)
   ((equal form check-kb-root-fallback) nil)
   ((not (proper-list-p form))
    (while (consp form)
      (check-kb-root--scan (car form) file)
      (setq form (cdr form)))
    (check-kb-root--scan form file))
   ;; (defvar NAME [VALUE [DOC]]) and friends: skip DOC.
   ((memq (car form) '(defvar defcustom defconst defvar-local))
    (check-kb-root--scan (nth 2 form) file)
    (let ((rest (nthcdr 3 form)))
      (when (stringp (car rest)) (setq rest (cdr rest)))
      (check-kb-root--scan rest file)))
   ;; (defun NAME ARGS [DOC] BODY...)
   ((memq (car form) '(defun defmacro defsubst cl-defun cl-defmacro))
    (let ((body (nthcdr 3 form)))
      (when (and (stringp (car body)) (cdr body)) (setq body (cdr body)))
      (check-kb-root--scan body file)))
   ;; (define-minor-mode NAME DOC ...) / (define-derived-mode NAME PARENT NAME DOC ...)
   ((eq (car form) 'define-minor-mode)
    (check-kb-root--scan (nthcdr 3 form) file))
   ((eq (car form) 'define-derived-mode)
    (check-kb-root--scan (nthcdr 5 form) file))
   (t (dolist (x form) (check-kb-root--scan x file)))))

(defun check-kb-root--file (file)
  (with-temp-buffer
    (insert-file-contents file)
    (goto-char (point-min))
    (condition-case err
        (while t
          (check-kb-root--scan (read (current-buffer)) file))
      (end-of-file nil)
      (error (push (cons file (format "UNREADABLE: %S" err)) check-kb-root--hits)))))

(let* ((root (file-name-as-directory (expand-file-name default-directory)))
       (files (cl-remove-if
               (lambda (f)
                 (or (string-match-p "/test/" f)
                     (member (file-relative-name f root) check-kb-root-skip)))
               (append (directory-files-recursively (concat root "modules") "\\.el\\'")
                       (directory-files-recursively (concat root "source/zettapkg") "\\.el\\'")))))
  (dolist (f files) (check-kb-root--file f))
  (princ (format "check-kb-root: %d files read, %d code literal(s) mentioning ~/kb\n"
                 (length files) (length check-kb-root--hits)))
  (dolist (hit (nreverse check-kb-root--hits))
    (princ (format "  %s: %S\n" (file-relative-name (car hit) root) (cdr hit))))
  (kill-emacs (if check-kb-root--hits 1 0)))
;;; check-kb-root.el ends here
