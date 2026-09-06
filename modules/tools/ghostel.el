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

(require 'color)
(require 'cl-lib)

(declare-function ghostel--send-encoded "ghostel" (key-name mods &optional utf8))
(declare-function ghostel--set-cursor-style "ghostel" (style visible))
(declare-function ghostel--cursor-position "ghostel-module" (term))
(defvar ghostel--term)
(declare-function evil-refresh-cursor "evil-core" (&optional state))
(defvar ghostel--copy-mode-active)

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

(defconst zetta-ghostel--ansi-names
  '("black" "red" "green" "yellow" "blue" "magenta" "cyan" "white"
    "bright-black" "bright-red" "bright-green" "bright-yellow"
    "bright-blue" "bright-magenta" "bright-cyan" "bright-white")
  "The 16 ANSI slots ghostel exposes as `ghostel-color-NAME' faces.")

(defun zetta-ghostel--relative-luminance (rgb)
  "WCAG relative luminance for RGB, a list of three 0..1 floats."
  (apply #'+ (cl-mapcar #'*
                        '(0.2126 0.7152 0.0722)
                        (mapcar (lambda (c)
                                  (if (<= c 0.03928)
                                      (/ c 12.92)
                                    (expt (/ (+ c 0.055) 1.055) 2.4)))
                                rgb))))

(defun zetta-ghostel--contrast (a b)
  "WCAG contrast ratio between colour names A and B, or nil if unknown."
  (let ((ra (color-name-to-rgb a)) (rb (color-name-to-rgb b)))
    (when (and ra rb)
      (let ((la (+ 0.05 (zetta-ghostel--relative-luminance ra)))
            (lb (+ 0.05 (zetta-ghostel--relative-luminance rb))))
        (/ (max la lb) (min la lb))))))

(defun zetta-ghostel--legible (color bg)
  "Nudge COLOR's lightness until it reads against BG, preserving hue.
Terminal colours are content, not chrome -- red must stay red in a diff --
so only lightness moves.  Walks away from BG in 5% steps, giving up after
enough tries to have crossed the whole range."
  (let ((target 4.0)
            (darken (> (zetta-ghostel--relative-luminance (color-name-to-rgb bg)) 0.5))
            (cur color)
            (n 0))
    (while (and (< n 14)
                (let ((c (zetta-ghostel--contrast cur bg)))
                  (and c (< c target))))
      (setq cur (if darken
                    (color-darken-name cur 5)
                  (color-lighten-name cur 5))
            n (1+ n)))
    cur))

(defun zetta-ghostel-apply-ansi-palette ()
  "Make ghostel's 16 ANSI colours legible against the current theme.
The faces inherit `term-color-*', which themes pick for a dark canvas, so
on a light theme \"white\" arrives as #ffffff -- invisible -- and \"yellow\"
as a muddy brown.  This is the same defect modules/term/vterm.el patches by
hand for `vterm-color-yellow\='; here every slot is checked and only the
ones that actually fail get moved.

Registered on `brushup-styles\=', so it re-runs per theme change.  Hues are
untouched: only lightness shifts, and only far enough to reach a 4:1 ratio."
  (let ((bg (or (and (boundp 'brushup-bg) brushup-bg)
                (face-background 'default nil t))))
    (when (and bg (color-name-to-rgb bg))
      (dolist (name zetta-ghostel--ansi-names)
        (let ((face (intern (format "ghostel-color-%s" name))))
          (when (facep face)
            (let* ((base (face-attribute face :foreground nil 'default))
                   (base (and (stringp base) (color-name-to-rgb base) base)))
              (when base
                (let ((fixed (zetta-ghostel--legible base bg)))
                  (unless (equal fixed base)
                    (set-face-attribute face nil :foreground fixed)))))))))))

;; Appended: `brushup-init' recomputes the palette late in `brushup-styles',
;; and a prepended style would read the previous theme's background.
(with-eval-after-load 'brushup
  (add-to-list 'brushup-styles '(zetta-ghostel-apply-ansi-palette) t))
(with-eval-after-load 'ghostel (zetta-ghostel-apply-ansi-palette))

(defun zetta-ghostel--restore-cursor-column (&rest _)
  "Put point at the terminal's cursor column even on a trimmed trailing blank.

The renderer trims trailing blank cells off every row so the buffer does
not carry the full-width viewport padding (src/render.zig), and then caps
point at end-of-line -- \"so we never jump past it into the next row (can
happen when cursor is on a trimmed trailing blank)\".

The consequence while typing: press space at the end of a word and the
cursor cannot advance, because the space was trimmed and there is no
column to land on.  It only springs forward once a non-blank character
arrives and the row stops being trimmed.

Point's LINE is already correct after a redraw -- only the column was
clamped -- so pad the current row out to the reported column with the
spaces the terminal grid actually holds.  Undo is suppressed: this is
rendered output, not user text."
  (when (and ghostel--term (not (bound-and-true-p ghostel--copy-mode-active)))
    (let ((col (car (ghostel--cursor-position ghostel--term))))
      (when (and col (> col (current-column)))
        (let ((inhibit-read-only t)
              (inhibit-modification-hooks t)
              (buffer-undo-list t))
          (move-to-column col t))))))

(defun zetta-ghostel--evil-owns-cursor (orig-fn style visible)
  "Keep evil's state cursor from being clobbered by the terminal.
`ghostel--set-cursor-style' assigns `cursor-type' straight from the style
the terminal reports, so anything emitting DECSCUSR -- zsh's line editor,
tmux, a full-screen TUI -- overwrites the shape evil just set.  Entering
insert state therefore flashes the narrow bar and then turns into a box on
the next repaint.

Unlike `evil-ghostel--override-cursor-style', this does NOT exempt
alt-screen mode (DEC 1049): tmux holds the alt screen for its entire
session, which is the normal working state here, so exempting it would
leave the cursor terminal-controlled essentially always.

An explicit hide request is still honoured -- only the shape is taken
over, never visibility."
  (if (and visible
           (bound-and-true-p evil-local-mode)
           (fboundp 'evil-refresh-cursor)
           (not (bound-and-true-p ghostel--copy-mode-active)))
      (evil-refresh-cursor)
    (funcall orig-fn style visible)))

(defun zetta-ghostel-send-up ()
  "Send the up-arrow key to the ghostel terminal."
  (interactive)
  (ghostel--send-encoded "up" ""))

(defun zetta-ghostel-send-down ()
  "Send the down-arrow key to the ghostel terminal."
  (interactive)
  (ghostel--send-encoded "down" ""))

(use-package ghostel
  ;; `etc' carries the shell-integration scripts (ghostel injects ZDOTDIR
  ;; pointing at etc/shell-integration/zsh).  Elpaca's default :files does
  ;; NOT link it into the build directory, so `ghostel--start-process' finds
  ;; no integration dir and silently skips it -- taking OSC 7 directory
  ;; tracking, OSC 2 title tracking and OSC 133 prompt marks with it.
  :ensure (ghostel :host github :repo "dakra/ghostel"
                   :files (:defaults "etc"))
  :commands (ghostel ghostel-project ghostel-other)

  :init
  ;; Item 1 -- clipboard from inside the terminal.
  ;; tmux is already set to `set-clipboard external', i.e. it forwards OSC 52
  ;; out to the host terminal rather than swallowing it; ghostel was dropping
  ;; it at the far end.  With this on, a copy inside tmux/Claude Code/any TUI
  ;; reaches the Emacs kill ring and the system clipboard.
  ;; Note this lets any program in the terminal write the clipboard.
  (setq ghostel-enable-osc52 t)

  :config
  ;; Item 3 -- make ghostel a first-class project terminal.
  ;; NOT by substituting `project-eshell' the way modules/term/vterm.el does:
  ;; both would be claiming the same `e' slot, so whichever module loaded
  ;; last would silently win.  Take an unused key instead, which leaves both
  ;; eshell and vterm's substitution intact.
  (with-eval-after-load 'project
    (keymap-set project-prefix-map "t" #'ghostel-project)
    (unless (assq 'ghostel-project project-switch-commands)
      ;; keep `project-any-command' ("Other") last in the menu
      (let ((tail (assq 'project-any-command project-switch-commands)))
        (setq project-switch-commands
              (if tail
                  (append (remq tail project-switch-commands)
                          (list '(ghostel-project "Ghostel") tail))
                (append project-switch-commands
                        (list '(ghostel-project "Ghostel"))))))))

  (advice-add 'ghostel--set-cursor-style :around
              #'zetta-ghostel--evil-owns-cursor)
  (advice-add 'ghostel--redraw :after
              #'zetta-ghostel--restore-cursor-column)

  ;; Item 5 -- let space-tree's navigation keys through.
  ;; `modules/ui/spacetree.el' binds M-<tab> (go-to-last-space),
  ;; M-S-<tab> (switch-space-by-name) and C-M-<tab> (go-right) globally,
  ;; but ghostel's special-keys loop binds every <tab> variant across the
  ;; mods `S- C- M- C-S- M-S- C-M-', so in a ghostel buffer they were
  ;; reaching `ghostel--send-event' instead.  That loop -- unlike the
  ;; C-<letter> and M-<letter> loops right beside it -- never consults
  ;; `ghostel-keymap-exceptions', so there is no supported opt-out.
  ;; vterm never bound these at all, which is why it worked there.
  ;;
  ;; Unbind rather than re-bind to the space-tree commands: lookup then
  ;; falls through to whatever is global, so this survives any remap in
  ;; spacetree.el.  C-M-S-<tab> (go-left) is absent from ghostel's mod
  ;; list and already reached Emacs, so it is not listed here.
  ;; To send a literal M-TAB to the program, use C-c C-q
  ;; (`ghostel-send-next-key').
  (dolist (key '("M-<tab>" "M-S-<tab>" "C-M-<tab>"))
    (keymap-unset ghostel-mode-map key t))

  :general
  (
   :states '(insert)
   :keymaps '(ghostel-mode-map)
   "C-s" 'ghostel--send-event
   ;; Item 4 -- C-x is deliberately in `ghostel-keymap-exceptions', i.e. meant
   ;; to reach Emacs.  Sending it stole C-x b / C-x o / C-x 0 inside the
   ;; terminal, which mattered less when normal state barely worked here.
   ;; To send a literal C-x to the program, use C-c C-q (ghostel-send-next-key).
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
