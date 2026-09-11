;;; ibuffer.el --- Configure ibuffer -*- lexical-binding: t; -*-

(use-package ibuffer
  :ensure nil
  ;; Loaded eagerly, not on the first `ibuffer': this module FILE is
  ;; named ibuffer.el, and `eval-after-load "ibuffer"' matches
  ;; load-history by file name, so any package that defers a binding
  ;; until ibuffer loads fires the moment THIS file loads -- against a
  ;; void `ibuffer-mode-map' unless the real ibuffer is already in.
  ;; hyperbole's autoloads do exactly that ("@" for hycontrol), and its
  ;; `:defer 1' require died on the hub with void-variable
  ;; ibuffer-mode-map (measured 2026-09-11).  The GUI profile never saw
  ;; it because all-the-icons-ibuffer happened to load ibuffer first.
  :demand t

  :init
  (defun zetta-soda-create-and-display-ibuffer (&optional buf-or-mode-name)
    (interactive)
    (ibuffer nil buf-or-mode-name nil []))

  (defun zetta-soda-drink-ibuffer ()
    (interactive)
    (zetta-soda-drink (quote zetta-soda-create-and-display-ibuffer) "*Ibuffer*"))

  (defun zetta-soda-cap-ibuffer ()
    (interactive)
    (zetta-soda-cap "*Ibuffer*"))

  (general-define-key
   :keymaps 'menu-run-map
   "b" (** zetta-soda-drink-ibuffer)
   "B" (** zetta-soda-cap-ibuffer))

  :hook (
         (ibuffer-mode . (lambda () (visual-line-mode -1)))
         (ibuffer-mode . (lambda () (text-scale-set -2)))
         (ibuffer-mode . (lambda () (ibuffer-auto-mode 1)))
         )
  )
;;; ibuffer.el ends here
