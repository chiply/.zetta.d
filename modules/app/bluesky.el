;;; bluesky.el --- Configure bluesky -*- lexical-binding: t; -*-

;; ahyatt/emacs-bluesky: timeline, threads, posting, replies.
;;
;; Auth: M-x bluesky looks up auth-source for `bluesky-default-host'
;; (bsky.social) with the handle as user and a Bluesky app password
;; (bsky.app → Settings → App Passwords) as secret.  Served by the
;; 1Password auth-source backend (init.el) via the guarded entry in
;; ~/.private.el — fields handle/app-password on op://Dev/Bluesky.

(use-package bluesky
  :ensure (bluesky :host github :repo "ahyatt/emacs-bluesky")
  :commands (bluesky))

;;; bluesky.el ends here
