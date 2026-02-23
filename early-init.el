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

;; Bypass file-name-handler-alist during init (~90-120ms savings).
;; Every require/load checks this regex list for TRAMP, compression, etc.
;; None of that is needed during startup.
(defvar zetta--file-name-handler-alist file-name-handler-alist)
(setq file-name-handler-alist nil)
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq file-name-handler-alist zetta--file-name-handler-alist)))

;; Skip source vs bytecode mtime checks during init.
;; Safe because we control when bytecode is compiled via `zetta install`.
(setq load-prefer-newer nil)

;; Suppress all rendering during init (restored automatically on frame creation)
(setq inhibit-redisplay t
      inhibit-message t)
(add-hook 'window-setup-hook
          (lambda ()
            (setq inhibit-redisplay nil
                  inhibit-message nil)
            (redisplay)))

;; Use fundamental-mode for *scratch* (avoids loading text-mode machinery)
(setq initial-major-mode 'fundamental-mode
      initial-scratch-message nil)

;; Faster subprocess I/O (default 4KB; benefits LSP, compilation, etc.)
(setq read-process-output-max (* 4 1024 1024))  ; 4MB

;; Prevent flash of unstyled modeline at startup
(setq-default mode-line-format nil)

;; Don't resize frame at startup
(setq frame-inhibit-implied-resize t)

;; Disable bidirectional text scanning for performance
(setq-default bidi-display-reordering 'left-to-right
              bidi-paragraph-direction 'left-to-right)
(setq bidi-inhibit-bpa t)

;; Don't compact font caches during GC (expensive, especially with icon fonts)
(setq inhibit-compacting-font-caches t)

;; Skip rendering cursors/highlights in unfocused windows
(setq-default cursor-in-non-selected-windows nil)
(setq highlight-nonselected-windows nil)

;; Faster scrolling over unfontified regions
(setq fast-but-imprecise-scrolling t)

;; Reduce idle UI refresh frequency (default 0.5s)
(setq idle-update-delay 1.0)

;; Don't attempt DNS lookups on strings that look like hostnames
(setq ffap-machine-p-known 'reject)
;;; early-init.el ends here
