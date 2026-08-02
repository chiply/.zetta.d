;;; mu4e-dashboard.el --- Configure mu4e-dashboard -*- lexical-binding: t; -*-

;; Rougier's org-based mail dashboard: an org file of [[mu:query]]
;; links with live counts, activated by `mu4e-dashboard'.  The
;; dashboard file itself is personal (it names maildirs/addresses), so
;; it lives outside this repo at `mu4e-dashboard-file'.

;; mu4e comes from the homebrew site-lisp, not an elpaca menu (same
;; treatment as nano-mu4e.el; add-to-list is idempotent).
(add-to-list 'elpaca-ignored-dependencies 'mu4e)

(use-package mu4e-dashboard
  :if (executable-find "mu")
  :ensure (mu4e-dashboard :host github :repo "rougier/mu4e-dashboard")
  :after mu4e
  :config
  (setq mu4e-dashboard-file "~/.mu4e-dashboard.org")
  (general-define-key
   :keymaps 'launch-map
   "M" 'mu4e-dashboard))

;;; mu4e-dashboard.el ends here
