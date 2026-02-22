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

(general-define-key
 :keymaps 'menu-window-map
 "D" (** delete-window)
 "C-S-d" (** delete-other-windows)
 "C-S-S" (** window-toggle-side-windows)
 "C-S-b h" (** horizontal-scroll-bar-mode)
 "mm" (** balance-windows)
 "mk" (** minimize-window)
 "mj" (** maximize-window)
 "C-v" (** visual-line-mode)
 "C-t" (** toggle-truncate-lines)
 "C-t" (** toggle-truncate-lines)
 "C-w" (** toggle-word-wrap)
 "s" (** zetta-state-hydra/body)
 "f" (** consult-project-extra-find)
 "F" (** find-file)
 "x" (** execute-extended-command)
 "u" (** winner-undo)
 "o" (** zetta-window-divider-mode)
 "C-S-b b" (** zetta-scroll-bar-mode)
 "r h" (** (lambda () (interactive) (shrink-window-horizontally 1)))
 "r C-h" (** (lambda () (interactive) (shrink-window-horizontally 2)))
 "r C-S-h" (** (lambda () (interactive) (shrink-window-horizontally 4)))
 "r l" (** (lambda () (interactive) (enlarge-window-horizontally 1)))
 "r C-l" (** (lambda () (interactive) (enlarge-window-horizontally 2)))
 "r C-S-l" (** (lambda () (interactive) (enlarge-window-horizontally 4)))
 "r j" (** (lambda () (interactive) (shrink-window 1)))
 "r C-j" (** (lambda () (interactive) (shrink-window 2)))
 "r C-S-j" (** (lambda () (interactive) (shrink-window 4)))
 "r k" (** (lambda () (interactive) (enlarge-window 1)))
 "r C-k" (** (lambda () (interactive) (enlarge-window 2)))
 "r C-S-k" (** (lambda () (interactive) (enlarge-window 4)))
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
 "r" (** window-toggle-side-windows)
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

;; (defun zetta-set-window-margin-zen ()
;;   (unless (and (boundp 'zetta-zen-disable) zetta-zen-disable)
;;     (when
;;         (and
;;          (> (window-total-width) 160)
;;          (or (not (window-parameter (selected-window) 'window-slot)) (string= major-mode "org-mode"))
;;          (not (equal text-scale-mode-amount 2)) ;; it should be two when both the above cateogires are true
;;          )
;;       (text-scale-set 2)
;;       )
;;     (when
;;         (and
;;          (<= (window-total-width) 160)
;;          (>= (window-total-width) 50)
;;          (or (not (window-parameter (selected-window) 'window-slot)) (string= major-mode "org-mode"))
;;          (not (equal text-scale-mode-amount 0)) ;; it should be two when both the above cateogires are true
;;          )
;;       (text-scale-set 0)
;;       )
;;     (when
;;         (and
;;          (<= (window-total-width) 49)
;;          (>= (window-total-width) 0)
;;          (or (not (window-parameter (selected-window) 'window-slot)) (string= major-mode "org-mode"))
;;          (not (equal text-scale-mode-amount -2)) ;; it should be two when both the above cateogires are true
;;          )
;;       (text-scale-set -2)
;;       ) (when
;;       (and
;;        (or
;;         (string= (symbol-name (window-parameter (selected-window) 'window-side)) "right")
;;         (string= (symbol-name (window-parameter (selected-window) 'window-side)) "top")
;;         (string= (symbol-name (window-parameter (selected-window) 'window-side)) "left")
;;         (string= (symbol-name (window-parameter (selected-window) 'window-side)) "bottom")
;;         )
;;        (not (equal text-scale-mode-amount -2)) ;; it should be two when both the above cateogires are true
;;        )
;;       (text-scale-set -2)
;;       )
;;     )
;;   )

;; (defun zetta-zen-mode ()
;;   (add-hook 'window-configuration-change-hook 'zetta-set-window-margin-zen 0 'local)
;;   )
;; (add-hook 'prog-mode-hook 'zetta-zen-mode)
;; (add-hook 'window-configuration-change-hook 'zetta-zen-mode)

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
