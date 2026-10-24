;;; blinker.el --- Tab-bar heartbeat indicator -*- lexical-binding: t -*-

;; A minimal blinker for the tab-bar that shows whether Emacs is
;; responsive.  If the blink stalls, something is blocking.

(defvar blinker--frames ["·" "•" "·" " "]
  "Blinker animation frames.")

(defvar blinker--index 0
  "Current frame index.")

(defvar blinker--timer nil
  "Animation timer.")

(defun blinker--advance ()
  "Advance to the next frame."
  (setq blinker--index (mod (1+ blinker--index) (length blinker--frames)))
  (force-mode-line-update))

(defun blinker-start ()
  "Start the blinker."
  (interactive)
  (when blinker--timer (cancel-timer blinker--timer))
  (setq blinker--timer (run-at-time nil 0.4 #'blinker--advance)))

(defun blinker-stop ()
  "Stop the blinker."
  (interactive)
  (when blinker--timer
    (cancel-timer blinker--timer)
    (setq blinker--timer nil)))

(defun blinker-tab-bar ()
  "Tab-bar format entry for the blinker; nothing while it is stopped."
  (when blinker--timer
    `((blinker menu-item ,(concat " " (aref blinker--frames blinker--index) " ") ignore))))

(defcustom blinker-enabled nil
  "Non-nil starts the heartbeat when this file loads.
Each frame is a `force-mode-line-update' -- a full re-render of the SVG
chrome in every window, 2.5 times a second, to animate a four-frame dot
(OPTIMIZATIONS.org).  Off by default since 2026-10-23; `M-x blinker-start'
when you want to watch for a stall."
  :type 'boolean :group 'zetta)

(when blinker-enabled
  (blinker-start))

(provide 'blinker)
;;; blinker.el ends here
