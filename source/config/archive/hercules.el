;; (use-package hercules
;;   :config

;;   (setq hercules-show-prefix t)

;;   (hercules-def
;;    :toggle-funs #'org-babel-mode
;;    :keymap 'org-babel-map
;;    :transient t
;;    :flatten t
;;    )

;;   (hercules-def
;;    :toggle-funs #'smerge-mode
;;    :keymap 'smerge-mode-map
;;    :transient t
;;    :flatten t
;;    )

;;   (hercules-def
;;    :toggle-funs #'hlt-highlight
;;    :keymap 'hlt-map
;;    :transient t
;;    :flatten t
;;    )

;;   ;; tweak binding to taste
;;   (define-key org-mode-map (kbd "C-c C-v") #'org-babel-mode)
;;   (define-key org-mode-map (kbd "C-c ^") #'smerge-mode)
;;   )

;; (use-package hercules
;;   :ensure (:wait t)
;;   :demand t
;;   :config

;;   ;; BASE map

;;   ;; TODO add which-key and embark support in the form of
;;   ;; reserved bindings in these maps (similar to, but separate from
;;   ;; C-h for now)
;;   (defvar-keymap hercules-base-keymap)
;;   ;;(general-define-key :keymaps 'hercules-base-keymap "C-h" (lambda () (interactive) (which-key-hide-show-hint)))
;;   ;;;; TODO transience doesn't seem to persist through selecting a command with embark -- may not be able to use this
;;   ;;(general-define-key :keymaps 'hercules-base-keymap "! C-h" (lambda () (interactive) (embark-overriding-keymap-help-command)))

;;   ;; other maps and hercules-def
;;   (defvar-keymap menu-window-keymap :parent hercules-base-keymap)
;;   ;;(hercules-def :toggle-funs 'hercules-window :keymap 'menu-window-keymap :transient t :flatten t)

;;   (defvar-keymap hercules-org-keymap :parent hercules-base-keymap)
;;   (hercules-def :toggle-funs 'hercules-org :keymap 'hercules-org-keymap :transient t :flatten t)

;;   (defvar-keymap hercules-run-keymap :parent hercules-base-keymap)
;;   (hercules-def :toggle-funs 'hercules-run :keymap 'hercules-run-keymap :transient t :flatten t)

;;   (defvar-keymap hercules-project-keymap :parent hercules-base-keymap)
;;   (hercules-def :toggle-funs 'hercules-project :keymap 'hercules-project-keymap :transient t :flatten t)

;;   (defvar-keymap hercules-magit-keymap :parent hercules-base-keymap)
;;   (hercules-def :toggle-funs 'hercules-magit :keymap 'hercules-magit-keymap :transient t :flatten t)

;;   :general
;;   (:keymaps 'launch-map
;;             "w" (lambda () (interactive) (repeater-from-keymap menu-window-keymap))
;;             ;;"p" 'hercules-project
;;             ;;"o" 'hercules-org
;;             ;;"r" 'hercules-run
;;             ;;"g" 'hercules-magit
;;             )
;;   (:keymaps '(evil-insert-state-map)
;;             (general-chord ",w") (lambda () (interactive) (repeater-from-keymap menu-window-keymap))
;;             ;;(general-chord ",p") 'hercules-project
;;             ;;(general-chord ",o") 'hercules-org
;;             ;;(general-chord ",r") 'hercules-run
;;             ;;(general-chord ",g") 'hercules-magit
;;             )
;;   (:keymaps 'override :states '(normal visual) :prefix ","
;;             "w" (lambda () (interactive) (repeater-from-keymap menu-window-keymap))
;;             ;;"p" 'hercules-project
;;             ;;"o" 'hercules-org
;;             ;;"r" 'hercules-run
;;             ;;"g" 'hercules-magit
;;             ))
