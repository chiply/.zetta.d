;;; security.el --- Configure security settings -*- lexical-binding: t; -*-

;; from the following article https://glyph.twistedmatrix.com/2015/11/editor-malware.html
;; note this code was copy pasted from https://gitlab.com/buildfunthings/emacs-config/blob/master/loader.org
(require 'cl)
(setq tls-checktrust t)

(setq python (or (executable-find "py.exe")
                 (executable-find "python")
                 ))

;; Without a python on PATH the `concat' below would run " -m certifi"
;; as a shell command and record its error text as the trust file --
;; a garbage entry that then breaks every TLS connection.  Leave the
;; system defaults alone in that case.
(when python
  (let ((trustfile
         (replace-regexp-in-string
          "\\\\" "/"
          (replace-regexp-in-string
           "\n" ""
           (shell-command-to-string (concat python " -m certifi"))))))
    (setq tls-program
          (list
           (format "gnutls-cli%s --x509cafile %s -p %%p %%h"
                   (if (eq window-system 'w32) ".exe" "") trustfile)))
    (setq gnutls-verify-error t)
    (setq gnutls-trustfiles (list trustfile))))
;;; security.el ends here
