;;; embark.el --- Configure embark -*- lexical-binding: t; -*-

(use-package embark
  :ensure (:wait t)
  :commands (embark-act embark-dwim embark-bindings embark-act-all)
  :config
  ;;(setq embark-prefix-help-command #'embark-prefix-help-command)
  (defun embark-act-noquit ()
    "Run action but don't quit the minibuffer afterwards."
    (interactive)
    (let ((embark-quit-after-action nil))
      (embark-act)))

  (setq embark-indicators
        '(
          embark-verbose-indicator
          embark-highlight-indicator
          embark-minimal-indicator
          ))
  (setq embark-confirm-act-all nil)

  (define-key embark-general-map (kbd "C-b") 'zetta-bookmark-create)
  (define-key embark-general-map (kbd "!") 'symbol-overlay-put)
  (define-key embark-general-map (kbd "C-!") 'symbol-overlay-remove-all)

  (setq embark-help-key "C-h")

  (defun embark-which-key-indicator ()
    "An embark indicator that displays keymaps using which-key.
The which-key help message will show the type and value of the
current target followed by an ellipsis if there are further
targets."
    (lambda (&optional keymap targets prefix)
      (if (null keymap)
          (which-key--hide-popup-ignore-command)
        (which-key--show-keymap
         (if (eq (plist-get (car targets) :type) 'embark-become)
             "Become"
           (format "Act on %s '%s'%s"
                   (plist-get (car targets) :type)
                   (embark--truncate-target (plist-get (car targets) :target))
                   (if (cdr targets) "…" "")))
         (if prefix
             (pcase (lookup-key keymap prefix 'accept-default)
               ((and (pred keymapp) km) km)
               (_ (key-binding prefix 'accept-default)))
           keymap)
         nil nil t (lambda (binding)
                     (not (string-suffix-p "-argument" (cdr binding))))))))

  (setq embark-indicators
        '(
          embark-which-key-indicator
          embark-highlight-indicator
          embark-isearch-highlight-indicator))

  (defun embark-hide-which-key-indicator (fn &rest args)
    "Hide the which-key indicator immediately when using the completing-read prompter."
    (which-key--hide-popup-ignore-command)
    (let ((embark-indicators
           (remq #'embark-which-key-indicator embark-indicators)))
      (apply fn args)))

  (advice-add #'embark-completing-read-prompter
              :around #'embark-hide-which-key-indicator)

  ;; project
  (defvar-keymap embark-project-map :parent embark-general-map)
  (add-to-list 'embark-keymap-alist '(project embark-project-map))

  ;; find file
  (defun embark-consult-project-find-in-dir (dir)
    (let ((default-directory dir)
          ;; to disable preview -- this is bc consult uses 'this
          ;; command' to determine what the active preview function is
          (this-command 'consult-project-extra-find))
      (call-interactively 'consult-project-extra-find)))

  ;; vc dir
  (defun embark-vc-dir (dir)
    (let ((default-directory dir))
      (if (fboundp 'magit)
          (call-interactively #'magit)
        (call-interactively #'project-vc-dir))))

  ;; dired
  (defun embark-dired (dir)
    (dired dir))

  ;; regex
  (defun embark-project-ripgrep (dir)
    (let ((default-directory dir)
          (this-command 'consult-ripgrep))  ;; to disable preview
      (if (fboundp 'consult-ripgrep)
          (call-interactively #'consult-ripgrep)
        (call-interactively #'grep))))

  ;; vterm
  (defun embark-project-vterm (dir)
    (let ((default-directory dir))
      (if (fboundp 'vterm)
          (call-interactively #'vterm)
        (call-interactively #'shell))))

  ;; TODO seems to be some hijacking of C-g going on.
  (general-define-key
   :keymaps 'embark-project-map
   "<return>" 'embark-vc-dir
   "f" 'embark-consult-project-find-in-dir
   "d" 'embark-dired
   "r" 'embark-project-ripgrep
   "v" 'embark-project-vterm
   "m" 'embark-vc-dir
   )

  :general
  (
   ;; override alone doesn't work here for some reason
   :keymaps (append zetta-modal-states-non-insert '(override))
   "C-." 'embark-act
   "C-h B" 'embark-bindings
   "C-;" 'embark-dwim
   "C->" 'embark-act-all
   )
  (
   :keymaps '(vertico-map)
   "C-." 'embark-act
   "C-;" 'embark-dwim
   "C->" 'embark-act-all
   )
  (
   :keymaps '(embark-collect-mode-map)
   "s-j" 'outline-forward-same-level
   "s-k" 'outline-backward-same-level
   )
  )

(defun zetta-embark-help-handler (km prefix)
  "Show embark bindings for KM via completing-read.
PREFIX is saved so repeatable-lite can continue the loop."
  (setq repeatable-lite-current-prefix prefix)
  (minibuffer-with-setup-hook
      (lambda ()
        (repeatable-lite-setup-minibuffer-switches #'zetta-embark-help-handler))
    (let ((command (consult--read
                    (car (embark--formatted-bindings km))
                    :prompt "Act: "
                    :category 'embark-keybinding)))
      (call-interactively (intern (car (last (string-split command))))))))

(add-to-list 'repeatable-lite-help-backends
             '(?\C-\S-h "C-S-h" "embark" zetta-embark-help-handler)
             t)
;;; embark.el ends here
