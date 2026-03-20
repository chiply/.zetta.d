;;; window.el --- Configure window management -*- lexical-binding: t; -*-

(require 'window)

;; NOTE this makes them look almost invisible, better than disabling
;; the mode because when disabled there's still a black liine right
;; divider for some reason
(window-divider-mode -1)
(setq window-divider-default-places t)
(setq window-divider-default-bottom-width 1
      window-divider-default-right-width 1)
(window-divider-mode +1)

(add-to-list 'brushup-styles
             '(progn
                (set-face-attribute 'window-divider nil
                                    :background brushup-bg
                                    :foreground brushup-bg
                                    )))

(defun zetta-window-divider-mode ()
  (interactive)
  (call-interactively 'window-divider-mode))

(defun zetta-scroll-bar-mode ()
  (interactive)
  (if (get-scroll-bar-mode) (set-scroll-bar-mode nil) (set-scroll-bar-mode 'left)))

(defun zetta-shrink-window-h-1 () (interactive) (shrink-window-horizontally 1))
(defun zetta-shrink-window-h-2 () (interactive) (shrink-window-horizontally 2))
(defun zetta-shrink-window-h-4 () (interactive) (shrink-window-horizontally 4))
(defun zetta-enlarge-window-h-1 () (interactive) (enlarge-window-horizontally 1))
(defun zetta-enlarge-window-h-2 () (interactive) (enlarge-window-horizontally 2))
(defun zetta-enlarge-window-h-4 () (interactive) (enlarge-window-horizontally 4))
(defun zetta-shrink-window-v-1 () (interactive) (shrink-window 1))
(defun zetta-shrink-window-v-2 () (interactive) (shrink-window 2))
(defun zetta-shrink-window-v-4 () (interactive) (shrink-window 4))
(defun zetta-enlarge-window-v-1 () (interactive) (enlarge-window 1))
(defun zetta-enlarge-window-v-2 () (interactive) (enlarge-window 2))
(defun zetta-enlarge-window-v-4 () (interactive) (enlarge-window 4))

(general-define-key
 :keymaps 'menu-window-map
 "D" (repeatable-lite-wrap delete-window)
 "C-S-d" (repeatable-lite-wrap delete-other-windows)
 "C-S-S" (repeatable-lite-wrap window-toggle-side-windows)
 "C-S-b h" (repeatable-lite-wrap horizontal-scroll-bar-mode)
 "mm" (repeatable-lite-wrap balance-windows)
 "mk" (repeatable-lite-wrap minimize-window)
 "mj" (repeatable-lite-wrap maximize-window)
 "C-v" (repeatable-lite-wrap visual-line-mode)
 "C-t" (repeatable-lite-wrap toggle-truncate-lines)
 "C-t" (repeatable-lite-wrap toggle-truncate-lines)
 "C-w" (repeatable-lite-wrap toggle-word-wrap)
 "s" (repeatable-lite-wrap zetta-state-hydra/body)
 "f" (repeatable-lite-wrap consult-project-extra-find)
 "F" (repeatable-lite-wrap find-file)
 "x" (repeatable-lite-wrap execute-extended-command)
 "u" (repeatable-lite-wrap winner-undo)
 "o" (repeatable-lite-wrap zetta-window-divider-mode)
 "C-S-b b" (repeatable-lite-wrap zetta-scroll-bar-mode)
 "r h" (repeatable-lite-wrap zetta-shrink-window-h-1)
 "r C-h" (repeatable-lite-wrap zetta-shrink-window-h-2)
 "r C-S-h" (repeatable-lite-wrap zetta-shrink-window-h-4)
 "r l" (repeatable-lite-wrap zetta-enlarge-window-h-1)
 "r C-l" (repeatable-lite-wrap zetta-enlarge-window-h-2)
 "r C-S-l" (repeatable-lite-wrap zetta-enlarge-window-h-4)
 "r j" (repeatable-lite-wrap zetta-shrink-window-v-1)
 "r C-j" (repeatable-lite-wrap zetta-shrink-window-v-2)
 "r C-S-j" (repeatable-lite-wrap zetta-shrink-window-v-4)
 "r k" (repeatable-lite-wrap zetta-enlarge-window-v-1)
 "r C-k" (repeatable-lite-wrap zetta-enlarge-window-v-2)
 "r C-S-k" (repeatable-lite-wrap zetta-enlarge-window-v-4)
 )

(add-to-list 'window-persistent-parameters '(window-side . writable))
(add-to-list 'window-persistent-parameters '(window-slot . writable))
(add-to-list 'window-persistent-parameters '(clone-of . writable))
(add-to-list 'window-persistent-parameters '(no-delete-other-windows . writable))
(add-to-list 'window-persistent-parameters '(split-window . writable))
(add-to-list 'window-persistent-parameters '(min-margins . writable))
(add-to-list 'window-persistent-parameters '(quit-restore . writable))

(general-define-key
 :keymaps 'menu-run-map
 "r" (repeatable-lite-wrap window-toggle-side-windows)
 )

(defun zetta-async-blowup ()
  (interactive)
  (when (or (eq (window-parameter (selected-window) 'window-side) 'top)
            (eq (window-parameter (selected-window) 'window-side) 'bottom))
    (if (< (window-total-height) 25)
        (enlarge-window 30)
      (shrink-window 30)))
  (when (eq (window-parameter (selected-window) 'window-side) 'left)
    (if (< (window-total-width) 30)
        (enlarge-window 30 t)
      (shrink-window 30 t)))
  (when (eq (window-parameter (selected-window) 'window-side) 'right)
    (if (< (window-total-width) 90)
        (enlarge-window 30 t)
      (shrink-window 30 t)))
  (unless (window-parameter (selected-window) 'window-side)
    (message "This is not a side window"))
  )

(general-define-key
 :keymaps '(treemacs-mode-map)
 "C-p" 'zetta-async-blowup)

(make-local-variable 'zetta-zen-disable)

(general-define-key
 :keymaps 'override
 "s-+" '(lambda () (interactive) (setq-local zetta-zen-disable t) (call-interactively 'text-scale-increase))
 "s-=" '(lambda () (interactive) (setq-local zetta-zen-disable t) (call-interactively 'text-scale-increase))

 "s--" '(lambda () (interactive) (setq-local zetta-zen-disable t) (call-interactively 'text-scale-decrease))

 "s-0" '(lambda () (interactive) (setq-local zetta-zen-disable t) (text-scale-adjust 0))
 "s-)" '(lambda () (interactive)
          ;; unlock
          (setq-local zetta-zen-disable nil)
          ;; and reset to (global) default size
          (text-scale-adjust 0))
 )
;;; window.el ends here
