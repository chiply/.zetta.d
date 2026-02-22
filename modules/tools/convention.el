;;; convention.el --- Configure convention -*- lexical-binding: t; -*-

;;(use-package convention
  ;;:straight nil
  ;;:load-path (expand-file-name "source/zettapkg/convention" user-emacs-directory)
  ;;:demand t
;;
  ;;:hydra
  ;;(defhydra+ hydra-convention ()
    ;;("d" docker "M-x docker" :exit t :column "Misc")
;;
    ;;("i" convention-build-image-from-preset "Build (preset)" :exit t :column "Image")
    ;;("I" convention-build-image-from-search-term "Build" :exit t)
    ;;("li" docker-images "docker-images")
    ;;("ri" convention-remove-image "Remove" :exit t)
;;
    ;;("C" convention-start-container "Start" :exit t :column "Container")
    ;;("s" convention-stop-container "Stop" :exit t)
    ;;("S" convention-start-a-stopped-container "Start a stopped" :exit t) 
    ;;("lrc" convention-prompt-for-running-container "List running" :exit t)
    ;;("lsc" convention-prompt-for-stopped-container "List stopped" :exit t)
    ;;("lac" convention-prompt-for-all-container "List all" :exit t)
    ;;("lc" docker-containers "docker-containers")
;;
    ;;("rc" convention-stop-and-remove-container "Stop and remove" :exit t :column "REPL")
    ;;("D" convention-connect-to-container "Local (container)" :exit t)
    ;;("R" zetta-ssh-shell "Remote" :exit t)
;;
;;
    ;;("C-d" convention-dock "Local (container)" :exit t :column "ssh")
    ;;("C-r" zetta-ssh "Remote" :exit t)
;;
    ;;("u" convention-initiate-build-ui "Build ui" :exit t)
    ;;)
;;
  ;;:general
  ;;(
   ;;:keymaps 'evil-insert-state-map
   ;;(general-chord ",d") 'hydra-convention/body
   ;;)
  ;;(
   ;;:states '(normal visual)
   ;;:keymaps 'override
   ;;:prefix ","
   ;;"d" 'hydra-convention/body
   ;;)
  ;;)
;;; convention.el ends here
