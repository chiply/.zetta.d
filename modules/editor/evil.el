;;; evil.el --- Configure evil-mode settings -*- lexical-binding: t; -*-

(use-package evil
  :ensure (:wait t)
  :demand t
  :init
  (setq evil-want-keybinding nil)

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
  (evil-set-initial-state 'biblio-selection-mode 'normal)

  (evil-mode 1)

  (key-chord-define evil-insert-state-map "jk" 'evil-normal-state)
  (key-chord-define evil-visual-state-map "kj" 'evil-normal-state)

  ;; vim like highlighting
  (define-key evil-normal-state-map (kbd "j") 'evil-next-visual-line)
  (define-key evil-normal-state-map (kbd "k") 'evil-previous-visual-line)

  (setq evil-ex-search-persistent-highlight nil)
  (evil-select-search-module 'evil-search-module 'evil-search)

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

  :brushup
  (add-to-list
   'brushup-styles
   '(progn
      (set-face-attribute
     'evil-ex-lazy-highlight nil
     :inherit 'modus-themes-subtle-red)))
  )

;;; evil.el ends here
