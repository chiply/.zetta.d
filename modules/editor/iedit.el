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
   "j" (** iedit-next-occurrence)
   "k" (** iedit-prev-occurrence)
   "gg" (** iedit-goto-first-occurrence)
   "G" (** iedit-goto-last-occurrence)
   "f" (** iedit-show/hide-unmatched-lines)
   "t" (** iedit-toggle-selection)
   "f" (** iedit-restrict-function)
   "l" (** iedit-restrict-current-line)
   "J" (** iedit-expand-down-to-occurence)
   "K" (** iedit-expand-up-to-occurence )
   "r" (** iedit-replace-occurrences)
   "i" (** zetta-iedit-initiate)
   )

  :hook (use-package--iedit--post-config . zetta-brushup)
  )
;;; iedit.el ends here
