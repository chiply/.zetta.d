;; vim like highlighting 
(define-key evil-normal-state-map (kbd "j") 'evil-next-visual-line)
(define-key evil-normal-state-map (kbd "k") 'evil-previous-visual-line)

(setq evil-ex-search-persistent-highlight nil)
(evil-select-search-module 'evil-search-module 'evil-search)

(add-to-list
 'brushup-styles
 '(progn
    (set-face-attribute
   'evil-ex-lazy-highlight nil
   :inherit 'modus-themes-subtle-red)))












