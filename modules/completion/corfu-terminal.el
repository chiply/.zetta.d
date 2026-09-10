;;; corfu-terminal.el --- corfu popups on a tty -*- lexical-binding: t; -*-

;; Corfu draws its candidate list in a child frame, and a terminal frame
;; on Emacs 29 or 30 cannot have one: `corfu-mode' is on but nothing ever
;; pops.  corfu-terminal swaps in an overlay-drawn popup (popon) for
;; exactly those frames.  It checks `display-graphic-p' on every show and
;; hide, so on the GUI daily driver, and in a daemon's GUI frames, it is
;; a no-op -- which is why it loads on both profiles rather than only on
;; the headless one: `emacsclient -t' into any daemon gets a popup.
;;
;; Emacs 31 grows native tty child frames, at which point this package is
;; redundant there but still harmless; drop it once nothing older than 31
;; is a target.

(use-package corfu-terminal
  :after corfu
  :config
  (corfu-terminal-mode 1))

;;; corfu-terminal.el ends here
