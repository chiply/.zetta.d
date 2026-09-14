;;; kkp.el --- kitty keyboard protocol on tty frames -*- lexical-binding: t; -*-

;; A terminal has no Super modifier: the physical Cmd key never reaches a
;; tty Emacs, and every `s-' binding in this config is unreachable there.
;; The kitty keyboard protocol carries it.  kkp enables the protocol from
;; `tty-setup-hook' on any terminal that answers the capability query
;; (Ghostty, kitty, WezTerm, iTerm2 3.5+; Terminal.app does not speak it)
;; and decodes super and hyper natively, so the Cmd chords work unchanged
;; from a Mac terminal, local or over ssh.  Emacs 31 has no native
;; support (checked NEWS).
;;
;; Two conditions on the terminal side: it must not consume the chord
;; itself (Ghostty binds Cmd-C/V/N/T/W/Q/digits/+/-/0 by default; unbind
;; per key in its config), and tmux in the path must relay the protocol
;; -- tmux 3.4 relays the CSI u form, the kitty flags only partly, so
;; ssh-into-tmux needs a test; a plain ssh session without tmux is clean.
;;
;; `:if (not (display-graphic-p))': the headless profile, and any daemon
;; at init time (the daemon's initial frame is a terminal frame), which is
;; what gives `emacsclient -t' on the Mac the same keys.  A GUI session
;; started directly skips it, install included.  The mode does nothing on
;; a GUI frame either way.  Blink on the iPad does not speak the protocol;
;; its Cmd travels as the 8-bit role instead (templates/zetta.headless.el).

(use-package kkp
  :if (not (display-graphic-p))
  :config
  (global-kkp-mode 1))

;;; kkp.el ends here
