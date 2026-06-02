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
   "j" (repeatable-wrap iedit-next-occurrence)
   "k" (repeatable-wrap iedit-prev-occurrence)
   "gg" (repeatable-wrap iedit-goto-first-occurrence)
   "G" (repeatable-wrap iedit-goto-last-occurrence)
   "f" (repeatable-wrap iedit-show/hide-unmatched-lines)
   "t" (repeatable-wrap iedit-toggle-selection)
   "f" (repeatable-wrap iedit-restrict-function)
   "l" (repeatable-wrap iedit-restrict-current-line)
   "J" (repeatable-wrap iedit-expand-down-to-occurence)
   "K" (repeatable-wrap iedit-expand-up-to-occurence )
   "r" (repeatable-wrap iedit-replace-occurrences)
   "i" (repeatable-wrap zetta-iedit-initiate)
   )

  :hook (use-package--iedit--post-config . brushup)
  )
;;; iedit.el ends here
