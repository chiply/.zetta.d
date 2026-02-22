;;; eww.el --- Configure eww -*- lexical-binding: t; -*-

(use-package eww
  :ensure nil
  :commands (eww eww-browse-url)
  :config
  (setq eww-auto-rename-buffer 'title)
  (setq eww-bookmarks-directory (expand-file-name "data/eww" user-emacs-directory))
  (setq shr-max-image-proportion 1.0) ; Shrink images to 50% of their original size

  (setq shr-inhibit-images nil)
  (setq shr-folding-mode t)

  ;; NOTE there is a bug in shr which causes rendering errors when
  ;; shr-us-fonts is nil, even though that's the way to get the
  ;; default emacs font used for everything else.  alternatively, we
  ;; can customize shr-text face to use our emacs font
  (setq shr-use-fonts t)
  (set-face-attribute 'shr-text nil :family "Terminus (TTF)")

  (eval-after-load 'shr
    '(progn
       (setq shr-width -1) ; Disable width-based wrapping
       (defun shr-fill-text (text) text) ; Prevent text filling
       (defun shr-fill-lines (start end) nil) ; Prevent line filling
       (defun shr-fill-line () nil))) ; Prevent individual line filling

  ;; This is how to control readble depending on the url
  (defun zetta-eww-after-render-functions ()
    (unless (or
             (string-match "reddit" (eww-current-url))
             (string-match "xkcd" (eww-current-url))
             )
      (eww-readable))
    (toggle-truncate-lines -1)
    )

  (defun zetta-eww-mode-functions ()
    ;; NOTE got the weird bug with shr-descend when disabling fonts
    (setq shr-use-fonts t)
    (toggle-truncate-lines -1)
    (olivetti-mode -1))

  (add-hook 'eww-after-render-hook 'zetta-eww-after-render-functions)
  (add-hook 'eww-mode-hook 'zetta-eww-mode-functions)

  ;; This is how to set image settings conditionally per url
  (defun my-eww-inhibit-images-advice (orig-fun url &rest args)
    "Set shr-inhibit-images based on URL before calling eww."
    (setq shr-inhibit-images
          (cond
           ((string-match-p "reddit\\.com\\|twitter\\.com\\|xkcd\\.com\\|github\\.com\\|wikipedia\\.org" url) nil)
           (t t)))
    (apply orig-fun url args))

  (advice-add 'eww :around #'my-eww-inhibit-images-advice)

  (defun zetta-eww-switch-to-eaf ()
    (interactive)
    (eaf-open-browser (eww-current-url)))

  (defun zetta-eww-follow-link ()
    (interactive)
    (browse-url (thing-at-point 'url)))

  (setq eww-default-download-directory "~/logseq/assets/")

  :general
  (
   :keymaps '(eww-mode-map)
   :states '(normal)
   "C-&" 'zetta-eww-switch-to-eaf
   "<return>" 'zetta-eww-follow-link
   "x" '(lambda () (interactive) (kill-buffer (current-buffer)))
   "s-i" 'eww-toggle-images
   )
  (
   :keymaps 'menu-lookup-map
   "e" 'eww
   ))
;;; eww.el ends here
