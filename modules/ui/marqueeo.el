;;; marqueeo.el --- Configure marqueeo -*- lexical-binding: t; -*-

;;(use-package marqueeo
  ;;:after magit
  ;;:ensure (marqueeo :type git :host github :repo "progfolio/marqueeo"
                    ;;:files (:defaults "*.el" "frames/*.png"))
  ;;:config
;;
  ;;(setq marqueeo-tick-interval 0.02)
;;
  ;;(defun marqueeo-go ()
    ;;(interactive)
    ;;(setq marqueeo--frame-counter 0)
    ;;(run-with-timer
     ;;1.5 nil
     ;;(lambda ()
       ;;(its-a-him-marqueeo 1)
       ;;(run-with-timer
        ;;2 nil
        ;;(lambda () (its-a-him-marqueeo -1))))))
;;
  ;;;; Copying push integration from parrot.el
  ;;(setq marqueeo-party-on-magit-push t)
;;
  ;;(defun marqueeo--magit-push-filter (fun &rest args)
    ;;"If the git command is a push, add a process ending listener.
;;FUN is usually `magit-run-git-async'
;;ARGS is args for `magit-run-git-async'"
    ;;(if-let* ((process (apply fun args))
              ;;(command (car args)))
        ;;(progn (when (and (stringp command) (string= "push" command))
                 ;;(marqueeo-go))
               ;;process)))
;;
  ;;(defun marqueeo--maybe-advise-magit-push ()
    ;;"Update advice for magit push.
;;See `marqueeo-party-on-magit-push'."
    ;;(if marqueeo-party-on-magit-push
        ;;(advice-add 'magit-run-git-async :around #'marqueeo--magit-push-filter)
      ;;(advice-remove 'magit-run-git-async #'marqueeo--magit-push-filter)))
;;
  ;;(marqueeo--maybe-advise-magit-push)
  ;;)
;;; marqueeo.el ends here
