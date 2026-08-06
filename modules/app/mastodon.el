;;; mastodon.el --- Configure mastodon -*- lexical-binding: t; -*-

(use-package mastodon
  ;;:ensure (mastodon :host codeberg :repo "martianh/mastodon.el")
  :config
  ;; Set `mastodon-instance-url' and `mastodon-active-user' in ~/.private.el

  ;; Org backlinks (capture %a) from mastodon buffers: the toot at
  ;; point, boost-aware (the boosted toot's own URL, not the boost),
  ;; described as @author + a text snippet of the content.  https
  ;; links, same policy as the elfeed/md4rd backends.
  (require 'dom)
  (with-eval-after-load 'ol
    (defun zetta-org-mastodon-store-link (&optional _interactive)
      "Store the toot at point as an org link."
      (when (derived-mode-p 'mastodon-mode)
        (when-let* ((toot (mastodon-tl--property 'item-json :no-move))
                    (url (mastodon-tl--field 'url toot)))
          (let* ((acct (alist-get 'acct (mastodon-tl--field 'account toot)))
                 (content (mastodon-tl--field 'content toot))
                 (snippet
                  (when (and content (fboundp 'libxml-parse-html-region))
                    (with-temp-buffer
                      (insert content)
                      (string-trim
                       (replace-regexp-in-string
                        "[ \n]+" " "
                        (or (dom-texts (libxml-parse-html-region
                                        (point-min) (point-max)))
                            ""))))))
                 (snippet (and snippet (not (string-empty-p snippet))
                               (truncate-string-to-width snippet 60 nil nil "…"))))
            (org-link-store-props
             :type "https" :link url
             :description (if snippet
                              (format "@%s: %s" acct snippet)
                            (format "@%s on Mastodon" acct)))))))
    (org-link-set-parameters "mastodon-toot"
                             :store #'zetta-org-mastodon-store-link)))
;;; mastodon.el ends here
