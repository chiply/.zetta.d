;;; org-other-agenda.el --- Board-style agenda views -*- lexical-binding: t; -*-

;; Board-style views over the same `org-agenda-files', re-laid out with
;; TextUI.  It reads Org's own hidden agenda buffer and forwards editing
;; keys to the native `org-agenda-*' commands, so state changes, logging
;; and hooks all apply: there is no second write path to worry about,
;; which is what makes it worth having at all.
;;
;; `org-other-agenda-series' takes the same shape as
;; `org-agenda-custom-commands', so the three views configured in
;; ../org-agenda.el are reused rather than restated -- change them there
;; and the board follows.
;;
;; TWO PACKAGES FROM GITHUB.  TextUI is not on MELPA, so both are fetched
;; by recipe; pin them in `elpaca-lock.el' so a cold CI build gets the same
;; commits.
;;
;; ON SKIPPING THE VERSION CHECK.  org-other-agenda declares
;; `(embark "1.2")' and this config pins embark 1.1, so elpaca refuses the
;; build outright: "Outdated dependency. embark version 1.1 installed, 1.2
;; required".  Upgrading embark is not a small change here -- embark-consult,
;; embark-vc, consult-gh-embark and the in-tree `embark-scope' package all
;; ride on it, and the pin is deliberate.
;;
;; So the floor is skipped rather than met, on evidence: every embark symbol
;; this package references -- `embark-keymap-alist', `embark-target-finders',
;; `embark-org-heading-map', `embark-around-action-hooks',
;; `embark-post-action-hooks' -- is bound in the installed 1.1.  Nothing it
;; names is missing.  That is not proof of behavioural compatibility, so if
;; the board misbehaves around embark actions, this comment is the first
;; place to look; the honest fix then is to upgrade embark, not to widen the
;; skip.

(use-package textui
  :ensure (textui :host github :repo "yibie/textui"))

(use-package org-other-agenda
  :ensure (org-other-agenda :host github :repo "yibie/org-other-agenda"
                            ;; see "ON SKIPPING THE VERSION CHECK" above
                            :build (:not elpaca-check-version))
  :after (org textui embark)
  :commands (org-other-agenda)
  :config
  ;; `org-other-agenda-series' is the BLOCK LIST, not the command list --
  ;; its own default is ((agenda "" ...) (alltodo "")).  The docstring says
  ;; it "has the shape of the command list in `org-agenda-custom-commands'",
  ;; which reads as though the whole alist would do; it will not.  An entry
  ;; there is (KEY DESCRIPTION BLOCKS), so handing the alist over feeds
  ;; `org-agenda-run-series' the string "d" where a block belongs.
  ;;
  ;; So take the blocks out of the Day command defined in org-agenda.el.
  ;; That is the reuse the plan wanted: change the day view once and the
  ;; board follows, rather than maintaining two copies of it.
  (setq org-other-agenda-series
        (or (nth 2 (assoc "d" org-agenda-custom-commands))
            '((agenda "" ((org-agenda-span 'day)))
              (alltodo "")))))

(general-define-key
 :keymaps 'menu-org-map
 "b" 'org-other-agenda)
;;; org-other-agenda.el ends here
