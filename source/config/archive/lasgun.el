(use-package evil-mc
  :config
  (global-evil-mc-mode  1)
  )

(straight-use-package
 '(lasgun :type git :host github :repo "aatmunbaxi/lasgun.el"))
(require 'lasgun)


(require 'transient)

;; Defines some lasgun actions
(define-lasgun-action lasgun-action-upcase-word t upcase-word)
(define-lasgun-action lasgun-action-downcase-word t downcase-word)
(define-lasgun-action lasgun-action-kill-word nil kill-word)

(transient-define-prefix lasgun-transient ()
  "Main transient for lasgun."
  [["Marks"
    ("c" "Char timer" lasgun-mark-char-timer :transient t)
    ("w" "Word" lasgun-mark-word-0 :transient t)
    ("l" "Begin of line" lasgun-mark-line :transient t)
    ("s" "Symbol" lasgun-mark-symbol-1 :transient t)
    ("o" "Whitespace end" lasgun-mark-whitespace-end :transient t)
    ("x" "Clear lasgun mark ring" lasgun-clear-lasgun-mark-ring :transient t)
    ("u" "Undo lasgun mark" lasgun-pop-lasgun-mark :transient t)]
   ["Actions"
    ("SPC" "Make cursors" lasgun-make-multiple-cursors)
    ("." "Embark act all" lasgun-embark-act-all)
    ("U" "Upcase" lasgun-action-upcase-word)
    ("l" "Downcase" lasgun-action-downcase-word)
    ("K" "Kill word" lasgun-action-kill-word)
    ("q" "Quit" transient-quit-one)]])

(global-set-key (kbd "C-c t g") 'lasgun-transient)


