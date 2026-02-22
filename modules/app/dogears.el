;;; dogears.el --- Configure dogears -*- lexical-binding: t; -*-

(use-package dogears
  :config
  ;; function
  (setq dogears-functions
        '(
          ;; NOTHING -- eg only the manual dogears
          find-file
          consult-buffer
          switch-buffer
          project-find-file
          consult-project-extra-find
          ;;ace-window
          ;;tab-line-switch-to-next-tab
          ;;tab-line-switch-to-prev-tab
          evil-search-forward
          evil-goto-definition
          ;;windmove-up
          ;;windmove-down
          ;;windmove-left
          ;;windmove-right
          )
        ;; turn off the idle timer
        dogears-idle nil
        )

  (dogears-mode 1)
  (add-to-list 'desktop-globals-to-save 'dogears-list)

  :display
  ;;(zetta-side "^\\*Dogears List*" 'right -11 0.20 0.25)

  :general
  (
   :keymaps 'override
   "s-!" 'dogears-remember
   "C-s-h" 'pop-global-mark
   )

  :hook (dogears-list-mode . (lambda () (text-scale-set 0))) ;; to appease tablist mode
  )
;;; dogears.el ends here
