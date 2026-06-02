;;; bootstrap-keys.el --- Configure key binding utilities -*- lexical-binding: t; -*-

;; for binding keys
(use-package general :demand t :ensure (:wait t))

;; for key "chords", although a better thought of as "melodies",
;; because they involve sequential presses of keys
(use-package key-chord
  :config
  (setq key-chord-two-keys-delay .05 key-chord-one-key-delay .05 key-chord-one-key-min-delay 0.5)
  (key-chord-mode 1))

;; provides hints
(use-package which-key
  :ensure (:wait t)
  :demand t
  :config

  (defun zetta-cursor-in-which-key-slot ()
    (and
     (eq 0 (window-parameter (selected-window) 'window-slot))
     (eq 'top (window-parameter (selected-window) 'window-side))
     ))

  (setq which-key-popup-type 'custom)
  (defun which-key-custom-popup-max-dimensions-function (ignore)
    (cons
     (which-key--height-or-percentage-to-height
      which-key-side-window-max-height)
     (frame-width)))

  (defun fit-horizontally ()
    (let ((fit-window-to-buffer-horizontally t))
      (fit-window-to-buffer)))

  (defun which-key-custom-show-popup-function (act-popup-dim)
    (let* ((alist `((window-width . fit-horizontally)
                    (window-height . fit-window-to-buffer)
                    (side . ,(if (zetta-cursor-in-which-key-slot)
                                 (intern "bottom")
                               (intern "top")
                               ))
                    (slot . 0)
                    )))

      (display-buffer-in-side-window which-key--buffer alist)
      (setq zetta-which-key-showing t)
      ))

  (defun which-key-custom-hide-popup-function ()
    (when (buffer-live-p which-key--buffer)
      (setq zetta-which-key-showing nil)
      (quit-windows-on which-key--buffer)
      ))

  ;; Monkey-patch: suppress the "No bindings found" message when
  ;; formatted-keys is nil.  Without this, which-key briefly flashes
  ;; a message on the first of two rapid invocations before the
  ;; second invocation succeeds.  Tested against which-key 3.x.
  (defun which-key--create-buffer-and-show
      (&optional prefix-keys from-keymap filter prefix-title)
    "Fill `which-key--buffer' with key descriptions and reformat.
Finally, show the buffer."
    (let ((start-time (current-time))
          (formatted-keys (which-key--get-bindings
                           prefix-keys from-keymap filter))
          (prefix-desc (key-description prefix-keys)))
      (cond ((null formatted-keys)
             ;; NOTE changes this, do nothing, don't message NOTE I
             ;; can't explain why this was getting triggered, based on
             ;; my experiment, it seems like this is getting run twice,
             ;; once where it fails and displays the message that used
             ;; to be here, and then again where it hits the `t`
             ;; condition below
             t
             )
            ((listp which-key-side-window-location)
             (setq which-key--last-try-2-loc
                   (apply #'which-key--try-2-side-windows
                          formatted-keys prefix-keys prefix-title
                          which-key-side-window-location)))
            (t (setq which-key--pages-obj
                     (which-key--create-pages
                      formatted-keys prefix-keys prefix-title))
               (which-key--show-page)))
      (which-key--debug-message
       "On prefix \"%s\" which-key took %.0f ms." prefix-desc
       (* 1000 (float-time (time-since start-time))))))

  (general-define-key
   :keymaps 'which-key-C-h-map
   "C-h" 'which-key-show-standard-help)

  (setq
   ;; Allow C-h to trigger which-key before it is done automatically
   which-key-show-early-on-C-h t
   ;;;; make sure which-key doesn't show normally but refreshes
   ;;;; quickly after it is triggered.
   which-key-idle-delay 1000
   which-key-idle-secondary-delay 0.1
   ;; doesn't seem to have an effect
   which-key-show-transient-maps t
   which-key-popup-type 'custom
   which-key-custom-popup-max-dimensions-function 'which-key-custom-popup-max-dimensions-function
   which-key-custom-show-popup-function 'which-key-custom-show-popup-function
   which-key-custom-hide-popup-function 'which-key-custom-hide-popup-function)

  (which-key-mode 1))

(use-package meow
  :after key-chord
  :init
  ;; copied from docs
  (defun meow-setup ()
    (setq meow-cheatsheet-layout meow-cheatsheet-layout-qwerty)
    (meow-motion-overwrite-define-key
     '("j" . meow-next)
     '("k" . meow-prev)
     '("<escape>" . ignore))
    (meow-leader-define-key
     ;; SPC j/k will run the original command in MOTION state.
     '("j" . "H-j")
     '("k" . "H-k")
     ;; Use SPC (0-9) for digit arguments.
     '("1" . meow-digit-argument)
     '("2" . meow-digit-argument)
     '("3" . meow-digit-argument)
     '("4" . meow-digit-argument)
     '("5" . meow-digit-argument)
     '("6" . meow-digit-argument)
     '("7" . meow-digit-argument)
     '("8" . meow-digit-argument)
     '("9" . meow-digit-argument)
     '("0" . meow-digit-argument)
     '("/" . meow-keypad-describe-key)
     '("?" . meow-cheatsheet))
    (meow-normal-define-key
     '("0" . meow-expand-0)
     '("9" . meow-expand-9)
     '("8" . meow-expand-8)
     '("7" . meow-expand-7)
     '("6" . meow-expand-6)
     '("5" . meow-expand-5)
     '("4" . meow-expand-4)
     '("3" . meow-expand-3)
     '("2" . meow-expand-2)
     '("1" . meow-expand-1)
     '("-" . negative-argument)
     '(";" . meow-reverse)
     ;; changed to allow for the prefix key
     '("." . meow-inner-of-thing)
     '(">" . meow-bounds-of-thing)
     '("[" . meow-beginning-of-thing)
     '("]" . meow-end-of-thing)
     '("a" . meow-append)
     '("A" . meow-open-below)
     '("b" . meow-back-word)
     '("B" . meow-back-symbol)
     '("c" . meow-change)
     '("d" . meow-delete)
     '("D" . meow-backward-delete)
     '("e" . meow-next-word)
     '("E" . meow-next-symbol)
     '("f" . meow-find)
     '("g" . meow-cancel-selection)
     '("G" . meow-grab)
     '("h" . meow-left)
     '("H" . meow-left-expand)
     '("i" . meow-insert)
     '("I" . meow-open-above)
     '("j" . meow-next)
     '("J" . meow-next-expand)
     '("k" . meow-prev)
     '("K" . meow-prev-expand)
     '("l" . meow-right)
     '("L" . meow-right-expand)
     '("m" . meow-join)
     '("n" . meow-search)
     '("o" . meow-block)
     '("O" . meow-to-block)
     '("p" . meow-yank)
     '("q" . meow-quit)
     '("Q" . meow-goto-line)
     '("r" . meow-replace)
     '("R" . meow-swap-grab)
     '("s" . meow-kill)
     '("t" . meow-till)
     '("u" . meow-undo)
     '("U" . meow-undo-in-selection)
     '("v" . meow-visit)
     '("w" . meow-mark-word)
     '("W" . meow-mark-symbol)
     '("x" . meow-line)
     '("X" . meow-goto-line)
     '("y" . meow-save)
     '("Y" . meow-sync-grab)
     '("z" . meow-pop-selection)
     '("'" . repeat)
     '("<escape>" . ignore)))

  :config
  (key-chord-define meow-insert-state-keymap "kj" 'meow-insert-exit)
  (setq meow-keypad-start-keys
        '((?c . ?c)
          (?h . ?h)
          (?x . ?x)
          ;; launch-map
          (?, . ?,)))

  ;; TODO -- would this make more sense as C-x and to use it as the
  ;; launcher?  maybe but keep this around for now
  (setq meow-keypad-leader-dispatch "C-c")

  ;; Disable expand-hint overlays after motions like e/b. The digit keys
  ;; still work as expand-by-N, but no number overlays are drawn.
  (setq meow-expand-hint-counts
        '((word . 0)
          (line . 0)
          (block . 0)
          (find . 0)
          (till . 0)
          (symbol . 0)))

  )

(defun zetta-state-evil ()
  (interactive)
  (if (fboundp 'evil-mode)
      (progn (evil-mode t) (meow-global-mode -1) (message "evil enabled"))
    (message "evil not available")))

(defun zetta-state-meow ()
  (interactive)
  (when (fboundp 'evil-mode) (evil-mode -1))
  (meow-setup)
  (meow-global-mode 1)
  (message "meow enabled"))

(defun zetta-state-emacs ()
  (interactive)
  (when (fboundp 'evil-mode) (evil-mode -1))
  (meow-global-mode -1)
  (message "emacs state enabled"))

(general-define-key
 :keymaps 'override
 "s-z m" 'zetta-state-meow
 "s-z e" 'zetta-state-evil
 "s-z E" 'zetta-state-emacs)

(defmacro defprefix (prefix name key)
  `(progn
     (define-prefix-command ',name)
     (general-define-key :keymaps ',prefix ,key ',name)))

(defprefix launch-map menu-window-map "w")
(defprefix launch-map menu-project-map "p")
(defprefix launch-map menu-lookup-map "l")
(defprefix launch-map menu-org-map "o")
(defprefix launch-map menu-run-map "r")
(defprefix launch-map menu-theme-map "t")
(defprefix launch-map menu-smerge-map "d")
(defprefix launch-map menu-iedit-map "i")
(defprefix launch-map menu-help-map "h")
(defprefix launch-map menu-vc-map "g")

;; launch-map: a prefix command bound to "," in non-insert modal states.
;; Modules bind keys to launch-map once; they become available across all
;; modal editing systems (meow, evil, emacs) automatically.
(define-prefix-command 'launch-map)
(defvar launch-key ",")

;; Used by vertico.el and multi-compile.el for insert-state bindings
(defvar zetta-modal-states-insert '(meow-insert-state-keymap))

(defvar zetta-modal-states-non-insert
  '(meow-beacon-state-keymap meow-motion-state-keymap meow-normal-state-keymap))

;; Bind launch-map in meow states immediately
(general-define-key :keymaps zetta-modal-states-non-insert launch-key 'launch-map)

;; Add evil states when/if evil loads
(with-eval-after-load 'evil
  (push 'evil-insert-state-map zetta-modal-states-insert)
  (dolist (map '(evil-normal-state-map evil-visual-state-map))
    (push map zetta-modal-states-non-insert))
  (general-define-key
   :keymaps '(evil-normal-state-map evil-visual-state-map)
   launch-key 'launch-map))

;; Bind launch map to C-, in insert states.  Compatible with meow and embark-become
(general-define-key (concat "C-" launch-key) 'launch-map)

(provide 'bootstrap-keys)
;;; bootstrap-keys.el ends here
