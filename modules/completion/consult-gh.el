;;; consult-gh.el --- Configure consult-gh -*- lexical-binding: t; -*-

(use-package consult-gh
  :if (executable-find "gh")
  :ensure (consult-gh
           :host github
           :repo "armindarvish/consult-gh"
           :files ("*.el")
           )
  :demand t
  :after consult nerd-icons

  :config
  ;;add your main GitHub account (replace "armindarvish" with your user or org)

  ;;use "gh org list" to get a list of all your organizations and adds them to default list
  (defun zetta-consult-gh-orgs ()
    (delete-dups (append consult-gh-favorite-orgs-list (remove "" (split-string (or (consult-gh--command-to-string "org" "list") "") "\n")))))

  (setq consult-gh--known-orgs-list (zetta-consult-gh-orgs))
  (setq consult-gh-favorite-orgs-list (zetta-consult-gh-orgs))

  (require 'consult-gh-nerd-icons)
  (consult-gh-nerd-icons-mode +1)

  ;; set the default folder for cloning repositories, By default Consult-GH will confirm this before cloning
  (setq consult-gh-default-clone-directory "~/source_code/")
  (require 'consult-gh-transient)

  ;; NOTE matching consult-omni
  (setq consult-gh-pr-maxnum 10)
  ;; when doing something comprehensive like org wide searc can
  ;; override as 1000, can have issues exceding API limit
  (setq consult-gh-code-maxnum 10)
  ;; matching consult-omni
  (setq consult-gh-repo-maxnum 10)
  (setq consult-gh-issue-maxnum 10)
  (setq consult-gh-comments-maxnum 10)
  (setq consult-gh-dashboard-maxnum 10)

  (setq consult-gh-show-preview t)
  (setq consult-gh-preview-key "C-=")

  ;; NOTE -- doesn't work
  (consult-customize
   consult-gh-search-repos
   consult-gh-search-code
   consult-gh-search-prs
   consult-gh-search-issues
   :preview-key "C-="
   )

  ;; Fix upstream bug: consult-gh--get-split-style-character calls
  ;; (char-to-string nil) when the split style has no :initial key
  ;; (e.g. comma style only has :separator).  Use :override advice
  ;; rather than `defun' so the fix survives async native compilation
  ;; — the .eln loads after :config runs and would otherwise restore
  ;; the broken original via defalias (advice persists across that).
  (advice-add 'consult-gh--get-split-style-character :override
              (lambda (&optional style)
                (let* ((style (or style consult-async-split-style 'none))
                       (char (or (plist-get (alist-get style consult-async-split-styles-alist) :initial)
                                 (plist-get (alist-get style consult-async-split-styles-alist) :separator))))
                  (if char (char-to-string char) ""))))
  )

(use-package consult-gh-embark
  :if (executable-find "gh")
  :ensure nil
  :after consult-gh
  :config
  (consult-gh-embark-mode +1))

(use-package consult-gh-forge
  :if (executable-find "gh")
  :ensure nil
  :after consult-gh
  :config
  (consult-gh-forge-mode +1))
;;; consult-gh.el ends here
