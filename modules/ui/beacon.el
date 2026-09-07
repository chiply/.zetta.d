;;; beacon.el --- Configure beacon -*- lexical-binding: t; -*-

;; The beacon answers one question -- "where did point just go?" -- so it
;; earns its keep exactly when a command moves point somewhere you were not
;; looking, and is noise the rest of the time.  Two mechanisms, because no
;; one of them covers both halves of that:
;;
;;   DISTANCE  `beacon-blink-when-point-moves-vertically' catches any jump
;;             far enough to lose the cursor, including from commands nobody
;;             thought to list.
;;   COMMAND   `zetta-beacon-blink-after-commands' catches the disorienting
;;             SHORT jumps -- an avy hop across the same screen, a search
;;             landing two lines down -- which no distance threshold can see.

(defcustom zetta-beacon-palette-rung 'brushup-bg-5
  "Palette rung the beacon flashes in.

A rung rather than a colour because the background ladder always recedes
AWAY from `brushup-bg', whichever direction the theme goes: under a light
theme these are darker than the page, under a dark one lighter.  So one
value reads correctly in both, where a literal colour would be invisible in
half the themes here.

Lower rungs are subtler, higher ones brighter."
  :type 'symbol :group 'zetta)

(defcustom zetta-beacon-blink-lines 4
  "Blink when a command moves point this many lines or more.
nil disables the distance trigger.  Ordinary line motion never reaches it --
one line at a time is one line per command -- and `beacon-dont-blink-commands'
excludes the built-in movement commands outright."
  :type '(choice (const :tag "Off" nil) integer) :group 'zetta)

(defcustom zetta-beacon-blink-after-commands
  '(;; evil search and long motions
    evil-search-next evil-search-previous
    evil-ex-search-next evil-ex-search-previous
    evil-goto-line evil-goto-first-line
    evil-jump-forward evil-jump-backward
    evil-window-top evil-window-bottom
    ;; avy -- the whole point of it is landing somewhere you were not looking
    avy-goto-char-timer avy-goto-line avy-goto-word-1 avy-goto-char-2
    ;; consult.  Deliberately the COMMANDS and not `consult--jump': that runs
    ;; for every preview candidate too, so it would strobe as you move down
    ;; the completion list.
    consult-line consult-imenu consult-ripgrep consult-goto-line
    ;; definitions, references, and coming back
    xref-find-definitions xref-find-references xref-go-back
    pop-global-mark pop-to-mark-command dogears-go imenu org-goto
    ;; isearch
    isearch-exit isearch-repeat-forward isearch-repeat-backward
    ;; plain far motion
    goto-line beginning-of-buffer end-of-buffer)
  "Commands after which the beacon flashes, however far point moved.

Scrolling commands are deliberately absent: `beacon-blink-when-window-scrolls'
is off here because a flash on every page is distracting, and listing the
scroll commands would reintroduce exactly that."
  :type '(repeat symbol) :group 'zetta)

(defun zetta-beacon-apply-palette ()
  "Take `beacon-color' from the theme, per `zetta-beacon-palette-rung'.
A string, so beacon reads it with `color-values' rather than treating it as
a brightness fraction of plain white or black -- which is what a number
means to it, and what made the beacon theme-blind before."
  (when (boundp zetta-beacon-palette-rung)
    (setq beacon-color (symbol-value zetta-beacon-palette-rung))))

(defun zetta-beacon--blink (&rest _)
  "Flash the beacon, ignoring the advised command's arguments."
  (when (bound-and-true-p beacon-mode)
    (beacon-blink)))

(defun zetta-beacon-install-blink-advice ()
  "Advise every command in `zetta-beacon-blink-after-commands' to flash.

Advice rather than a `post-command-hook' test: this module was disabled once
for lag, and a hook would pay a check after every command in the session
where advice costs nothing until one of these actually runs.

Undefined commands are advised anyway -- `advice-add' keeps the advice
through a later `defun' -- so packages that have not loaded yet need no
`with-eval-after-load' of their own."
  (dolist (cmd zetta-beacon-blink-after-commands)
    (advice-add cmd :after #'zetta-beacon--blink)))

(use-package beacon
  :custom
  (beacon-blink-duration 0.2)                    ; fast blink
  (beacon-blink-when-window-scrolls nil)         ; distracting, so remove
  (beacon-blink-when-point-moves-horizontally nil)
  :config
  (setq beacon-blink-when-point-moves-vertically zetta-beacon-blink-lines)
  ;; Once on load as well as on every theme change: `brushup-styles' may
  ;; already have run before this package existed.
  (zetta-beacon-apply-palette)
  (zetta-beacon-install-blink-advice)
  ;; Previously disabled here, with the note "stops working after a while,
  ;; laggy" -- and hl-line.el still records beacon as the reason IT stays
  ;; off.  Enabled by request; if the lag returns, those two notes are where
  ;; the history is.
  (beacon-mode 1)
  :brushup
  (add-to-list 'brushup-styles '(zetta-beacon-apply-palette)))
;;; beacon.el ends here
