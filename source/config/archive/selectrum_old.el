;;(use-package selectrum
  ;;:init
  ;;;;(selectrum-mode +1)
  ;;(setq selectrum-max-window-height 10
        ;;selectrum-display-style '(horizontal))
;;
  ;;:brushup
  ;;(add-to-list 'brushup-styles
               ;;'(set-face-attribute 'selectrum-current-candidate nil
                                    ;;:background brushup-bg-2
                                    ;;:foreground brushup-fg)) 
;;
  ;;:general
  ;;(
   ;;:keymaps 'selectrum-minibuffer-map
   ;;"C-j" 'selectrum-next-candidate
   ;;"C-k" 'selectrum-previous-candidate
   ;;"s-j" 'selectrum-next-page
   ;;"s-k" 'selectrum-previous-page
;;
   ;;"C-S-k" 'kill-line
   ;;"C-y" 'yank 
   ;;"s-c" 'selectrum-kill-ring-save
;;
   ;;"<C-return>" 'selectrum-submit-exact-input
;;
   ;;"M-q" '(lambda ()
            ;;(interactive)
            ;;(selectrum-cycle-display-style))
;;
   ;;"M-S-q" '(lambda ()
              ;;(interactive)
              ;;(if (eq selectrum-max-window-height 20)
                  ;;(setq selectrum-max-window-height 10)
                ;;(setq selectrum-max-window-height 20)))
   ;;)
;;
  ;;:hook (use-package--selectrum--post-config . zetta-brushup)
  ;;)


;;(use-package prescient)
;;
;;(use-package selectrum-prescient
  ;;:after (selectrum prescient)
;;
  ;;:init
  ;;(selectrum-prescient-mode +1)
  ;;(prescient-persist-mode +1)
;;
  ;;:config
  ;;(setq selectrum-prescient-enable-filtering nil)
  ;;)
