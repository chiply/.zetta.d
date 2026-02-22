;;; ace-window.el --- Configure ace-window -*- lexical-binding: t; -*-

(use-package ace-window
  :demand t
  :commands (ace-window ace-select-window ace-delete-window ace-swap-window)
  :brushup
  (add-to-list 'brushup-styles
               '(progn
                  (set-face-attribute 'aw-leading-char-face nil
                                      :background brushup-bg
                                      :foreground brushup-fg
                                      :height 4.0)
                  (set-face-attribute 'aw-mode-line-face nil
                                      :foreground brushup-fg
                                      :weight 'bold)))

  :config
  (setq aw-scope 'frame
        aw-dispatch-always t
        aw-char-position "left"
        aw-keys '(?a ?s ?d)
        aw-display-mode-overlay nil
        aw-background nil
        aw-minibuffer-flag t
        aw-ignore-current nil
        )
  ;; Don't use ace-window-display-mode — it prepends the window number
  ;; to mode-line-format, duplicating what telephone-line's zt-ace-1
  ;; segment already shows. Instead, hook aw-update directly to keep
  ;; the ace-window-path window parameter populated for telephone-line.
  (aw-update)
  (add-hook 'window-configuration-change-hook #'aw-update)
  (add-hook 'after-make-frame-functions (lambda (_) (aw-update)) t)

  ;; helm buffer bring buffer name temporarily intto the headerline
  ;; TODO change this -- more modular, add to list
  (setq aw-ignored-buffers
        '(
          "*Calc Trail*" " *LV*"
          )
        )
  
  :general
  (
   :keymaps 'launch-map
   "," 'ace-window
   )

  :hook (use-package--ace-window--post-config . zetta-brushup)
  )
;;; ace-window.el ends here
