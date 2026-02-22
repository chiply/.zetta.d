;;; interface.el --- Configure core interface -*- lexical-binding: t; -*-

;; download from https://files.ax86.net/terminus-ttf/ drag it into the
;; `Font Book` app
;; Set font in default-frame-alist for daemon compatibility (set-frame-font
;; fails silently in daemon mode since there's no frame yet)
(add-to-list 'default-frame-alist `(font . ,(format "%s-%d" zetta-font 16)))
(set-face-attribute 'default nil :family zetta-font :height 160)

;; prevent the *Warnings* buffer from popping up
;;(setq warning-minimum-level :emergency)

(winner-mode)

(global-auto-revert-mode 1) ;; you might not want this
(setq auto-revert-verbose nil) ;; or this

;; need t turn his on per mode, causes oo many issues
(global-visual-line-mode -1)

(pixel-scroll-precision-mode 1)

(setq scroll-margin 0 ;; setting this above 0 causes issues with jumping while scrolling
      scroll-conservatively 9999
      scroll-step 1)

(setq scroll-bar-width nil)
(setq scroll-bar-height nil)


(defun server-shutdown ()
  "Save buffers, Quit, and Shutdown (kill) server"
  (interactive)
  (save-some-buffers)
  (kill-emacs))

(defun zetta-scratch ()
  (interactive)
  (let* ((major-mode-input (completing-read "Enter a major mode: "
                                            '("python" "sql" "elisp"))))
    (switch-to-buffer (concat "*" major-mode-input "-scratch" "*"))
    (when (string= major-mode-input "python") (python-ts-mode))
    (when (string= major-mode-input "sql") (sql-mode))
    (when (string= major-mode-input "elisp") (emacs-lisp-mode))))

(setq enable-local-variables :all)

;;(defhydra+ hydra-window ()
;;("C-S" zetta-scratch :exit t)
;;("C-S-<backspace>" zetta-server-shutdown-save-desktop))

(general-define-key :keymaps 'menu-window-keymap
                    "C-S" 'zetta-scratch
                    "C-S-<backspace>" 'zetta-server-shutdown-save-desktop)

(setq-default left-margin-width 2)
(setq-default right-margin-width 2)
;;(setq-default left-fringe-width 5)
;;(setq-default right-fringe-width 5)


(defun zetta-tab-bar-hydra ()
  (let ((icon (zetta-line-hydra-indicator-icon))) (when icon "H")))

(defun zmc-modeline-indicator ()
  (concat
   ;;"🏃‍♀️‍➡️"
   (when (boundp 'local-transient) local-transient)
   " "
   ;;" || " "🌎 "
   ;;(when (boundp 'latest-transient) latest-transient)
   ))

(setq pom nil)
(defun pomodoro! ()
  ;; toggle the value of global variable pom
  (interactive)
  (setq pom (not pom)))

;; some comment
(defun pom-ind ()
  ;; comment
  (when pom "🍅 "))

(defun tab-bar-keycast ()
  (let ((str (keycast--format keycast-mode-line-format)))
    (when str
      (set-text-properties 0 (length str) nil str))
    `((keycast menu-item ,(or str "") ignore))))

;;(defun repeat-indicator-icon ()
;;(if (and (boundp 'menu--indicator) menu--indicator) "** " "__ "))

(defun zetta-pyvenv-activate-poetry-modeline ()
  (and (boundp 'zetta-pyvenv-virtual-env)
       (concat "{venv:"
               (zetta-minify-path zetta-pyvenv-virtual-env)
               "/"
               (car (last (split-string zetta-pyvenv-virtual-env "/")))
               "}")))

(defun new-line () "\n")
(defun new-line-1 () "2")
(defun new-line-2 () "\n")

(defun zetta-nyan ()
  (nyan-create))

(defun zetta-current-prefix ()
  (let ((descr (key-description
                (or
                 (and
                  (boundp 'my-this-command-keys-vector)
                  my-this-command-keys-vector)
                 (this-command-keys-vector)))))
    (if (string-match-p "mouse" descr)
        ""
      descr
      )
    ))

;; otherwise prefix keys won't show up
(add-hook 'prefix-command-echo-keystrokes-functions 'force-mode-line-update)

(defun zetta-insert-space () " ")

;; Tab-bar spinner — replaces flappy-fish with a spinner-types animation.
;; Like the fish, a continuously running animation tells you Emacs isn't frozen.
(defvar zetta-tab-spinner-index 0)
(defvar zetta-tab-spinner-type 'Bar)
(defvar zetta-tab-spinner--timer nil)

(defun zetta-tab-spinner--advance ()
  "Advance the tab-bar spinner to the next frame."
  (let ((frames (cdr (assq zetta-tab-spinner-type spinner-types))))
    (when frames
      (setq zetta-tab-spinner-index
            (mod (1+ zetta-tab-spinner-index) (length frames)))))
  (force-mode-line-update))

(defun zetta-tab-spinner-start (&optional type)
  "Start the tab-bar spinner with optional TYPE (defaults to `zetta-tab-spinner-type')."
  (interactive)
  (when type (setq zetta-tab-spinner-type type))
  (when zetta-tab-spinner--timer (cancel-timer zetta-tab-spinner--timer))
  (setq zetta-tab-spinner--timer
        (run-at-time nil 0.2 #'zetta-tab-spinner--advance)))

(defun zetta-tab-spinner-stop ()
  "Stop the tab-bar spinner."
  (interactive)
  (when zetta-tab-spinner--timer
    (cancel-timer zetta-tab-spinner--timer)
    (setq zetta-tab-spinner--timer nil)))

(defun zetta-fish ()
  "Return the current spinner frame for the tab-bar."
  (let ((frames (cdr (assq zetta-tab-spinner-type spinner-types))))
    (when frames
      (concat " " (nth zetta-tab-spinner-index frames) " "))))

(defun zetta-tab-bar-spot-mode-line-string ()
  (if (fboundp 'spot-mode-line-string)
      (spot-mode-line-string)
    "*"))

(defun zetta-tab-bar-modal ()
  (or
   (when (and (boundp 'evil-mode) evil-mode) "evil")
   (when (and (boundp 'meow-mode) meow-mode) "meow")
   (when (not (or (and (boundp 'evil-mode) evil-mode)
                  (and (boundp 'meow-mode) meow-mode)))
     "emacs"))
  )

(defun zetta-tab-bar-recursion-level ()
  (let ((recursion-level (minibuffer-depth)))
    (if (zerop recursion-level)
        "[R:0] "
      (format " [R:%d] " recursion-level)))
  )

(defun zetta-buffer-name ()
  (if (buffer-file-name) (abbreviate-file-name (buffer-file-name)) "%b"))

(defun zetta-gptel-processes ()
  (when (boundp 'gptel--request-alist)
    (let ((num-processes (length gptel--request-alist)))
      (if (> num-processes 0)
          (format " ai:%d " num-processes)
        ""))))


(setq tab-bar-format '(;; everything here on will be aligned on the right
                       ;;zetta-tab-bar-hydra
                       zetta-buffer-name
                       zmc-modeline-indicator
                       zetta-pyvenv-activate-poetry-modeline
                       ;; doesn't work in tab bar as it doesn't get
                       ;; updated reliably... note that even when
                       ;; using the entry and exist hooks it doesn't
                       ;; work
                       ;;key-state
                       ;;zetta-nyan
                       new-line
                       zetta-tab-bar-spot-mode-line-string
                       new-line
                       zetta-tab-bar-modal
                       zetta-gptel-processes

                       ;;zetta-fish
                       blinker-tab-bar

                       tab-bar-format-align-right
                       tab-bar-keycast 
                       zetta-insert-space
                       zetta-tab-bar-recursion-level
                       recursion-indicator--string
                       ;;"  "
                       pom-ind
                       tab-bar-format-global
                       repeat-indicator-icon ;; (?)
                       ;; these go together
                       ;; TODO add current map
                       internal-echo-keystrokes-prefix ;; universal arg
                       zetta-insert-space
                       zetta-current-prefix
                       zetta-insert-space
                       space-tree-modeline-lighter))

(add-to-list 'brushup-styles
             '(set-face-attribute 'tab-bar nil :box nil :inherit nil :background brushup-bg)
             )


;; Emacs 28 and newer: Hide commands in M-x which do not work in the current
;; mode.  Vertico commands are hidden in normal buffers. This setting is
;; useful beyond Vertico.
(setq read-extended-command-predicate #'command-completion-default-include-p)

;; note can change the minibuffer font in this way.  not doing this
;; for now because the echo area height is determined by teh default
;; font size.  so when there is a short default font and the font set
;; here is taller, then the minibuffer resizes whenever it gets used,
;; causign jitter in the interface
;; (add-hook 'minibuffer-setup-hook 'my-buffer-face-mode-pt-mono-p85)

;; activate makefile-mode whenver a file is opened matching the regex "Makefile.*"
(add-to-list 'auto-mode-alist '("Makefile.*" . makefile-mode))
(add-hook 'window-selection-change-functions (lambda (_) (force-mode-line-update)))

(use-package trailing-newline-indicator
  :ensure (trailing-newline-indicator
           :host github
           :repo "saulotoledo/trailing-newline-indicator")

  :init
  (global-trailing-newline-indicator-mode 1)

  :config
  (setq trailing-newline-indicator-show-line-number nil)
  )
;;; interface.el ends here
