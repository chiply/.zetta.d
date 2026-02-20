;;; -*- lexical-binding: t; -*-

(require 'json)
(require 'url)

(require 'spot-util)
(require 'spot-var)
(require 'spot-generic-query)


(defun spot-authorize ()
  "Obtain access_ and refresh_ tokens for user account."
  (interactive)
  ;; Copy auth URL to kill ring (to respect terminal emacs users)
  (browse-url spot-auth-url-full)
  (setq spot-auth-code (read-string "Enter code from URL: "))
  (spot-request-async
   :method "POST"
   :url spot-token-url
   :q-params (concat "?grant_type=" "authorization_code"
                     "&redirect_uri=" spot-redirect-uri
                     "&code=" spot-auth-code)
   :callback (lambda (response)
               (let ((json (json-read-from-string response)))
                 (setq
                  spot-access-token (alist-get-chain '(access_token) json)
                  spot-refresh-token (alist-get-chain '(refresh_token) json)))
               (message "Refreshed spot access token and refresh token"))
   :extra-headers `(("Content-Type" . "application/x-www-form-urlencoded")
                    ("Content-Length" . "0")
                    ("Authorization" . ,(concat "Basic " spot-b64-id-secret)))))


(defun spot-refresh ()
  "Obtain access_ and refresh_ tokens for user account."
  (interactive)
  (spot-request-async
   :method "POST"
   :url spot-token-url
   :q-params (concat "?grant_type=" "refresh_token"
                     "&refresh_token=" spot-refresh-token)
   :callback (lambda (response)
               (setq
                spot-access-token
                (alist-get-chain '(access_token) (json-read-from-string response)))
               (message "Refreshed spot access token"))
   :extra-headers `(("Content-Type" . "application/x-www-form-urlencoded")
                    ("Content-Length" . "0")
                    ("Authorization" . ,(concat "Basic " spot-b64-id-secret)))))



(provide 'spot-auth)
