;;; ghostel.el --- Configure ghostel (Ghostty terminal integration) -*- lexical-binding: t; -*-

;; Ghostel is NOT a drop-in for vterm's key API.  vterm generates a
;; `vterm-send-C-<key>' command family with the `vterm-define-key' macro;
;; ghostel has no equivalent, so `ghostel-send-C-s', `ghostel-send-escape',
;; `ghostel-send-up' and friends do not exist.
;;
;; Instead, every modified or special key goes through
;; `ghostel--send-event', which decomposes `last-command-event' into a key
;; name plus modifier list and hands them to the ghostty key encoder.
;; `ghostel--self-insert' is strictly the [remap self-insert-command] path:
;; it calls `string' on the raw event, so any modified key fails
;; `characterp' (C-, is event 67108908 -> "Wrong type argument: characterp").
;;
;; Keys whose pressed binding differs from the key to transmit (C-k -> up)
;; need a wrapper around `ghostel--send-encoded', the same primitive the
;; package's own evil layer uses.

(declare-function ghostel--send-encoded "ghostel" (key-name mods &optional utf8))

;; Defined ahead of the `use-package' form deliberately: general's
;; use-package handler emits an `(autoload ... "ghostel")' stub for every
;; command it binds, guarded by `fboundp'.  Defining these first keeps
;; general from pointing them at a file that does not define them.
(defun zetta-ghostel-send-event-with-text ()
  "Send the current key event, telling the encoder what text the key makes.
Ghostty's key encoder cannot encode a key with no legacy control-code
mapping -- C-, C-. C-; C-- C-= -- unless it is given the unmodified key's
text.  `ghostel--send-event' never passes it, so those keys silently send
nothing at all.  With the hint, C-, encodes as CSI-u (ESC [ 44 ; 5 u).

Use this only for such keys.  Plain `ghostel--send-event' is correct for
everything else, including meta keys: those fail in the encoder too, but
`ghostel--raw-key-sequence' catches them and builds the ESC prefix, and a
text hint would defeat that and send a bare unprefixed character."
  (interactive)
  (let ((base (event-basic-type last-command-event))
        (mods (event-modifiers last-command-event)))
    (when (characterp base)
      (ghostel--send-encoded
       (string base)
       (mapconcat (lambda (m)
                    (pcase m
                      ('shift "shift") ('control "ctrl") ('meta "meta")
                      ('hyper "hyper") ('super "super") (_ nil)))
                  mods ",")
       (string base)))))

(defun zetta-ghostel-send-up ()
  "Send the up-arrow key to the ghostel terminal."
  (interactive)
  (ghostel--send-encoded "up" ""))

(defun zetta-ghostel-send-down ()
  "Send the down-arrow key to the ghostel terminal."
  (interactive)
  (ghostel--send-encoded "down" ""))

(use-package ghostel
  :ensure (ghostel :host github :repo "dakra/ghostel")
  :commands (ghostel ghostel-project ghostel-other)

  :general
  (
   :states '(insert)
   :keymaps '(ghostel-mode-map)
   "C-s" 'ghostel--send-event
   "C-x" 'ghostel--send-event
   "C-," 'zetta-ghostel-send-event-with-text
   "<escape>" 'ghostel--send-event
   "C-u" 'universal-argument
   )

  (
   :states '(normal)
   :keymaps '(ghostel-mode-map)
   "C-b" 'ghostel--send-event
   "C-," 'zetta-ghostel-send-event-with-text
   "C-k" 'zetta-ghostel-send-up
   "C-j" 'zetta-ghostel-send-down
   )
  )
;;; ghostel.el ends here
