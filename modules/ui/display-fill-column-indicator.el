;;; display-fill-column-indicator.el --- Configure display-fill-column-indicator -*- lexical-binding: t; -*-

(use-package display-fill-column-indicator
  :ensure nil
  :hook (elpaca-after-init . global-display-fill-column-indicator-mode)

  :init
  ;; The rule marks where a line you are WRITING gets too long.  A terminal
  ;; or a REPL is not writing lines to that budget -- its width is the
  ;; window's, its output wraps where the program decided, and a bar down
  ;; column 80 is just a stripe through somebody else's layout.
  ;;
  ;; Done through the globalized mode's own predicate rather than by turning
  ;; the mode off again from each mode hook: `:predicate' is the supported
  ;; way to say WHERE a globalized minor mode applies, it is tested with
  ;; `derived-mode-p' (so `comint-mode' covers shell, the `inferior-*'
  ;; REPLs, sql, ielm and *Async Shell Command* in one entry), and it
  ;; answers for buffers that never run a mode hook at all.
  ;;
  ;; `special-mode' is upstream's own exclusion, kept.  The rest are the
  ;; terminals that are not comint -- the same set `zetta-window-chrome-rules'
  ;; strips the bars from, and for the same reason.
  (setq global-display-fill-column-indicator-modes
        '((not special-mode
               comint-mode ghostel-mode vterm-mode eshell-mode term-mode)
          t))

  :brushup

  (add-to-list 'brushup-styles
               '(progn
                  ;; provides subtlety, but still keeps it visible on
                  ;; the current line since the background is
                  ;; brushup-bg...
                  (set-face-attribute 'fill-column-indicator nil
                                      :background brushup-bg
                                      :foreground brushup-bg-1_0
                                      )
                  )
               )
  )
;;; display-fill-column-indicator.el ends here
