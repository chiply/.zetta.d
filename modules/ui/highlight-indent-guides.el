;;; highlight-indent-guides.el --- Configure highlight-indent-guides -*- lexical-binding: t; -*-

(use-package highlight-indent-guides

  ;; a surprisingl useful package

  ;; obvious use case: useful for orienting in json documents.  Same for
  ;; yaml, but is even more critical in yaml as whitespace determines
  ;; meaning, unlike json which can be minified without losing meaning

  ;; less obvious, but more useful features:

  ;; nice visual guides for programming languages where whitespace
  ;; really matters, like python.  For example, nice visual guide of
  ;; depth, function span.  Offers liter alternative to something like
  ;; focus mode for functions which uses basic indentation.

  ;; useful indicator of org src blocks, can turn off the annoying
  ;; background highlighting

  ;; trying it basically everywhere for now

  ;; interestinigly doesn't work super well in dired

  :config
  ;; no bitmap, changes widths
  (setq highlight-indent-guides-method 'fill)
  ;; Disable auto mode to prevent errors during theme switching
  ;; (faces can be nil during theme disable/enable cycle)
  (setq highlight-indent-guides-auto-enabled nil)
  ;; useful because it lets trace up the stack to orient where you are
  ;; in the tree
  (setq highlight-indent-guides-responsive 'stack)
  ;; lower number increases the contrast.  5 seems to be a good
  ;; compromise between subtlety and clarity
  (setq highlight-indent-guides-auto-character-face-perc 5)

  ;; Safely set faces after theme is fully loaded
  (defun zetta-highlight-indent-guides-auto-set-faces-safe ()
    "Set highlight-indent-guides faces only if colors are available."
    (when (and (facep 'default)
               (face-attribute 'default :foreground nil t)
               (face-attribute 'default :background nil t))
      (ignore-errors (highlight-indent-guides-auto-set-faces))))

  ;; Run after theme loads with a small delay for safety
  (add-hook 'enable-theme-functions
            (lambda (_)
              (run-with-idle-timer 0.1 nil #'zetta-highlight-indent-guides-auto-set-faces-safe)))

  ;; Also run once at startup after everything is loaded
  (add-hook 'emacs-startup-hook #'zetta-highlight-indent-guides-auto-set-faces-safe)

  ;;:hook (
         ;;(
          ;;json-mode
          ;;yaml-mode
          ;;org-mode
          ;;python-ts-mode
          ;;emacs-lisp-mode
          ;;) .
         ;;highlight-indent-guides-mode
         ;;)
  )
;;; highlight-indent-guides.el ends here
