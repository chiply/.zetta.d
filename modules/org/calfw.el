;;; calfw.el --- Configure calfw calendar -*- lexical-binding: t; -*-

;; calfw-org.el ships in the same repo as calfw.  Declared as its own
;; elpaca order the pair coordinates through elpaca's monorepo machinery,
;; which deadlocks on a cold first clone ("Waiting on monorepo" forever --
;; measured on every cold CI run and a cold local build, 2026-07-22; warm
;; it resolves instantly, which is why no working machine ever saw it).
;; Building both files as ONE order removes the coordination entirely;
;; the calfw-org use-package below stays for config but ensures nothing.
(use-package calfw
  :ensure (calfw :files ("calfw.el" "calfw-compat.el" "calfw-org.el"))
  :commands (cfw:open-calendar-buffer)
  :config
  ;; Auto-resize calendar when window dimensions change
  (defun zetta-calfw-auto-resize (frame)
    "Re-render calfw buffers when FRAME's windows change size."
    (dolist (win (window-list frame))
      (with-current-buffer (window-buffer win)
        (when (derived-mode-p 'cfw:calendar-mode)
          (let ((cp (calfw-cp-get-component)))
            (when cp
              (let ((dims (calfw-default-window-dims win)))
                (calfw-cp-resize cp (car dims) (cdr dims)))
              (calfw--cp-update cp)))))))
  (add-hook 'window-size-change-functions #'zetta-calfw-auto-resize)

  (with-eval-after-load 'evil
    ;; Calendar grid — hjkl navigation, SPC for details, RET to open
    (evil-set-initial-state 'cfw:calendar-mode 'normal)
    (evil-define-key 'normal calfw-calendar-mode-map
      "h" 'calfw-navi-previous-day-command
      "j" 'calfw-navi-next-week-command
      "k" 'calfw-navi-previous-week-command
      "l" 'calfw-navi-next-day-command
      "^" 'calfw-navi-goto-week-begin-command
      "$" 'calfw-navi-goto-week-end-command
      "<" 'calfw-navi-prev-view
      ">" 'calfw-navi-next-view
      "t" 'calfw-navi-goto-today-command
      "." 'calfw-navi-goto-today-command
      "R" 'calfw-refresh-calendar-buffer
      (kbd "SPC") 'calfw-show-details-command
      (kbd "TAB") 'calfw-navi-next-item-command
      (kbd "<backtab>") 'calfw-navi-prev-item-command
      (kbd "M-g") 'calfw-navi-goto-date-command
      "D" 'calfw-change-view-day
      "W" 'calfw-change-view-week
      "T" 'calfw-change-view-two-weeks
      "M" 'calfw-change-view-month
      (kbd "RET") 'calfw-org-onclick
      "q" 'bury-buffer)

    ;; Details buffer — scrollable item list with org navigation
    (evil-set-initial-state 'calfw-details-mode 'normal)
    (evil-define-key 'normal calfw-details-mode-map
      "j" 'next-line
      "k" 'previous-line
      "h" 'calfw-details-navi-prev-command
      "l" 'calfw-details-navi-next-command
      (kbd "TAB") 'calfw-details-navi-next-item-command
      (kbd "<backtab>") 'calfw-details-navi-prev-item-command
      (kbd "RET") 'calfw-org-onclick
      (kbd "C-f") 'scroll-up-command
      (kbd "C-b") 'scroll-down-command
      "q" 'calfw-details-kill-buffer-command)))

(autoload 'calfw-org-open-calendar "calfw-org" "Open calfw calendar with org agenda." t)

(use-package calfw-org
  :ensure nil  ; built as part of the calfw order above (same repo)
  :after calfw
  :demand t)

;;; calfw.el ends here
