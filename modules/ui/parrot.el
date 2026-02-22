;;; parrot.el --- Configure parrot -*- lexical-binding: t; -*-

(use-package parrot
  :commands (parrot-mode parrot-start-animation)
  :ensure (parrot :type git :host github :repo "positron-solutions/parrot")
  :config
  (setq parrot-party-on-magit-push t)

  (defun parrot--magit-push-filter (fun &rest args)
    "If the git command is a push, add a process ending listener.
FUN is usually `magit-run-git-async'
ARGS is args for `magit-run-git-async'"
    (if-let* ((process (apply fun args))
              (command (car args)))
        (progn (when (and (stringp command) (string= "push" command))
                 ;; NOTE updating this to wait for the push to
                 ;; complete -- otherwise there is lagging magit is
                 ;; locking emacs for some reason
                 (run-with-timer
                  1.5 nil
                  (lambda ()
                    (parrot-party-while-process process))))
               process)))

  :custom
  (parrot-animate 'hide-static)
  (parrot-rotate-animate-after-rotation nil)
  ;; trying to prevent jittering due to pushing freezing emacs
  (parrot-num-rotations 5)
  ;; doesn't work
  (parrot-party-on-org-todo-states '("DONE"))
  ;; NOTE I get issues with the othertypes
  (parrot-type 'default)
  ;;(parrot-animate-on-load t)
  ;;(parrot-mode t)
  :config
  (setq zetta-parrot-window nil)
  (setq zetta-parrot-buffer nil)
  (defun zetta-animate-parrot ()
    (interactive)
    (setq zetta-parrot-window (selected-window))
    (setq zetta-parrot-buffer (current-buffer))
    (parrot-start-animation)
    )

  ;; NOTE overwriting function in parrot.el, my custom functions
  ;; ensures the parrot only animates in the selected buffer/window
  (defun parrot--progress ()
    "Start a persistent parrot animation.
Use `parrot-progress-finished' to stop."
    (zetta-animate-parrot))

  
  :hook
  ((magit-status-mode . (lambda () (parrot-mode) (parrot-stop-animation)))
   (org-mode . (lambda () (parrot-mode) (parrot-stop-animation)))))
;;; parrot.el ends here
