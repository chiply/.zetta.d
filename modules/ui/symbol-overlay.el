;;; symbol-overlay.el --- Configure symbol-overlay -*- lexical-binding: t; -*-

(use-package symbol-overlay
  :after transient
  :config
  (setq symbol-overlay-idle-time 0.05)
  (setq symbol-overlay-priority 90)
  ;; disable default keybindings, will use transient, hydra, hercules,
  ;; etc... instead
  (setq symbol-overlay-map (make-sparse-keymap))

  ;; keybindings
  (global-set-key (kbd "M-i") 'symbol-overlay-put)
  (global-set-key (kbd "M-n") 'symbol-overlay-switch-forward)
  (global-set-key (kbd "M-p") 'symbol-overlay-switch-backward)
  (global-set-key (kbd "<f7>") 'symbol-overlay-mode)
  (global-set-key (kbd "<f8>") 'symbol-overlay-remove-all)

  ;; transient ui
  (transient-define-prefix symbol-overlay-transient ()
    "Symbol Overlay transient"
    ["Symbol Overlay"
     ["Overlays"
      ("." "Add/Remove at point" symbol-overlay-put)
      ("k" "Remove All" symbol-overlay-remove-all)
      ]
     ["Navigation"
      ("<" "Jump to first" symbol-overlay-jump-first)
      (">" "Jump to last" symbol-overlay-jump-last)
      ("n" "Next" symbol-overlay-switch-forward)
      ("p" "Previous" symbol-overlay-switch-backward)
      ("d" "Jump to definition" symbol-overlay-jump-to-definition)
      ("s" "Isearch" symbol-overlay-isearch-literally)
      ]
     ["Operations"
      ("e" "Echo mark" symbol-overlay-echo-mark)
      ("q" "Query replace" symbol-overlay-query-replace)
      ("r" "Rename" symbol-overlay-rename)
      ("w" "Copy to kill ring" symbol-overlay-save-symbol)
      ("t" "Toggle in scope" symbol-overlay-toggle-in-scope)
      ]
     ["Other"
      ("m" "Highlight symbol-at-point" symbol-overlay-mode)
      ]
     ]
    )

  (global-set-key (kbd "s-.") 'symbol-overlay-transient)

  ;; The auto-highlight face's stock #f0f0f0 is indistinguishable from
  ;; the org-remark default highlighter (brushup-bg-1) — use the
  ;; half-step between pure background and bg-1: visibly lighter than
  ;; a remark highlight, still detectable, theme-adaptive.
  (add-to-list 'brushup-styles
               '(set-face-attribute
                 'symbol-overlay-default-face nil
                 :background brushup-bg-1_0))
  (when (fboundp 'brushup) (brushup))

  ;; modes
  :hook ((sql-mode python-ts-mode emacs-lisp-mode yaml-mode
                   jsonian-mode json-mode web-mode shell-command-mode sh-mode grep-mode
                   lark-mode makefile-mode helpful-mode org-mode terraform-mode eww-mode) .
                   symbol-overlay-mode))
;;; symbol-overlay.el ends here
