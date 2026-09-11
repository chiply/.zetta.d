;;; evil-tty-cursor.el --- evil state on a tty frame: cursor shape, hl-line -*- lexical-binding: t; -*-

;; Emacs cannot shape a tty cursor itself.  `cursor-type' (and so evil's
;; per-state cursor, `evil-insert-state-cursor' = (bar . 2) here) only
;; reaches a window system; on a tty the cursor is the terminal's, and the
;; one way to change it is the DECSCUSR escape (CSI n SP q: 1/2 block, 3/4
;; underline, 5/6 bar), which Emacs never sends.  Seen 2026-09-11 from
;; Blink over mosh to the hub daemon: evil on, tty frames' `cursor-type'
;; nil, the cursor a block in every state.
;;
;; Two things here, both for tty frames only (`display-graphic-p' is
;; checked per frame, so a daemon serving GUI and tty frames at once is
;; unaffected on the GUI side):
;;
;; 1. Send DECSCUSR on every cursor refresh: steady bar in insert (and
;;    emacs) state, steady underline in replace, steady block elsewhere.
;;    Rides on `evil-refresh-cursor', which evil runs on every state change
;;    and on every window-configuration change, so switching to a window
;;    whose buffer is in another state also re-sends.  De-duplicated per
;;    terminal, so a refresh that changes nothing writes nothing.  Over
;;    mosh the escape is dropped (mosh 1.4 has no DECSCUSR:
;;    mobile-shell/mosh#1355 is still open) and this is harmless; over
;;    plain ssh, and on any future mosh with #1355 merged, it is the fix.
;;
;; 2. For the path mosh cannot strip, carry the state in the text: the
;;    `hl-line' background steps up one rung of the brushup ladder in
;;    insert state and rests on the page otherwise.  Frame-local, so a GUI
;;    frame on the same daemon keeps its underline-only `hl-line'
;;    (ui/hl-line.el).  The evil tag on the mode line does the same job in
;;    words (`zetta-telephone-line-evil-tag-faces').  Prominence only, no
;;    hue names a state.
;;
;; Verify from Blink both ways: mosh (expect the hl-line step and the
;; tag only) and ssh (expect the bar as well).

(defcustom zetta-evil-tty-cursor t
  "When non-nil, send DECSCUSR so a tty cursor follows the evil state."
  :type 'boolean :group 'zetta)

(defcustom zetta-evil-tty-hl-line t
  "When non-nil, step `hl-line' up the ink ladder in insert state on a tty."
  :type 'boolean :group 'zetta)

(defcustom zetta-evil-tty-hl-line-insert-rung 'brushup-bg-2
  "Brushup variable holding the `hl-line' background for insert state.
One rung is not always visible through a 256-colour path; two is."
  :type 'symbol :group 'zetta)

(defun zetta-evil-tty--state-shape ()
  "DECSCUSR parameter for the current evil state (steady variants)."
  (cond ((bound-and-true-p evil-replace-state-minor-mode) 4)
        ((or (bound-and-true-p evil-insert-state-minor-mode)
             (bound-and-true-p evil-emacs-state-minor-mode)) 6)
        (t 2)))

(defun zetta-evil-tty--send-shape (frame shape)
  "Send DECSCUSR SHAPE to FRAME's terminal unless it already shows it."
  (let ((term (frame-terminal frame)))
    (unless (eql (terminal-parameter term 'zetta-evil-tty-cursor-shape) shape)
      (set-terminal-parameter term 'zetta-evil-tty-cursor-shape shape)
      (ignore-errors
        (send-string-to-terminal (format "\e[%d q" shape) term)))))

(defun zetta-evil-tty--hl-line (frame)
  "Set FRAME's `hl-line' background from the evil state, frame-locally."
  (when (and (facep 'hl-line) (boundp zetta-evil-tty-hl-line-insert-rung))
    (set-face-attribute
     'hl-line frame
     :background (if (bound-and-true-p evil-insert-state-minor-mode)
                     (symbol-value zetta-evil-tty-hl-line-insert-rung)
                   'unspecified))))

(defun zetta-evil-tty-refresh (&rest _)
  "Reflect the evil state on the selected frame when it is a tty frame.
Runs after `evil-refresh-cursor', so wherever evil would have reshaped a
GUI cursor this reshapes the terminal's instead."
  (let ((frame (selected-frame)))
    (unless (display-graphic-p frame)
      (when zetta-evil-tty-cursor
        (zetta-evil-tty--send-shape frame (zetta-evil-tty--state-shape)))
      (when zetta-evil-tty-hl-line
        (zetta-evil-tty--hl-line frame)))))

(defun zetta-evil-tty-reset (frame)
  "Hand FRAME's terminal its default cursor back before the frame goes."
  (unless (display-graphic-p frame)
    (let ((term (frame-terminal frame)))
      (when (terminal-parameter term 'zetta-evil-tty-cursor-shape)
        (set-terminal-parameter term 'zetta-evil-tty-cursor-shape nil)
        (ignore-errors (send-string-to-terminal "\e[0 q" term))))))

(with-eval-after-load 'evil
  (advice-add 'evil-refresh-cursor :after #'zetta-evil-tty-refresh)
  (add-hook 'delete-frame-functions #'zetta-evil-tty-reset))

;;; evil-tty-cursor.el ends here
