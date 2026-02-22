;;; docker.el --- Configure docker -*- lexical-binding: t; -*-

(use-package docker
  ;; there will inevitably be integration with convention.
  ;; the docker package makes working with containers easy
  ;; viewing, modifying, running etc...
  ;; convention is used for the creation of 1 off containers, and is
  ;; likely becoming obsoltete
  :commands (docker docker-containers docker-images docker-volumes docker-networks)

  :display
  ;;(zetta-side "^\\*docker-im*" 'top)
  ;;(zetta-side "^\\*docker-cont*" 'top)
  ;;(zetta-side "^\\*docker-vol*" 'top)
  ;;(zetta-side "^\\* docker*" 'top)

  :evil
  (evil-set-initial-state 'docker-volume-mode 'normal)
  (evil-set-initial-state 'docker-machine-mode 'normal)
  (evil-set-initial-state 'docker-image-mode 'normal)
  (evil-set-initial-state 'docker-container-mode 'normal)
  (evil-set-initial-state 'docker-network-mode 'normal)

  ;; bringing into evil from emacs mode
  ;; avoid j k l h

  ;; where possible, make analogs (eg l for ls in both image and
  ;; container, is l and ; by default, respectively)
  :general
  (
   :keymaps '(docker-image-mode-map)
   "<return>" 'convention-start-container-from-docker-image-mode
   "x" 'docker "L" 'docker-image-ls "D" 'docker-image-rm
   "R" 'docker-image-run "?" 'docker-image-help "F" 'docker-image-pull
   "P" 'docker-image-push "I" 'docker-image-inspect "d" 'docker-image-mark-dangling
   "r" 'docker-image-run-selection "T" 'docker-image-tag-selection
   "j" 'tablist-next-line
   "k" 'tablist-previous-line
   "m" 'tablist-mark-forward
   )
  (
   :keymaps '(docker-container-mode-map)
   "<return>" 'convention-dock-from-docker-container-mode
   "<C-return>" 'convention-connect-to-container-from-docker-container-mode
   "x" 'docker "C" 'docker-container-cp "l" 'docker-container-ls
   "D" 'docker-container-rm "d" 'docker-container-diff "?" 'docker-container-help
   "K" 'docker-container-kill "L" 'docker-container-logs "f" 'docker-container-open
   "O" 'docker-container-stop "C-d" 'docker-container-dired "P" 'docker-container-pause
   "s" 'docker-container-shell "S" 'docker-container-start "v" 'docker-container-vterm
   "a" 'docker-container-attach "e" 'docker-container-eshell "b" 'docker-container-shells
   "I" 'docker-container-inspect "R" 'docker-container-restart "F" 'docker-container-find-file
   "C-s" 'docker-container-shell-env "C-F" 'docker-container-find-directory
   "y" 'docker-container-cp-to-selection "r" 'docker-container-rename-selection
   "Y" 'docker-container-cp-from-selection "p" 'docker-container-unpause-selection
   "j" 'tablist-next-line
   "k" 'tablist-previous-line
   "m" 'tablist-mark-forward
   )
  (
   :keymaps '(docker-volume-mode-map)
   "l" 'docker-volume-ls
   "D" 'docker-volume-rm
   "?" 'docker-volume-help
   "C-d" 'docker-volume-dired
   "I" 'docker-volume-inspect
   "d" 'docker-volume-mark-dangling
   "f" 'docker-volume-dired-selection
   "j" 'tablist-next-line
   "k" 'tablist-previous-line
   "m" 'tablist-mark-forward
   )
  )
;;; docker.el ends here
