;;; corfu.el --- Configure corfu -*- lexical-binding: t; -*-

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
   ;;"M-f" 'corfu-complete
   "C-'" 'corfu-quick-complete
   "RET" 'corfu-complete
   ;; seems counterintuitive, based on the function names, but I like
   ;; this behavior
   "C-S-j" 'corfu-popupinfo-scroll-up
   "C-S-k" 'corfu-popupinfo-scroll-down))

(defcustom zetta-corfu-icon-height 0.8
  "Relative height for `nerd-icons-corfu' completion icons.
Nerd-icons glyphs rasterize about 1.2x taller than the completion text.
Corfu sizes every candidate row by `default-line-height', so the taller
icon rows overflow and the lower rows are clipped -- barely noticeable at
the normal size, badly at large text scales.  Capping each icon to this
fraction of the text height keeps every row at the line height, so no
candidate is vertically truncated.  Set to nil to disable the cap."
  :type '(choice (const :tag "No cap" nil) number)
  :group 'corfu)

(use-package nerd-icons-corfu
  :after corfu
  :config
  (defun zetta-corfu-cap-icon-height (icon)
    "Cap ICON to `zetta-corfu-icon-height' of the completion text height.
`:filter-return' advice for `nerd-icons-corfu--get-by-kind'.  Returns a copy
of the icon glyph scaled down so Corfu -- which budgets each row at
`default-line-height' -- never clips the lower rows (worst at large text
scales).  Copies the string first so the shared nerd-icons glyph cache is
left untouched; a nil `zetta-corfu-icon-height' leaves the icon unchanged."
    (if (and (stringp icon) (> (length icon) 0) (numberp zetta-corfu-icon-height))
        (let ((s (copy-sequence icon)))
          (add-face-text-property 0 (length s)
                                  (list :height zetta-corfu-icon-height) nil s)
          s)
      icon))
  (advice-add 'nerd-icons-corfu--get-by-kind :filter-return
              #'zetta-corfu-cap-icon-height)

  (add-to-list 'corfu-margin-formatters #'nerd-icons-corfu-formatter))


;;; corfu.el ends here
