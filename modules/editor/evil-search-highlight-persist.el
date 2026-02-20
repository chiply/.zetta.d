;;(use-package evil-search-highlight-persist
  ;;:after (highlight)
  ;;:init
  ;;(global-evil-search-highlight-persist t)
;;
  ;;:brushup
  ;;(add-to-list 'brushup-styles
               ;;'(set-face-attribute 'evil-search-highlight-persist-highlight-face nil
                                    ;;:foreground 'unspecified
                                    ;;:background 'unspecified
                                    ;;:underline t))
;;
  ;;:general
  ;;(
   ;;:keymaps 'evil-insert-state-map
   ;;(general-chord ",/") 'evil-search-highlight-persist-remove-all
   ;;)
  ;;(
   ;;:states '(normal visual)
   ;;:keymaps 'override
   ;;:prefix ","
   ;;"/" 'evil-search-highlight-persist-remove-all
   ;;)
;;
  ;;:hook (use-package--evil-search-highlight-persist--post-config . zetta-brushup)
  ;;)
