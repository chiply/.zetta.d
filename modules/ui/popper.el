;;; popper.el --- Configure popper -*- lexical-binding: t; -*-

(use-package popper
  ;; this package controls the convenient display of more transient
  ;; buffers.  Often used for side windows, but very useful in the
  ;; more generic context.  Provides a quick way to quickly close a
  ;; transient window and restore whatever was underneath it

  ;; note you can move a side window that has a default location and
  ;; popper will redisplay it where it WAS

  ;; think about most of your display stetings must be set in diplsy
  ;; buffer alist, this adds the ppopup management feature
  :bind (("C-`"   . popper-toggle)
         ("M-`"   . popper-cycle)
         ("C-M-`" . popper-toggle-type))
  :init
  (setq popper-reference-buffers
        '(
          "\\*Messages\\*" "Output\\*$" "\\*Async Shell Command\\*"
          help-mode helpful-mode dired-mode
          magit-status-mode magit-process-mode
          ))
  ;; leave to display buffer alist, can set default side or other
  ;; location there
  (setq popper-display-control nil)
  (popper-mode +1)
  (popper-echo-mode +1)
  :config
  ;; if nil then the mode line never shows up, likely a bug
  (setq popper-mode-line "")
  (setq popper-echo-lines 5)
  )
;;; popper.el ends here
