;;; bootstrap-menu.el --- Configure menu system -*- lexical-binding: t; -*-

(use-package menu
  :ensure nil
  :demand t
  :load-path "source/zettapkg/menu"
  :after which-key
  :config

  ;; note making this t requires you to 'quit' the which key window
  ;; before opening embark if C-h is used... not a clear side-effect,
  ;; so documenting here.  I want to keep the option open to have both.
  ;; only way around this is to rebind C-h in the default menus-map
  (setq which-key-use-C-h-commands t)

  (defmacro defmenu+ (name map key)
    "Personal function that runs defmenu and also binds the menu to a prefix
key that is available in many contexts"
    `(progn
       (defmenu ,name ,map)
       ;; TODO add meow
       (general-define-key :keymaps 'launch-map
                           ,key ',name)

       ;; TODO why is this commented out?
       ;;(general-define-key :keymaps '(evil-insert-state-map)
                           ;;(general-chord ,(concat "," key)) ',name)

       (general-define-key :keymaps 'override :states '(normal visual)
                           :prefix ","
                           ,key ',name)))


  ;; TODO why do these need to be defined here? and not elsewhere?
  ;; is it as so there is a keymap available for use elsewhere?

  ;; TODO what would a different pattern look like? maybe allowing
  ;; these to be included in each config file?  what would happen if
  ;; different keys were supplied each time by accident?  I'm
  ;; wondering about the value of a higher level macro that defines
  ;; the menu if it doesn't already exist... but them I'm departing
  ;; from the feature that allows user's to add bindings to a menu by
  ;; simply using built-in (or potentially their own custom) keymap
  ;; commands.  Maybe some macro in addition to this one that DOESN'T
  ;; bind to a key as so you can let the end user optionally include a
  ;; defmenu in their code to ensure the menu exists?  And that macro
  ;; would conditionally create the menu if it doesn't already exist,
  ;; and do nothing else.
  ;;(defmenu+ menu-window menu-window-keymap "W")
  ;;(defmenu+ menu-project menu-project-keymap "p")
  ;;(defmenu+ menu-run menu-run-keymap "r")
  ;;(defmenu+ menu-org menu-org-keymap "O")
  ;;(defmenu+ menu-theme menu-theme-keymap "t")

  ;; TODO move to magit -- not used here
  ;;(defmenu+ menu-vc menu-vc-keymap "g")

  ;; TODO this somehow gets overwritten elsewhere whatever overwrites
  ;; this actually doesn't work at all (doesn't show any kind of help)
  (setq prefix-help-command 'versatile-C-h)
  )

(provide 'bootstrap-menu)
;;; bootstrap-menu.el ends here
