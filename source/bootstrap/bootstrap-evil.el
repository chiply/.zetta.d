;;; bootstrap-evil.el --- Configure evil-mode bootstrap -*- lexical-binding: t; -*-

(use-package evil
  :ensure (:wait t)
  :demand t
  :init
  (setq evil-want-keybinding nil)
  ;;(add-to-list
  ;;'brushup-styles
  ;;'(setq evil-emacs-state-cursor '("red" box)
  ;;evil-visual-state-cursor '("orange" box)
  ;;evil-insert-state-cursor '("blue" box)
  ;;evil-replace-state-cursor '("green" hollow)
  ;;evil-operator-state-cursor '("red" hollow)
  ;;evil-normal-state-cursor `(,(face-attribute 'default :foreground) box)))

  :config
  (setq evil-default-state 'normal)
  ;; note basic functionality only is implemented... search backwards
  ;; not supported, allows for convenient kill line without
  ;; interfering with other keybindings
  (setq evil-want-minibuffer t)


  ;; get emacs kbds in insert-mode
  (setcdr evil-insert-state-map nil)
  (define-key evil-insert-state-map (read-kbd-macro evil-toggle-key) 'evil-emacs-state)
  (define-key evil-insert-state-map (kbd "<escape>") 'evil-force-normal-state)  

  ;; this stuff is destined for the respective
  ;; use-package calls
  (evil-set-initial-state 'Info-mode 'normal)
  (evil-set-initial-state 'with-editor-mode 'emacs)
  (evil-set-initial-state 'eww-mode 'emacs)
  (evil-set-initial-state 'minimap-sb-mode 'emacs)
  (evil-set-initial-state 'minimap-mode 'emacs)
  (evil-set-initial-state 'minimap-mode 'emacs)
  (evil-set-initial-state 'biblio-selection-mode 'normal)

  (evil-mode 1)

  (key-chord-define evil-insert-state-map "jk" 'evil-normal-state)
  (key-chord-define evil-visual-state-map "kj" 'evil-normal-state)

  :general
  
  (
   :states '(normal visual)
   :keymaps 'override
   :prefix ","
   "/" 'evil-ex-nohighlight
   )
  (
   :states '(normal visual)
   "C-S-j" (lambda () (interactive) (evil-scroll-down nil))
   "C-S-k" (lambda () (interactive) (evil-scroll-up nil))
   "C-j" (lambda () (interactive) (evil-scroll-line-down 1))
   "C-k" (lambda () (interactive) (evil-scroll-line-up 1))
   )
  )



(defalias 'use-package-handler/:evil 'use-package-handle-forms)
(defalias 'use-package-normalize/:evil 'use-package-normalize-forms)

(add-to-list 'use-package-keywords :evil t)

(provide 'bootstrap-evil)
;;; bootstrap-evil.el ends here
