;;; undo-tree.el --- Configure undo-tree -*- lexical-binding: t; -*-

(use-package undo-tree
  :init
  (setq undo-tree-enable-undo-in-region t)

  ;; Prevent undo tree files from polluting your git repo.
  ;; This also ensures that undo data, whch could potentially contain
  ;; sensitive information, is not stored in the emacs directory

  ;; NOTE testing for now as it creates files in unwanted places
  (setq undo-tree-auto-save-history nil)
  ;;(setq undo-tree-history-directory-alist '(("." . "~/.emacs-undo/undo")))

  ;; https://stackoverflow.com/questions/8370778/remove-glyph-at-end-of-truncated-lines
  (set-display-table-slot standard-display-table 0 ?\ )

  ;;(defun undo-tree-visualize ()
  ;;"Visualize the current buffer's undo tree."
  ;;(interactive "*")
  ;;(unless undo-tree-mode
  ;;(user-error "Undo-tree mode not enabled in buffer"))
  ;;(deactivate-mark)
    ;;;; throw error if undo is disabled in buffer
  ;;(when (eq buffer-undo-list t)
  ;;(user-error "No undo information in this buffer"))
    ;;;; transfer entries accumulated in `buffer-undo-list' to `buffer-undo-tree'
  ;;(undo-list-transfer-to-tree)
    ;;;; add hook to kill visualizer buffer if original buffer is changed
  ;;(add-hook 'before-change-functions 'undo-tree-kill-visualizer nil t)
    ;;;; prepare *undo-tree* buffer, then draw tree in it
  ;;(let ((undo-tree buffer-undo-tree)
  ;;(buff (current-buffer))
  ;;(display-buffer-mark-dedicated 'soft))
      ;;;; this line is mine
  ;;(let ((buf (get-buffer-create undo-tree-visualizer-buffer-name)))
  ;;(display-buffer buf)
  ;;(select-window (get-buffer-window buf))
  ;;)
  ;;(setq undo-tree-visualizer-parent-buffer buff)
  ;;(setq undo-tree-visualizer-parent-mtime
  ;;(and (buffer-file-name buff)
  ;;(nth 5 (file-attributes (buffer-file-name buff)))))
  ;;(setq undo-tree-visualizer-initial-node (undo-tree-current undo-tree))
  ;;(setq undo-tree-visualizer-spacing
  ;;(undo-tree-visualizer-calculate-spacing))
  ;;(make-local-variable 'undo-tree-visualizer-timestamps)
  ;;(make-local-variable 'undo-tree-visualizer-diff)
  ;;(setq buffer-undo-tree undo-tree)
  ;;(undo-tree-visualizer-mode)
      ;;;; FIXME; don't know why `undo-tree-visualizer-mode' clears this
  ;;(setq buffer-undo-tree undo-tree)
  ;;(set (make-local-variable 'undo-tree-visualizer-lazy-drawing)
  ;;(or (eq undo-tree-visualizer-lazy-drawing t)
  ;;(and (numberp undo-tree-visualizer-lazy-drawing)
  ;;(>= (undo-tree-count undo-tree)
  ;;undo-tree-visualizer-lazy-drawing))))
  ;;(when undo-tree-visualizer-diff (undo-tree-visualizer-show-diff))
  ;;(let ((inhibit-read-only t)) (undo-tree-draw-tree undo-tree))))

  :config
  (global-undo-tree-mode)

  (with-eval-after-load 'evil
    (general-define-key
     :keymaps '(evil-normal-state-map evil-visual-state-map)
     :state '(normal visual)
     "u" 'undo-tree-undo
     "C-r" 'undo-tree-redo))

  :brushup
  (add-to-list 'brushup-styles
               '(set-face-attribute 'undo-tree-visualizer-active-branch-face nil
                                   :foreground brushup-fg
                                   :background brushup-bg
                                   ))

  :general

  (
   :keymaps 'launch-map
   "u" 'undo-tree-visualize
   )

  :hook (undo-tree-visualizer-mode . (lambda () (text-scale-set -2)))
  )
;;; undo-tree.el ends here
