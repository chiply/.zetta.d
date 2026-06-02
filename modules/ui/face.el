;;; face.el --- Configure face and frame settings -*- lexical-binding: t; -*-

(add-to-list 'default-frame-alist '(fullscreen . maximized))
(setq initial-frame-alist (quote ((fullscreen . maximized))))

(defun transparency (value)
  (interactive "nTransparency Value 0 - 100 opaque:")
  (set-frame-parameter (selected-frame) 'alpha value))
(transparency 93)

(defun zetta-theme-brushup ()
  (interactive)
  (setq prefix-help-command 'repeatable--versatile-C-h)
  (when debug-on-error
    (toggle-debug-on-error)
    (message "Debug-on-error is off"))
  (when (fboundp 'brushup)
    (brushup)))

(general-define-key
 :keymaps 'menu-theme-map
 "T" (** zetta-theme-brushup))

(general-define-key
 :keymaps 'menu-window-map
 "t" 'menu-theme-map
 "T" (** transparency))

(add-hook 'help-mode-hook (lambda () (text-scale-set -2)))
(add-hook 'Info-mode-hook (lambda () (text-scale-set -2)))
(add-hook 'calendar-mode-hook (lambda () (text-scale-set 2)))
;;; face.el ends here
