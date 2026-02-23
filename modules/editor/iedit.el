;;; iedit.el --- Configure iedit -*- lexical-binding: t; -*-

(use-package iedit
  :init
  (defun zetta-iedit-initiate ()
    (interactive)
    (when (not (and (boundp 'iedit-mode) iedit-mode))
      (iedit-mode)))

  (defun zetta-iedit-terminate ()
    (interactive)
    (when (and (boundp 'iedit-mode) iedit-mode)
      (iedit-mode)))

  :config
  (setq iedit-overlay-priority 100)

  ;;:brushup
  (add-to-list 'brushup-styles
               '(set-face-attribute 'iedit-occurrence nil
                                    :inherit nil
                                    :background (face-background 'highlight)))

  :general
  (
   :keymaps 'menu-iedit-map
   "," 'zetta-iedit-terminate
   "j" (repeatable-lite-wrap iedit-next-occurrence)
   "k" (repeatable-lite-wrap iedit-prev-occurrence)
   "gg" (repeatable-lite-wrap iedit-goto-first-occurrence)
   "G" (repeatable-lite-wrap iedit-goto-last-occurrence)
   "f" (repeatable-lite-wrap iedit-show/hide-unmatched-lines)
   "t" (repeatable-lite-wrap iedit-toggle-selection)
   "f" (repeatable-lite-wrap iedit-restrict-function)
   "l" (repeatable-lite-wrap iedit-restrict-current-line)
   "J" (repeatable-lite-wrap iedit-expand-down-to-occurence)
   "K" (repeatable-lite-wrap iedit-expand-up-to-occurence )
   "r" (repeatable-lite-wrap iedit-replace-occurrences)
   "i" (repeatable-lite-wrap zetta-iedit-initiate)
   )

  :hook (use-package--iedit--post-config . zetta-brushup)
  )
;;; iedit.el ends here
