;;; keycast.el --- Configure keycast -*- lexical-binding: t; -*-

(use-package keycast
  :config
  ;; Minor mode that manages keycast's post-command-hook tracking
  ;; without going through keycast-mode-line-mode.
  (define-minor-mode zetta-keycast-mode
    "Toggle keycast display in the tab-bar."
    :global t
    (if zetta-keycast-mode
        (progn
          (add-hook 'post-command-hook #'keycast--update t)
          (add-hook 'minibuffer-exit-hook #'keycast--minibuffer-exit t))
      (unless (keycast--mode-active-p)
        (remove-hook 'post-command-hook #'keycast--update)
        (remove-hook 'minibuffer-exit-hook #'keycast--minibuffer-exit))))

  ;; Remove the box from keycast-key so it doesn't exceed tab-bar height.
  (set-face-attribute 'keycast-key nil :inherit nil :box nil :overline nil :underline nil :background 'unspecified :foreground brushup-fg)
  (set-face-attribute 'keycast-command nil :inherit nil :box nil :overline nil :underline nil :background 'unspecified :foreground brushup-fg)

  (zetta-keycast-mode)

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;                  repeatable integration                      ;;
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;
  ;; repeatable's command loop bypasses post-command-hook, so
  ;; keycast never sees dispatched commands.  Three-part fix:
  ;;
  ;; 1. :around call-interactively — sets a flag when a repeatable-wrap wrapper is
  ;;    called and updates keycast for real commands inside the loop.
  ;; 2. :around keycast--update — skips post-command-hook updates for
  ;;    repeatable-wrap wrappers so they don't overwrite the real command.
  ;; 3. :around execute-kbd-macro — exit commands go through
  ;;    execute-kbd-macro (not call-interactively), so intercept and
  ;;    dispatch via call-interactively instead.
  ;;
  ;; All advice is installed only after repeatable loads.

  (with-eval-after-load 'repeatable
    (defvar zetta-keycast--in-repeatable nil)

    (define-advice call-interactively
        (:around (fn cmd &rest args) zetta-keycast-repeatable)
      (let ((zetta-keycast--in-repeatable
             (or zetta-keycast--in-repeatable
                 (and (symbolp cmd)
                      (string-prefix-p "repeatable-wrap" (symbol-name cmd))))))
        (prog1 (apply fn cmd args)
          (when (and zetta-keycast--in-repeatable
                     (bound-and-true-p zetta-keycast-mode)
                     (symbolp cmd)
                     (not (string-prefix-p "repeatable-wrap" (symbol-name cmd))))
            (setq keycast--this-command-desc cmd
                  keycast--this-command-keys (this-single-command-keys)
                  keycast--command-repetitions 0)
            (force-mode-line-update t)))))

    (define-advice keycast--update
        (:around (fn) zetta-skip-repeatable-wrappers)
      (if (and (symbolp this-command)
               (string-prefix-p "repeatable-wrap" (symbol-name this-command)))
          (force-mode-line-update t)
        (funcall fn)))

    (define-advice execute-kbd-macro
        (:around (fn macro &rest args) zetta-keycast-capture-exit)
      (if (and zetta-keycast--in-repeatable
               (bound-and-true-p zetta-keycast-mode)
               (vectorp macro)
               (= (length macro) 1))
          (let ((binding (key-binding macro)))
            (if (and binding (commandp binding) (not (keymapp binding)))
                (call-interactively binding)
              (apply fn macro args)))
        (apply fn macro args))))
  )
;;; keycast.el ends here
