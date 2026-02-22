;;; minimap.el --- Configure minimap -*- lexical-binding: t; -*-

;; NOTE revisited on May 9th.  Basically the minimap doesn't work well
;; wiht spacetree.  Tried all different settings to get around this,
;; but best thing to do is simply not use the interactive version.
;; frankly I don't think this would ever be necessary outside of a
;; presentation scenario, and leaving it static will likely keep it
;; out of the way for the most part (eg not poppoing up in new
;; contexts were I don't need it)



;; org-mode needs to not be in indent mode


;; same behavior for treemacs with the updates?


;; The automatic update is cool, but this causes some issues. It will
;; be better to strike a balance between the two. Two functions should
;; be implemented. One for toggling follow mode in the form of
;; switching between a delay of zero and a delay of one of A second
;; function should be implemented to quickly update the mini Mac based
;; on location. These functions should be bound to similar keys and
;; the toggling should be the higher tier binding.


;; issues
;; doesn't appear in a consistent window
;; appearing in windows that are not elftmost causes issues
;; delete other windows also deletes the minimap
;; enters in evil mode, so the click to scroll doesnt work

;; pros
;; wout linenumbers it is actually quite useful
;; updates really smoothly with low latancy
;; benefirs of minimaps

;; current use:
;; given issues when rendering in complex layouts, I will typically use this rarely or when presenting (when I have simple window layouts)

;; left off (and last for the day... when doing ,w c-S-D, this closes the minimap.  Need to change this special function to change the minimap setting prior to and after )

(use-package minimap
  :commands (minimap-mode minimap-update)
  :config

  ;; overwriting the minor mode definition and other functions allows for ignored buffers, which is necessary.  For example agenda --> agenda.org would break all of emacs on me
  ;;(define-minor-mode minimap-mode
  ;;"Toggle minimap mode."
  ;;:global t
  ;;:group 'minimap
  ;;:lighter " MMap"
  ;;(if minimap-mode
  ;;(progn
  ;;(when (and minimap-major-modes
                     ;;;; CHANGED make sure buffer is not in ignored buffer list
  ;;(not (< 0
  ;;(length (-filter
  ;;(lambda (ignored-buffer-regex)
  ;;(string-match ignored-buffer-regex (buffer-name (current-buffer))))
  ;;zetta-minimap-ignored-buffers
  ;;)) 
  ;;))
  ;;(apply 'derived-mode-p minimap-major-modes))
  ;;(unless (minimap-get-window)
  ;;(minimap-create-window))
            ;;;; Create minimap.
  ;;(minimap-new-minimap))
          ;;;; Create timer.
  ;;(setq minimap-timer-object
  ;;(run-with-idle-timer minimap-update-delay t 'minimap-update))
          ;;;; Hook into other modes.
  ;;(minimap-setup-hooks))
      ;;;; Turn it off
  ;;(minimap-kill)
  ;;(minimap-setup-hooks t)))
  ;;
  ;;(defun minimap-update (&optional force)
  ;;"Update minimap sidebar if necessary.
  ;;This is meant to be called from the idle-timer or the post command hook.
  ;;When FORCE, enforce update of the active region."
  ;;(interactive)
    ;;;; If we are in the minibuffer, do nothing.
  ;;(unless (active-minibuffer-window)
  ;;(if (minimap-active-current-buffer-p)
          ;;;; We are still in the same buffer, so just update the minimap.
  ;;(minimap-update-current-buffer force)
        ;;;; The buffer was switched, check if the minimap should switch, too.
  ;;(if (and minimap-major-modes
                 ;;;; CHANGED make sure buffer is not in ignored buffer list
  ;;(not (< 0
  ;;(length (-filter
  ;;(lambda (ignored-buffer-regex)
  ;;(string-match ignored-buffer-regex (buffer-name (current-buffer))))
  ;;zetta-minimap-ignored-buffers
  ;;)) 
  ;;))
  ;;
  ;;(apply 'derived-mode-p minimap-major-modes))
  ;;(progn
              ;;;; Create window if necessary...
  ;;(unless (minimap-get-window)
  ;;(minimap-create-window))
              ;;;; ...and re-create minimap with new buffer...
  ;;(minimap-new-minimap)
              ;;;; Redisplay
  ;;(sit-for 0)
              ;;;; ...and call update again.
  ;;(minimap-update t))
          ;;;; We have entered a buffer for which no minimap should be
          ;;;; displayed. Check if we should de
  ;;(when (and (minimap-get-window)
  ;;(minimap-need-to-delete-window))
            ;;;; We wait a tiny bit before deleting the window, since we
            ;;;; might only be temporarily in another buffer.
  ;;(run-with-timer 0.3 nil
  ;;(lambda ()
  ;;(when (and (null (minimap-active-current-buffer-p))
  ;;(minimap-get-window))
  ;;(delete-window (minimap-get-window))))))))))
  ;;
  ;;(setq zetta-minimap-ignored-buffers '("agenda.org" "agenda_pub.org"))

  ;;(setq minimap-major-modes
  ;;'(
  ;;prog
  ;;)
  ;;)

  



  ;; to get git information in the fringes
  (setq minimap-hide-fringes nil)
  (setq minimap-minimum-width 25)
  (setq minimap-width-fraction 0.10)
  (setq minimap-update-delay 0.10)
  (setq minimap-hide-scroll-bar nil)
  ;; causes issues with window size when on left... 
  (setq minimap-window-location 'right)
  (setq minimap-enlarge-certain-faces nil)
  (setq minimap-recreate-window t)
  (setq minimap-automatically-delete-window t)
  (setq minimap-display-semantic-overlays nil) ;; did this fix the org issue?
  (setq minimap-dedicated-window t)

  (remove-hook 'minimap-mode-hook 'hide-mode-line-mode)

  (add-hook 'minimap-sb-mode-hook
            (lambda () (progn
                         (display-line-numbers-mode -1)
                         (evil-emacs-state)
                         )))

  (defun zetta-toggle-minimap ()
    (interactive)
    (minimap-mode 'toggle)
    )

  (defun zetta-toggle-minimap-follow ()
    (interactive)
    (if minimap-update-delay
        (setq minimap-update-delay nil)
      (setq minimap-update-delay 0))
    (minimap-mode 'toggle)
    (minimap-mode 'toggle)
    )

  (setq minimap-major-modes
        '(
          prog-mode
          ;;text-mode ;; NOTE this includes org-mode
          ;; NOTE no org mode as minimap doesn't work with narrowed org buffers
          ;;org-mode
          embark-collect-mode
          eww-mode
          Info-mode
          ;; all modes
          ;;special-mode
          ;;shell-command-mode
          ;;compilation-mode
          ))

  :brushup
  (add-to-list 'brushup-styles
               '(progn
                  ;;(set-face-attribute 'minimap-current-line-face nil
                  ;;:background brushup-bg-2
                  ;;)
                  (set-face-attribute 'minimap-active-region-background nil
                                      :background brushup-bg-1_0
                                      )
                  
                  ))

  :general
  (
   :keymaps 'override
   "s-[" 'zetta-toggle-minimap
   "s-]" 'minimap-update
   "s-}" 'zetta-toggle-minimap-follow
   )
  )
;;; minimap.el ends here
