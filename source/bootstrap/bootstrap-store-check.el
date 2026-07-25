;;; bootstrap-store-check.el --- Warn on Emacs/bytecode version skew -*- lexical-binding: t; -*-

;; A prebuilt package store is byte-compiled by CI's Emacs.  .elc is
;; only guaranteed compatible when the running Emacs is built from the
;; same Lisp sources -- true for identical released versions, NOT for
;; two pretest builds that share a version number: a 31.0.50 master
;; snapshot and a 31.0.90 release-branch build differ in core macros
;; and setters (measured 2026-07-25: a store compiled by 31.0.90
;; called the named setter function (setf image-property), void on a
;; 31.0.50 build, so every all-the-icons SVG icon errored).
;; bin/zetta refuses to install a store whose manifest doesn't match
;; `emacs-version' exactly; this startup check catches the other
;; drift direction -- the user switching Emacs over an installed
;; store -- which no install-time gate can see.

(defun zetta-store-check ()
  "Warn when the running Emacs differs from the one that compiled the store.
Reads the manifest that bin/zetta keeps alongside an installed
prebuilt store; silent when no manifest exists (source-built
stores compile against the local Emacs by construction)."
  (let ((manifest (expand-file-name "elpaca/elpaca-manifest.json"
                                    user-emacs-directory)))
    (when (file-readable-p manifest)
      (with-temp-buffer
        (insert-file-contents manifest)
        (when (re-search-forward "\"emacs\": *\"\\([^\"]+\\)\"" nil t)
          (let ((builder (match-string 1)))
            (unless (equal builder emacs-version)
              (display-warning
               'zetta
               (format (concat "This Emacs is %s, but the installed package "
                               "store was byte-compiled by Emacs %s.  "
                               "Mismatched bytecode can call functions this "
                               "Emacs lacks (void-function errors).  Fix: run "
                               "Emacs %s, or rebuild from source: "
                               "rm -rf %selpaca && bin/zetta install")
                       emacs-version builder builder user-emacs-directory)
               :warning))))))))

;; Batch runs (zetta install/sync, CI) are covered by the install-time
;; gate and would only add noise here.
(unless noninteractive
  (add-hook 'emacs-startup-hook #'zetta-store-check))

(provide 'bootstrap-store-check)
;;; bootstrap-store-check.el ends here
