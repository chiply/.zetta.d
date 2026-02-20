(use-package corfu
  :hook (elpaca-after-init . global-corfu-mode)
  ;; Optional customizations
  :custom
  ;; (corfu-cycle t)                ;; Enable cycling for `corfu-next/previous'
  (corfu-auto t)                 ;; Enable auto completion
  ;; (corfu-separator ?\s)          ;; Orderless field separator
  ;; (corfu-quit-at-boundary nil)   ;; Never quit at completion boundary
  ;; (corfu-quit-no-match nil)      ;; Never quit, even if there is no match
  ;; (corfu-preview-current nil)    ;; Disable current candidate preview
  ;; (corfu-preselect 'prompt)      ;; Preselect the prompt
  ;; (corfu-on-exact-match nil)     ;; Configure handling of exact matches
  ;; (corfu-scroll-margin 5)        ;; Use scroll margin

  ;; Enable Corfu only for certain modes.
  ;; :hook ((prog-mode . corfu-mode)
  ;;        (shell-command-mode . corfu-mode)
  ;;        (eshell-mode . corfu-mode))

  ;; Recommended: Enable Corfu globally.  This is recommended since Dabbrev can
  ;; be used globally (M-/).  See also the customization variable
  ;; `global-corfu-modes' to exclude certain modes.
  :config
  (defun corfu-move-to-minibuffer ()
    (interactive)
    (pcase completion-in-region--data
      (`(,beg ,end ,table ,pred ,extras)
       (let ((completion-extra-properties extras)
             completion-cycle-threshold completion-cycling)
         (consult-completion-in-region beg end table pred)))))
  (keymap-set corfu-map "M-m" #'corfu-move-to-minibuffer)
  (add-to-list 'corfu-continue-commands #'corfu-move-to-minibuffer)

  (defun corfu-enable-in-minibuffer ()
    "Enable Corfu in the minibuffer."
    (when (local-variable-p 'completion-at-point-functions)
      ;; (setq-local corfu-auto nil) ;; Enable/disable auto completion
      (setq-local corfu-echo-delay nil ;; Disable automatic echo and popup
                  corfu-popupinfo-delay nil)
      (corfu-mode 1)))
  (add-hook 'minibuffer-setup-hook #'corfu-enable-in-minibuffer)

  (corfu-echo-mode -1)
  (corfu-indexed-mode 1)
  (corfu-popupinfo-mode 1)

  (setq corfu-popupinfo-delay 0.25)

  ;; add frame alpha to corfu--frame-parameters
  (add-to-list 'corfu--frame-parameters '(alpha . (75 . 75)))

  :brushup
  
  (add-to-list 'brushup-styles
               '(set-face-attribute 'corfu-default nil
                                    :foreground brushup-fg
                                    :background brushup-bg))

  (add-to-list 'brushup-styles
               '(set-face-attribute 'corfu-current nil
                                    :foreground brushup-fg
                                    :background brushup-bg
                                    ;; NOTE makes this work will across themes
                                    :underline t))

  :general
  (
   :keymaps 'corfu-map
   "M-F" 'corfu-expand
   "M-f" 'corfu-complete
   "C-'" 'corfu-quick-complete
   "RET" nil
   ;; seems counterintuitive, based on the function names, but I like
   ;; this behavior
   "C-S-j" 'corfu-popupinfo-scroll-up
   "C-S-k" 'corfu-popupinfo-scroll-down))

(use-package nerd-icons-corfu
  :after corfu
  :config
  (add-to-list 'corfu-margin-formatters #'nerd-icons-corfu-formatter))
