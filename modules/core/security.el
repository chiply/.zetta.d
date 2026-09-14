;;; security.el --- TLS trust -*- lexical-binding: t; -*-

;; Emacs's GnuTLS verifies server certificates against `gnutls-trustfiles',
;; a list of well-known system bundle paths of which the missing ones are
;; ignored -- so the system trust store is the default, and it already
;; holds the macOS roots and whatever a corporate MDM adds.  Two additions
;; on top of it:
;;
;; - python's certifi bundle, when a `python' on PATH has certifi
;;   installed AND what it prints is an existing file.  The previous
;;   version of this file captured stderr with stdout, so with python
;;   present and certifi absent the interpreter's error text became the
;;   only trust file and every TLS connection failed; and making certifi
;;   the ONLY trust broke behind a TLS-intercepting proxy whose root is in
;;   the system store but not in certifi (work-security-audit.org S6).
;; - `zetta-extra-trust-files', for such a corporate root: set it in
;;   ~/.zetta.el before the modules load.
;;
;; `gnutls-verify-error' is t: a certificate that does not verify is an
;; error, not a prompt.  The rationale is the article this file began
;; from, https://glyph.twistedmatrix.com/2015/11/editor-malware.html.

(require 'gnutls)

(defvar zetta-extra-trust-files nil
  "Additional CA bundle files (PEM) appended to `gnutls-trustfiles'.
Set in ~/.zetta.el or ~/.private.el, for example a corporate root
behind a TLS-intercepting proxy.  Entries that are not existing files
are ignored.")

(defun zetta-certifi-trust-file ()
  "Path of python's certifi bundle, or nil.
Nil when no `python' is on PATH, when certifi is not installed (the
interpreter's stderr is discarded, never captured), or when what python
prints is not an existing regular file."
  (let ((python (or (executable-find "py.exe") (executable-find "python"))))
    (when python
      (let ((out (with-temp-buffer
                   (when (eq 0 (ignore-errors
                                 (call-process python nil (list t nil) nil
                                               "-m" "certifi")))
                     (string-trim (buffer-string))))))
        (when (and out (not (string-empty-p out)))
          (let ((path (replace-regexp-in-string "\\\\" "/" out)))
            (when (file-regular-p path) path)))))))

(defun zetta-tls-trust-files ()
  "The trust list: Emacs's system bundles, then certifi, then the extras.
Wildcard entries are expanded and only existing regular files are kept,
so the result is either empty or a list of files that exist."
  (let ((candidates
         (append (if (functionp gnutls-trustfiles)
                     (funcall gnutls-trustfiles)
                   gnutls-trustfiles)
                 (let ((certifi (zetta-certifi-trust-file)))
                   (and certifi (list certifi)))
                 (mapcar #'expand-file-name zetta-extra-trust-files)))
        result)
    (dolist (candidate candidates)
      (dolist (file (if (string-match-p "[*?[]" candidate)
                        (file-expand-wildcards candidate)
                      (list candidate)))
        (when (and (file-regular-p file) (not (member file result)))
          (push file result))))
    (nreverse result)))

;; An empty result means none of the known bundles exists on this box:
;; keep Emacs's own list rather than trust nothing at all.
(let ((files (zetta-tls-trust-files)))
  (when files
    (setq gnutls-trustfiles files)))

(setq gnutls-verify-error t)
;;; security.el ends here
