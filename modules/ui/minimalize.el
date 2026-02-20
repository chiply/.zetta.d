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
(horizontal-scroll-bar-mode -1)
(scroll-bar-mode -1)
(fset 'yes-or-no-p 'y-or-n-p)

(setq blink-cursor-mode nil)

(setq frame-title-format nil)



