(use-package forge
  ;; NOTE fixing a presumably temporary issue where elpaca tries to pull from main, which specifies a non-existent tags for magit and ghub
  ;;:ensure (forge :type git :host github :repo "magit/forge" :tag "v0.4.4")
  :after (magit ghub)
  ;; notes: need to set up github username locally for each repo
  ;; with this command
  ;; git config --global github.user USERNAME
  ;; git config --local github.user USERNAME
  :init
  (setq auth-sources '("~/.authinfo"))
  ;;(zetta-side "\\forge-topic-mode" 'right 2)
  :general
  (
   :keymaps 'magit-status-mode-map
   "P" 'forge-pull))
