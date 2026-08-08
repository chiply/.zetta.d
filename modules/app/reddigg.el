;;; reddigg.el --- Configure reddigg -*- lexical-binding: t; -*-

;; Org-based Reddit reader, trialed 2026-08-03 alongside md4rd (see
;; modules/app/md4rd.el) while deciding which to keep.
;;
;; Reddit 403-blocks the unauthenticated endpoints reddigg fetches
;; (old.reddit.com/*.json, api.reddit.com), so every request — all
;; funneled through reddigg--promise-json — is rewritten to
;; oauth.reddit.com with the bearer token machinery from the md4rd
;; module (loads before this one; both under modules/app/).

(use-package reddigg
  :ensure (reddigg :host github :repo "thanhvg/emacs-reddigg")
  :commands (reddigg-view-main reddigg-view-sub reddigg-view-comments)
  :config
  ;; Same sub list as md4rd for a fair comparison.
  (setq reddigg-subs md4rd-subs-active)

  (defun zetta-reddigg--oauth-json (orig url)
    "Call ORIG with URL rewritten to oauth.reddit.com plus bearer auth.
The dynamic binding works because promise-new runs its executor —
and thus url-retrieve — synchronously inside this extent."
    (when (fboundp 'zetta-md4rd--ensure-token)
      (zetta-md4rd--ensure-token))
    (let ((url-request-extra-headers
           `(("User-Agent" . ,zetta-md4rd-user-agent)
             ("Authorization" . ,(concat "bearer " md4rd--oauth-access-token)))))
      (funcall orig (replace-regexp-in-string
                     "\\`https://\\(?:old\\.\\|www\\.\\|api\\.\\)?reddit\\.com"
                     "https://oauth.reddit.com" url))))
  (advice-add 'reddigg--promise-json :around #'zetta-reddigg--oauth-json))

;;; reddigg.el ends here
