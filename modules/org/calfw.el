;;; calfw.el --- Configure calfw calendar -*- lexical-binding: t; -*-

(use-package calfw
  :ensure t
  :commands (cfw:open-calendar-buffer)
  :config
  (with-eval-after-load 'evil
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
      "q" 'bury-buffer)))

(autoload 'calfw-org-open-calendar "calfw-org" "Open calfw calendar with org agenda." t)

(use-package calfw-org
  :ensure t
  :after calfw
  :demand t)

;;; calfw.el ends here
