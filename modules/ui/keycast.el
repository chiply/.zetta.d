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
  ;; Registered on `brushup-styles' rather than applied once here: these read
  ;; `brushup-fg', which changes with the theme, so a one-shot call left the
  ;; keycast faces on the PREVIOUS theme's foreground after every switch.
  (add-to-list
   'brushup-styles
   '(dolist (face '(keycast-key keycast-command))
      (when (facep face)
        (set-face-attribute face nil
                            :inherit nil :box nil :overline nil :underline nil
                            :background 'unspecified
                            :foreground brushup-fg)))
   t)

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

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;                     embark integration                            ;;
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;
  ;; `embark-act' runs the selected action within its own command-loop
  ;; turn.  For single-target command actions embark itself sets
  ;; `this-command' to the action (embark--act), so keycast's
  ;; post-command update names the action.  But actions in
  ;; `embark-multitarget-actions' (e.g. `embark-copy-as-kill') run via
  ;; `funcall' on that path and `this-command' is left as `embark-act' --
  ;; which is what keycast then shows.  Stamp `this-command' after every
  ;; normally-completed action so the action is reported instead.  (On
  ;; the quit-minibuffer path `embark--act' exits non-locally and the
  ;; :after advice does not run, same as embark's own stamping.)

  (with-eval-after-load 'embark
    (define-advice embark--act (:after (action &rest _) zetta-keycast-action)
      (when (and (bound-and-true-p zetta-keycast-mode) (symbolp action))
        (setq this-command action))))

  (with-eval-after-load 'repeatable
    (defvar zetta-keycast--in-repeatable nil)

    (define-advice call-interactively
        (:around (fn cmd &rest args) zetta-keycast-repeatable)
      (let* ((wrapper (and (symbolp cmd)
                           (string-prefix-p "repeatable-wrap" (symbol-name cmd))))
             (zetta-keycast--in-repeatable
              (or zetta-keycast--in-repeatable wrapper)))
        ;; Show the wrapped command as soon as the wrapper STARTS.  The
        ;; post-return update below only fires after the inner command
        ;; finishes -- for a minibuffer command that is after the whole
        ;; minibuffer interaction, so without this keycast keeps showing
        ;; whatever ran before the wrapper was invoked.
        (when (and wrapper (bound-and-true-p zetta-keycast-mode))
          (setq keycast--this-command-desc
                (intern (string-remove-prefix "repeatable-wrap-"
                                              (symbol-name cmd)))
                keycast--this-command-keys (this-single-command-keys)
                keycast--command-repetitions 0)
          (force-mode-line-update t))
        (prog1 (apply fn cmd args)
          (when (and zetta-keycast--in-repeatable
                     (bound-and-true-p zetta-keycast-mode)
                     (symbolp cmd)
                     (not wrapper))
            (setq keycast--this-command-desc cmd
                  keycast--this-command-keys (this-single-command-keys)
                  keycast--command-repetitions 0)
            (force-mode-line-update t)))))

    (defvar zetta-keycast-ignored-commands '(file-notify-handle-event)
      "Commands whose post-command updates keycast should ignore.
These arrive as (special) events outside the user's typing -- e.g.
file watchers firing while a project minibuffer is open -- and would
overwrite the genuinely last-typed command in the display.")

    (define-advice keycast--update
        (:around (fn) zetta-skip-repeatable-wrappers)
      (if (or (memq this-command zetta-keycast-ignored-commands)
              (and (symbolp this-command)
                   (string-prefix-p "repeatable-wrap" (symbol-name this-command))))
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
