;; -*- lexical-binding: t; -*-
;;
;; ~/.zetta.el — HEADLESS profile for Zetta Emacs
;;
;; A terminal-only, secret-free Zetta for a machine with no window
;; system, no SVG support and no toolchain beyond gcc: the kb-hub VPS
;; (apt emacs-nox 29 on Ubuntu 24.04, reached from a phone or tablet over
;; ssh/mosh and tmux).  Stated use: org editing, agenda, capture and
;; search over ~/kb, plus git.  Anything else is added by need, and every
;; addition has to pass CI's emacs-nox row, which loads exactly this file.
;; The 2026-09-11 pass (~/headless-hub-plan.org, the owner's keep-out
;; sheet) added the grep/replace/vc/dired/git-history tools, bookmarks,
;; dogears, olivetti, eww, compile, treesit-fold, magneto and ghostel.
;;
;; Install it as ~/.zetta.el BEFORE the first build: `bin/zetta install'
;; copies the full-profile example into place when the file is missing,
;; and `bin/zetta build' refuses to run without one.  The hub bootstrap
;; (~/.files/hub/bootstrap-hub.sh) does this.
;;
;; Parser rule (bootstrap-modules.el): within one category the list is
;; either all inclusions or all exclusions, never both.  The SVG chrome
;; (svg-line, svg-margin, modeline-svg, header-line-svg, tab-bar-svg,
;; tab-line-svg, svg-lib, poimap) is deliberately NOT listed here: the
;; capability predicate in `zetta-module-conditions' skips those files
;; wherever `(image-type-available-p 'svg)' is nil, so this profile stays
;; right if the box ever gets an SVG-capable build.

;;; ————————————————————————————————————————————————
;;; Native compilation on a small box
;;; ————————————————————————————————————————————————

;; One (or two) cores: a single async compile worker leaves the daemon
;; usable while the first days of deferred compilation run.
(setq native-comp-async-jobs-number 1)

;; Lint findings in third-party code are not actionable; log them to
;; *Warnings* without popping a window into the tty client.
(setq native-comp-async-report-warnings-errors 'silent)

;;; ————————————————————————————————————————————————
;;; Keep Emacs droppings out of the synced tree (~/kb)
;;; ————————————————————————————————————————————————

;; The shared .stignore already excludes *~, *# and .#*; this keeps them
;; from being written into the folder in the first place.
(let ((backups (expand-file-name ".data/backups/" user-emacs-directory))
      (autosaves (expand-file-name ".data/autosaves/" user-emacs-directory)))
  (make-directory backups t)
  (make-directory autosaves t)
  (setq backup-directory-alist `(("." . ,backups))
        auto-save-file-name-transforms `((".*" ,autosaves t))
        create-lockfiles nil
        backup-by-copying t
        delete-old-versions t))

;; Customize writes go to init.el when `custom-file' is unset, and tramp
;; saves its connection-local profiles through Customize on its own --
;; measured 2026-09-11: the hub's checkout was dirty (init.el reflowed)
;; after one session, which blocks the next `git pull'.  Keep the
;; per-machine saves in .data/ instead; the block already in init.el
;; still evaluates, so nothing is lost.
(setq custom-file (expand-file-name ".data/custom.el" user-emacs-directory))

;;; ————————————————————————————————————————————————
;;; Terminal
;;; ————————————————————————————————————————————————

;; Touch taps on a tablet move point and scroll only with this on.
(xterm-mouse-mode 1)

;; The `kj' insert-state exit is a key-chord with a 50 ms window
;; (bootstrap-keys.el).  Over mosh from a tablet two keystrokes may not
;; land that close together; if `kj' misfires, widen it here:
;; (setq key-chord-two-keys-delay 0.15)

;; Clipboard: OSC 52.  Inside tmux the frame's TERM is tmux-256color, so
;; Emacs runs `terminal-init-tmux' (term/tmux.el, Emacs 28+), which hands
;; xterm.el the fixed list below instead of probing the terminal; its
;; default is (modifyOtherKeys) only, so kills never left the daemon
;; (measured 2026-09-11: the live frame had no `xterm--set-selection').
;; `setSelection' makes every kill an OSC 52 write; tmux 3.4 forwards it
;; (`set-clipboard' defaults to external) and Blink puts it on the iPad
;; clipboard.  A terminal that ignores OSC 52 ignores the escape.
;; `getSelection' stays off: a yank would wait on a reply the terminal
;; may never send.  modifyOtherKeys is what lets C-, reach Emacs at all.
(setq xterm-tmux-extra-capabilities '(modifyOtherKeys setSelection))

;;; ————————————————————————————————————————————————
;;; Evil on a tty
;;; ————————————————————————————————————————————————

;; On a tty the Tab key and C-i are the same byte (0x09): there is no
;; separate <tab> event the way there is in a GUI frame.  Evil binds C-i
;; to `evil-jump-forward' in `evil-motion-state-map' (`evil-want-C-i-jump'
;; defaults to t), and a state map outranks `org-mode-map', so in normal
;; state Tab ran the jump instead of `org-cycle' (measured 2026-09-11 in
;; ~/kb/inbox.org).  Nothing in the tmux/Blink chain can separate them:
;; even with modifyOtherKeys on, xterm.el decodes a modified C-i back to
;; the character 9.  Read before evil loads, this leaves C-i alone and Tab
;; falls through to the major mode everywhere; the jump keeps its C-o
;; partner on C-M-o (ESC C-o, which always arrives).
(setq evil-want-C-i-jump nil)
(with-eval-after-load 'evil
  (define-key evil-motion-state-map (kbd "C-M-o") #'evil-jump-forward))

;; Same family: C-m is RET and C-[ is ESC on a tty.  Evil handles ESC
;; itself (`evil-esc-mode'); RET is not rebound by evil; the config binds
;; neither C-m nor C-[ anywhere (checked 2026-09-11).

;;; ————————————————————————————————————————————————
;;; Super and the chords with no byte (tty frames only)
;;; ————————————————————————————————————————————————

;; Goal: the same chords in GUI and headless.  The real Cmd key stays.
;; Three routes, all landing on the same `s-' events the config binds:
;;
;; - Blink (iPad), mosh or ssh: Cmd in the "8-bit" modifier role (Config >
;;   Keyboard > Modifiers) sends the character +128 -- Cmd-b is U+00E2, as
;;   one UTF-8 character; mosh, tmux and Emacs's utf-8 keyboard coding all
;;   pass it through -- and the first loop below maps each Latin-1
;;   character U+00A1..U+00FE back to `s-<char>' (case preserved, so
;;   Cmd-Shift-b is `s-B' as in the GUI).  The cost: those characters
;;   cannot be TYPED while the map is active (é is s-i, ñ is s-q, ü is
;;   s-u, ç is s-g).  Narrow the range to the characters the config binds
;;   if typing accents on the hub ever matters.  Bracketed paste is read
;;   with `read-event', which does not consult `input-decode-map', so a
;;   pasted "é" is still text.
;; - A Mac terminal (Ghostty, kitty, WezTerm, iTerm2): the kitty keyboard
;;   protocol, core/kkp.el.
;; - Anything else: `C-c s <key>' is `s-<key>', the built-in modifier
;;   prefix (`event-apply-super-modifier', the same thing `C-x @ s' does)
;;   on a shorter chord.  Two keystrokes, zero terminal cooperation.
;;
;; The chords with no byte at all -- C-, C-tab C-S-<letter> -- come as
;; xterm's modifyOtherKeys encoding, injected by Blink "Custom presses"
;; (the enable request Emacs sends dies in mosh, so the client injects
;; the encoding itself).  xterm.el decodes that table for punctuation
;; and tab; the letters (C-S-a/d/s/w windmove, C-S-t, C-S-r...) need the
;; second loop.  The Blink half -- modifier roles, shortcut reassignments,
;; the custom-press byte table -- is in hub-issues.org.
;;
;; `input-decode-map' and `local-function-key-map' are terminal-local, so
;; `tty-setup-hook' is the right place: it runs once per tty terminal,
;; after term/xterm.el's own decode table, and never for a GUI frame.

(defun zetta-headless-tty-keys ()
  "Decode the 8-bit Super role, C-S-<letter>, and bind the Super prefix."
  ;; Cmd as the 8-bit role: U+00A1..U+00FE -> s-<char>.
  (let ((c #xA1))
    (while (<= c #xFE)
      (define-key input-decode-map (vector c)
                  (vector (logior (- c 128) #x800000)))
      (setq c (1+ c))))
  ;; C-S-<letter> in both modifyOtherKeys forms (modifier 6 = Ctrl+Shift;
  ;; xterm sends the shifted keysym, so the code is the uppercase letter).
  (dotimes (i 26)
    (let* ((code (+ ?A i))
           (event (kbd (format "C-S-%c" (+ ?a i)))))
      (define-key input-decode-map (format "\e[27;6;%d~" code) event)
      (define-key input-decode-map (format "\e[%d;6u" code) event)))
  ;; The floor: C-c s <key> reads as s-<key> on any terminal.
  (define-key local-function-key-map (kbd "C-c s")
              #'event-apply-super-modifier))

(add-hook 'tty-setup-hook #'zetta-headless-tty-keys)

;; ghostel's terminal engine is a dynamic module (libghostty-vt, built
;; with zig, which this box does not have).  Its releases carry a
;; prebuilt aarch64-linux .so for the pinned module version, so fetch
;; that on first use instead of prompting in the tty.
(setq ghostel-module-auto-install 'download)

;;; ————————————————————————————————————————————————
;;; Secrets: none
;;; ————————————————————————————————————————————————

;; No 1Password CLI on this box, so no credential can resolve.  Say so
;; explicitly rather than let every lookup fall through to a backend
;; that is not there.  The modules that need secrets (elfeed, mastodon,
;; forge, gptel) are simply absent from the lists below; ~/.private.el
;; on this machine can be a single ";;".
(setq auth-sources nil)

;;; ————————————————————————————————————————————————
;;; Modules
;;; ————————————————————————————————————————————————

(zetta-modules!
 ;; image.el is pixel plumbing for a window system.
 :core (-image)
 ;; consult-gh and consult-omni declare Package-Requires emacs 29.4, so
 ;; elpaca refuses to build them on the hub's 29.3 (measured: CI nox row).
 ;; Neither is hub work anyway: gh plus credentials, and web search.
 :completion (-consult-gh -consult-omni)
 ;; Icons need a GUI font, the font and pixel modules a window system,
 ;; the toys a place to draw.  (SVG chrome: see the header.)
 :ui (-all-the-icons -all-the-icons-dired -all-the-icons-ibuffer
      -fontaine -ligature -unicode-fonts -default-text-scale -face
      -ultra-scroll -minimap -modern-fringes -image-mode
      -nyan-mode -parrot)
 :editor (-evil-fringe-mark)
 :lang
 ;; Inclusion lists: nothing reaches the hub without being asked for.
 ;; Still out, by the owner's sheet: vterm (cmake + libvterm; tmux is
 ;; the terminal), pdf-tools (make + poppler), whisper, the macOS
 ;; helpers (osx-lib, spotlight, say, signel, command-palette, alert),
 ;; everything that needs a token or a backend (forge, gha, jira, slack,
 ;; ai, irs, the feed and mail readers), the dev stack (lsp, dap,
 ;; flycheck, docker, kubernetes, the compile front-ends), and the toys.
 :tools (magit dired git-gutter
         ;; search and edit-in-place
         grep replace wgrep
         ;; git history beyond magit; git-link and browse-at-remote
         ;; need a remote, harmless without one
         vc git-link browse-at-remote git-timemachine blamer
         ;; dired.el already reaches for both
         dired-subtree dired-ranger
         ;; M-x compile for the ~/kb scripts; treesit-fold is pure elisp
         ;; once the grammars are installed (python, tsx, typescript)
         compile treesit-fold
         magneto
         ;; terminal in a buffer; the module is downloaded, see above
         ghostel)
 :app (hyperbole hywiki-alias hywiki-graph
       ;; bookmark+ is not a module (modules/app/disabled/), so the
       ;; bookmark row of the sheet is the built-in plus the two helpers
       bookmark bookmark-view bookmark-in-project
       dogears
       ;; prose width on a small screen
       olivetti
       ;; activities.el is a commented-out stub today; listed so it
       ;; comes along the day it is enabled
       activities
       ;; network, no key
       define-word
       eww)
 ;; pdf-tools builds epdfinfo on first PDF open; pdfnote goes with it;
 ;; the image and chart modules have nothing to draw on.
 :org (-pdf-tools -pdfnote -org-image -org-gantt -org-timegrid)
 ;; :term omitted: tmux is the shell here, and term/shell.el hardcodes zsh.
 )
