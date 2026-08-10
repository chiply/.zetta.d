;;; dap-mode.el --- Configure dap-mode -*- lexical-binding: t; -*-

(use-package dap-mode
  :commands (dap-debug dap-hydra dap-mode dap-ui-mode)

  :config
  (setq dap-ui-variable-length 1000)

  ;; lang specific
  (require 'dap-python)

  (setq dap-python-debugger 'debugpy)
  (setq dap-auto-configure-features '())

  ;;(dap-tooltip-mode nil)
  ;;(tooltip-mode nil)

  ;; silence unhandled-but-harmless debugpy events ("No message
  ;; handler for …" noise); same idiom dap-python itself uses for
  ;; debugpyWaitingForServer/debugpyAttach
  (cl-defmethod dap-handle-event ((_e (eql debugpySockets)) _session _params))
  (cl-defmethod dap-handle-event ((_e (eql process)) _session _params))

  ;; add the repl to the hydra (upstream omits it).  :exit t is
  ;; essential: the hydra's transient map (:foreign-keys run) eats
  ;; keystrokes typed into minibuffers/repls, which is also why M-x
  ;; from the hydra misbehaves — q dismisses it, s-D brings it back
  (with-eval-after-load 'dap-hydra
    (defhydra+ dap-hydra ()
      ("sr" dap-ui-repl "Repl" :exit t)))

  ;; upstream dap-delete-session sends "disconnect" via the
  ;; SYNCHRONOUS dap-request — freezing Emacs until C-g whenever the
  ;; adapter doesn't answer — and the cleanup lambda that follows it
  ;; is dead code (evaluated and discarded; an async callback orphaned
  ;; by some upstream refactor), so processes/sessions leaked too.
  ;; Rebuilt async with the callback attached and a timeout fallback.
  (define-advice dap-delete-session (:override (debug-session) zetta-async)
    (interactive (list (dap--cur-session-or-die)))
    (let* ((output-buffer (dap--debug-session-output-buffer debug-session))
           (program-proc (dap--debug-session-program-proc debug-session))
           (cleanup-fn
            (lambda ()
              (when (memq debug-session (dap--get-sessions))
                (->> (dap--get-sessions)
                     (-remove-item debug-session)
                     (dap--set-sessions))
                (when (eq (dap--cur-session) debug-session)
                  (dap--switch-to-session nil))
                (when (and program-proc (process-live-p program-proc))
                  (kill-process program-proc))
                (when (and output-buffer (buffer-live-p output-buffer))
                  (kill-buffer output-buffer))
                (dap--refresh-breakpoints)))))
      (if (not (dap--session-running debug-session))
          (funcall cleanup-fn)
        (dap--send-message
         (dap--make-request "disconnect" (list :restart :json-false))
         (lambda (_resp) (funcall cleanup-fn))
         debug-session)
        ;; adapter never answers -> clean up anyway (no-op if the
        ;; callback already ran, thanks to the memq guard)
        (run-at-time 2 nil cleanup-fn))))

  ;; zmc parity at session launch: phrase highlighting so streaming
  ;; output is annotated (the terminate hook re-applies it after
  ;; compilation-mode wipes hi-lock state), and the modeline spinner
  ;; as a "session still running" indicator — stopped at termination,
  ;; where the compilation-mode handover doubles as the done signal.
  (define-advice dap--create-output-buffer (:filter-return (buf) zetta-session-ui)
    (when (bufferp buf)
      (with-current-buffer buf
        (when (fboundp 'zetta-highlight-phrases)
          (zetta-highlight-phrases))
        (when (fboundp 'zetta-spinner-compile-spin)
          (zetta-spinner-compile-spin))))
    buf)

  ;; zmc convention, taken one step further: when the session ends its
  ;; process is dead, so the output buffer can be handed to the FULL
  ;; compilation major mode — TAB/S-TAB message navigation, RET-to-
  ;; jump, and the existing evil aux bindings on compilation-mode-map
  ;; all apply (the minor mode's map lacks TAB and keeps the buffer
  ;; labeled special-mode).  dap-terminated-hook is dap's sentinel.
  (defun zetta-dap--compile-ui-on-terminate (session)
    (when-let* ((buf (get-buffer (dap--debug-session-output-buffer session))))
      (when (buffer-live-p buf)
        (with-current-buffer buf
          ;; stop the spinner explicitly before the mode switch: the
          ;; switch would wipe its buffer-locals but orphan its timer
          (when (fboundp 'spinner-stop)
            (spinner-stop))
          (compilation-mode)
          (when (fboundp 'zetta-highlight-phrases)
            (zetta-highlight-phrases))))))
  (add-hook 'dap-terminated-hook #'zetta-dap--compile-ui-on-terminate)

  ;; the session-exit status line is a hardcoded `message' in an
  ;; anonymous sentinel (dap--create-session) — no knob, no advisable
  ;; name.  Emacs 30 message filtering: keep it out of the echo area
  ;; (it still lands in *Messages*).
  (add-to-list 'set-message-functions 'inhibit-message)
  (add-to-list 'inhibit-message-regexps "\\`Debug session process exited")

  ;; the output window is fit-to-buffer between min/max heights
  ;; (upstream: 10..20 lines, ~20% of a tall frame).  Pin both bounds
  ;; to half the frame at display time so the output always gets a
  ;; half split, whatever the frame size.
  (define-advice dap-go-to-output-buffer (:around (fn &rest args) zetta-half-height)
    (let* ((half (max 10 (/ (frame-height) 2)))
           (dap-output-window-min-height half)
           (dap-output-window-max-height half))
      (apply fn args)))

  ;; note this depends on python -- with-venv is str8 up broke
  ;; NOTE `pyvenv-virtual-env' is the active venv root (with trailing
  ;; slash); the old version read `pyvenv-activate', which is bound
  ;; but never set, silently resolving to the nonexistent /bin/python
  (defun dap-python--pyenv-executable-find (command)
    (if (bound-and-true-p pyvenv-virtual-env)
        (concat pyvenv-virtual-env "bin/python")
      (executable-find command)))

  ;; env-aware pytest template (successor to the removed hand-rolled
  ;; dap-debug-python-pytest-at-point): debugpy natively supports
  ;; :envFile, and dap-mode expands ${workspaceFolder} in registered
  ;; templates — no elisp .env parsing needed.  Launching it errors
  ;; when the project has no .env; use the shipped
  ;; "Python :: Run pytest (at point)" there instead.
  (dap-register-debug-template
   "Python :: Run pytest (at point, .env)"
   (list :type "python-test-at-point"
         :args "-vvv"
         :cwd "${workspaceFolder}"
         :program nil
         :module "pytest"
         :envFile "${workspaceFolder}/.env"
         :request "launch"
         :name "Python :: Run pytest (at point, .env)"))

  :hook ((python-ts-mode . dap-ui-mode)
         (python-ts-mode . dap-mode))

  :general
  (
   :keymaps 'override
   "s-D" 'dap-hydra
   "C-S-s-d" 'dap-debug
   )
  )
;;; dap-mode.el ends here
