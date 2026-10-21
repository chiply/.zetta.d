;;; minimalize.el --- Configure minimal UI -*- lexical-binding: t; -*-

(setq ns-use-proxy-icon nil
      frame-resize-pixelwise t
      ring-bell-function 'ignore
      inhibit-startup-message t
      make-backup-files nil
      auto-save-default nil
      indicate-empty-lines nil
      kill-buffer-query-functions
      (delq
       'process-kill-buffer-query-function
       kill-buffer-query-functions))

(add-to-list 'default-frame-alist
             '(ns-transparent-titlebar . nil))

(dolist (x '((ns-transparent-titlebar . unbound)
             (ns-appearance . unbound)))
  (add-to-list 'frameset-filter-alist x))

(menu-bar-mode 1)
(tool-bar-mode -1)
(when (fboundp 'horizontal-scroll-bar-mode)
  (horizontal-scroll-bar-mode -1))
(when (fboundp 'scroll-bar-mode)
  (scroll-bar-mode -1))
(fset 'yes-or-no-p 'y-or-n-p)

;; The cursor blinks: it is what says "point is here" now that the beacon
;; is off (beacon.el).  Stock timing -- ten blinks after the last input,
;; then steady, so an idle frame is not redrawn forever
;; (`blink-cursor-blinks'; 0 would blink without end).
(blink-cursor-mode 1)

(setq frame-title-format nil)
;;; minimalize.el ends here
