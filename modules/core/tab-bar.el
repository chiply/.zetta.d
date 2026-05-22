;;; tab-bar.el --- Configure tab-bar-format system -*- lexical-binding: t; -*-

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

(defun tab-bar-keycast ()
  (let ((str (keycast--format keycast-mode-line-format)))
    (when str
      (set-text-properties 0 (length str) nil str))
    `((keycast menu-item ,(or str "") ignore))))

(defun zetta-pyvenv-activate-poetry-modeline ()
  (and (boundp 'zetta-pyvenv-virtual-env)
       (concat "{venv:"
               (zetta-minify-path zetta-pyvenv-virtual-env)
               "/"
               (car (last (split-string zetta-pyvenv-virtual-env "/")))
               "}")))

(defun new-line () "\n")

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
  (let ((name (if (buffer-file-name)
                  (abbreviate-file-name (buffer-file-name))
                (buffer-name))))
    (if (> (length name) 70)
        (concat (substring name 0 67) "…")
      name)))

(defun zetta-gptel-processes ()
  (when (boundp 'gptel--request-alist)
    (let ((num-processes (length gptel--request-alist)))
      (if (> num-processes 0)
          (format " ai:%d " num-processes)
        ""))))

(defun zetta-tab-bar-current-thing ()
  "Tab-bar item: shows the buffer-local `zetta-tap-current-thing'."
  (when (and (boundp 'zetta-tap-current-thing) zetta-tap-current-thing)
    (format "[%s] " zetta-tap-current-thing)))

(setq tab-bar-format
      '(
        ;; line 1
        zetta-buffer-name zmc-modeline-indicator
        zetta-pyvenv-activate-poetry-modeline
        ;; line 2
        new-line zetta-tab-bar-spot-mode-line-string
        ;; line 3 left-aligned
        new-line zetta-tab-bar-modal zetta-gptel-processes
        blinker-tab-bar
        ;; line 3 right-aligned
        tab-bar-format-align-right tab-bar-keycast zetta-insert-space
        zetta-tab-bar-current-thing zetta-tab-bar-recursion-level
        recursion-indicator--string tab-bar-format-global
        internal-echo-keystrokes-prefix
        zetta-insert-space zetta-current-prefix zetta-insert-space
        space-tree-modeline-lighter
        ))

(add-to-list 'brushup-styles
             '(set-face-attribute 'tab-bar nil :box nil :inherit nil :background brushup-bg)
             )

;;; tab-bar.el ends here
