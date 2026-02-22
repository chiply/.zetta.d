;;; early-init.el --- Configure early initialization -*- lexical-binding: t; -*-

;; Disable built-in package manager (using Elpaca instead)
(setq package-enable-at-startup nil)

;; Disable UI elements early (before frame creation - faster than doing it later)
(push '(tool-bar-lines . 0) default-frame-alist)
(push '(menu-bar-lines . 0) default-frame-alist)
(push '(vertical-scroll-bars) default-frame-alist)

;; Defer garbage collection during init (huge speedup)
(setq gc-cons-threshold most-positive-fixnum
      gc-cons-percentage 0.6)

;; Restore reasonable GC settings after init
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold (* 16 1024 1024)  ; 16MB
                  gc-cons-percentage 0.1)))

;; Faster file loading
(setq read-process-output-max (* 4 1024 1024))  ; 4MB (default is 4KB)

;; Prevent flash of unstyled modeline at startup
(setq-default mode-line-format nil)

;; Don't resize frame at startup
(setq frame-inhibit-implied-resize t)

;; Disable bidirectional text scanning for performance
(setq-default bidi-display-reordering 'left-to-right
              bidi-paragraph-direction 'left-to-right)
(setq bidi-inhibit-bpa t)
;;; early-init.el ends here
