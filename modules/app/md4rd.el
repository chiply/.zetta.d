;;; md4rd.el --- Configure md4rd -*- lexical-binding: t; -*-

(use-package md4rd
  :config
  (defun md4rd-load-comments-from-url (url)
    "Load and display Reddit comments from URL in md4rd format.
URL should be a Reddit permalink or comments URL."
    (interactive "sReddit URL: ")
    (let ((json-url (md4rd--convert-to-json-url url)))
      (when json-url
        (message "Fetching comments from: %s" json-url)
        (md4rd--fetch-comments json-url))))

  (defun md4rd--convert-to-json-url (url)
    "Convert a Reddit URL to its JSON API endpoint."
    (cond
     ;; Already a JSON URL
     ((string-match-p "\\.json$" url) url)

     ;; Reddit permalink or comments URL
     ((string-match "reddit\\.com/r/[^/]+/comments/[^/?]+" url)
      (let ((clean-url (replace-regexp-in-string "\\?.*" "" url)))
        (if (string-suffix-p "/" clean-url)
            (concat clean-url ".json")
          (concat clean-url "/.json"))))

     ;; Old reddit format
     ((string-match "old\\.reddit\\.com" url)
      (md4rd--convert-to-json-url (replace-regexp-in-string "old\\." "" url)))

     ;; Mobile reddit format
     ((string-match "m\\.reddit\\.com" url)
      (md4rd--convert-to-json-url (replace-regexp-in-string "m\\." "" url)))

     ;; www.reddit format
     ((string-match "www\\.reddit\\.com" url)
      (md4rd--convert-to-json-url (replace-regexp-in-string "www\\." "" url)))

     (t
      (message "Invalid Reddit URL format: %s" url)
      nil)))

  ;; For elfeed integration
  (defun md4rd-elfeed-show-reddit-comments ()
    "Show Reddit comments for the current elfeed entry if it's a Reddit URL."
    (interactive)
    (when (bound-and-true-p elfeed-show-entry)
      (let ((url (elfeed-entry-link elfeed-show-entry)))
        (if (string-match-p "reddit\\.com" url)
            (md4rd-load-comments-from-url url)
          (message "Current entry is not a Reddit URL")))))

  ;; Optional: Add to elfeed-show-mode-map if you want a keybinding
  (general-unbind :keymaps 'elfeed-show-mode-map "R")
  (general-define-key :keymaps 'elfeed-show-mode-map :states 'normal "R" 'md4rd-elfeed-show-reddit-comments)

  ;; --- OAuth reads --------------------------------------------------
  ;; Reddit 403-blocks the unauthenticated *.json endpoints md4rd uses
  ;; for ALL reads (any User-Agent; curl and url.el alike — verified
  ;; 2026-08-03), so listings/comments silently render nothing.  Route
  ;; reads through oauth.reddit.com with the bearer token instead.
  ;; Needs a token carrying the `read' scope: stock md4rd only asks for
  ;; vote,submit, so widen the authorize URL for future logins.
  (setq md4rd--oauth-url
        (replace-regexp-in-string "scope=vote,submit" "scope=read,vote,submit"
                                  md4rd--oauth-url))

  (defvar zetta-md4rd-user-agent "emacs:md4rd:0.3.1 (personal reader)"
    "Descriptive User-Agent, per Reddit API rules.")

  (defvar zetta-md4rd--token-refreshed-at 0
    "`float-time' of the last successful access-token refresh.")

  (defun zetta-md4rd--refresh-token-sync ()
    "Refresh the OAuth access token, blocking.  Return it, or nil."
    (let* ((url-request-method "POST")
           (url-request-data (format "grant_type=refresh_token&refresh_token=%s"
                                     md4rd--oauth-refresh-token))
           (url-request-extra-headers
            `(("Content-Type" . "application/x-www-form-urlencoded")
              ("User-Agent" . ,zetta-md4rd-user-agent)
              ("Authorization" . ,(concat "Basic "
                                          (base64-encode-string
                                           (format "%s:" md4rd--oauth-client-id) t)))))
           (buf (ignore-errors
                  (url-retrieve-synchronously
                   "https://www.reddit.com/api/v1/access_token" t nil 10))))
      (when buf
        (with-current-buffer buf
          (when-let* ((json (ignore-errors
                              (json-read-from-string
                               (buffer-substring (1+ url-http-end-of-headers)
                                                 (point-max)))))
                      (token (alist-get 'access_token json)))
            (setq md4rd--oauth-access-token token
                  zetta-md4rd--token-refreshed-at (float-time))
            token)))))

  (defun zetta-md4rd--ensure-token ()
    "Refresh the access token when older than 50 min (1 h lifetime)."
    (when (> (- (float-time) zetta-md4rd--token-refreshed-at) 3000)
      (or (zetta-md4rd--refresh-token-sync)
          (message "md4rd: token refresh failed — run M-x md4rd-login"))))

  (defun zetta-md4rd--oauth-headers ()
    "Bearer auth headers for authenticated Reddit reads."
    `(("User-Agent" . ,zetta-md4rd-user-agent)
      ("Authorization" . ,(concat "bearer " md4rd--oauth-access-token))))

  (defun zetta-md4rd--fetch-sub (sub)
    "Fetch SUB's hot listing via the authenticated API."
    (zetta-md4rd--ensure-token)
    (request (format "https://oauth.reddit.com/r/%s/hot" sub)
             :complete (cl-function
                        (lambda (&rest data &allow-other-keys)
                          (apply #'md4rd--fetch-sub-callback sub data)))
             :sync nil
             :parser #'json-read
             :headers (zetta-md4rd--oauth-headers)))

  (defun zetta-md4rd--fetch-comments (comment-url)
    "Fetch COMMENT-URL via the authenticated API."
    (zetta-md4rd--ensure-token)
    (request (replace-regexp-in-string
              "\\`https?://\\(www\\.\\)?reddit\\.com" "https://oauth.reddit.com"
              comment-url)
             :complete #'md4rd--fetch-comments-callback
             :sync nil
             :parser #'json-read
             :headers (zetta-md4rd--oauth-headers)))

  (advice-add 'md4rd--fetch-sub :override #'zetta-md4rd--fetch-sub)
  (advice-add 'md4rd--fetch-comments :override #'zetta-md4rd--fetch-comments)

  ;; needed to use this to set things up https://not-an-aardvark.github.io/reddit-oauth-helper/
  (setq
   md4rd-subs-active
   '(lisp+Common_Lisp emacs prolog dataisbeautiful archlinux aws
     datascience Guitar healthIT jazzguitar jazztheory KnowledgeGraph
     javascript MachineLearning planetemacs Python stats SQL
     programming vim Watches webdev eink))

  (general-unbind :keymaps 'md4rd-mode :states 'normal "q")
  (general-define-key :keymaps 'md4rd-mode :states 'normal "q" 'kill-current-buffer)

  ;; fixing face
  (defface md4rd--greentext-face
    '((((type graphic) (background dark))
       :background unspecified :foreground "#90a959")
      (((type graphic) (background light))
       :background unspecified :foreground "#90a959")
      (t :background unspecified :foreground "#90a959"))
    "Face for rendering greentexts."
    :group 'md4rd)

  ;; NOTE buggy
  ;;(add-hook 'md4rd-mode-hook 'md4rd-indent-all-the-lines)
  )
;;; md4rd.el ends here
