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
(when (file-exists-p custom-file)
  (load custom-file nil 'nomessage))

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
