;;; terminals.el --- Lean terminal buffers -*- lexical-binding: t; -*-

;; After James Cherti, "Why your Emacs terminal is slow and how to fix it"
;; (2026-09-14).  A terminal buffer takes output in bursts and redraws on
;; each, and everything that runs per keystroke or per change in an
;; ordinary buffer -- paren matching, electric pairs, the current-line
;; highlight, completion, undo recording, syntactic fontification -- runs
;; on every burst here, for nothing: the program on the other end does its
;; own colours, its own pairing, its own history.  One function for the four
;; emulators switches that machinery off in the buffer.
;;
;; From `after-change-major-mode-hook', late, and not from the mode hooks:
;; every globalized minor mode (corfu, anzu, evil-surround, blamer, the
;; trailing-newline indicator, yasnippet) turns itself on from that same
;; hook, which `run-mode-hooks' runs AFTER the major mode's own hook -- so
;; a `(foo-mode -1)' in `vterm-mode-hook' is undone a moment later.  Depth
;; 90 puts this after all of them.  It still runs before ghostel starts its
;; process, which is what the read-buffering setting below needs.
;;
;; What this does NOT do, on purpose:
;; - no `mode-line-format' nil and no `line-spacing' 0: the SVG mode line
;;   belongs in a terminal window as in any other, and ghostel sets its
;;   own row height (`ghostel-line-spacing');
;; - eldoc and auto-composition stay on in ghostel, which uses them for
;;   its URL/file hints and for composing text;
;; - evil's jump hooks stay: his version drops them from the command hooks,
;;   which takes `C-o' / `C-i' with it, and point gets moved around in a
;;   ghostel buffer here (the search fix in tools/ghostel.el);
;; - the line-number MODE is ui/display-line-numbers.el's business (ghostel
;;   is exempt at the turn-on there); the display variable is handled
;;   below, because the mode being off is not enough here;
;; - `read-process-output-max' is already 4 MB globally (early-init.el),
;;   above his 1 MB floor, and both bidi settings are global there too.

(defconst zetta-terminal-modes '(ghostel-mode vterm-mode term-mode eat-mode)
  "Major modes of the terminal emulators this file leans out.")

(defun zetta-terminal-buffer-p ()
  "Non-nil in a buffer of one of `zetta-terminal-modes'."
  (apply #'derived-mode-p zetta-terminal-modes))

(defcustom zetta-terminal-lean-minor-modes
  '(;; per-keystroke syntax work (smartparens hangs on both command hooks)
    electric-pair-local-mode electric-indent-local-mode show-paren-local-mode
    smartparens-mode show-smartparens-mode hungry-delete-mode
    ;; per-move overlay and margin work
    hl-line-mode display-fill-column-indicator-mode volatile-highlights-mode
    svg-margin-hover-mode poimap-mode
    ;; checkers
    flycheck-mode flymake-mode
    ;; input interception and extra keymaps
    evil-surround-mode yas-minor-mode undo-tree-mode
    ;; completion
    corfu-mode company-mode
    ;; a terminal is not a file
    blamer-mode trailing-newline-indicator-mode anzu-mode)
  "Minor modes switched off in a terminal buffer by `zetta-terminal-lean-buffer'.
Only a mode that is bound and on is touched.  `M-x describe-mode' in a
terminal buffer lists what is still on; add to this list from there.
The census of a live ghostel buffer on 2026-10-23 is where the second
line of each group came from.  Still on and left alone: the global modes
with nothing per buffer to switch off, and Hyperbole's `hywiki-mode',
whose word-tracking functions sit on both command hooks in every buffer."
  :type '(repeat symbol) :group 'zetta)

(defcustom zetta-terminal-lean-non-ghostel-minor-modes
  '(eldoc-mode auto-composition-mode)
  "Minor modes switched off in every terminal buffer except ghostel's.
ghostel uses eldoc for its URL and file hints and auto-composition to
compose text; the others want neither."
  :type '(repeat symbol) :group 'zetta)

(defun zetta-terminal-lean-buffer ()
  "Strip the current buffer, if it is a terminal, of per-keystroke machinery.
On `after-change-major-mode-hook' at depth 90; see the commentary."
  (when (zetta-terminal-buffer-p)
    ;; The emulator draws its own colours through escape sequences; there
    ;; is nothing for font-lock to parse.
    (setq-local font-lock-defaults '(nil t))
    ;; Scrolling: bring point into view and nothing more -- no recentering
    ;; arithmetic, no margins, no automatic horizontal scrolling, no wrapping.
    (setq-local scroll-conservatively most-positive-fixnum
                scroll-margin 0
                hscroll-margin 0
                auto-hscroll-mode nil
                truncate-lines t)
    ;; No highlight boxes over the no-break spaces TUIs draw with, and no
    ;; per-paragraph direction scan (right-to-left text in the shell will
    ;; render wrong, which is the trade).
    (setq-local nobreak-char-display nil
                bidi-paragraph-direction 'left-to-right
                bidi-inhibit-bpa t)
    ;; No line numbers: the gutter takes real columns off the width the
    ;; emulator reports to the PTY.  The VARIABLE, not the mode -- this
    ;; config gives `display-line-numbers' a default of `relative', so a
    ;; buffer whose mode never turns on (ghostel is exempt at the turn-on
    ;; in ui/display-line-numbers.el) still draws them from the default.
    (setq-local display-line-numbers nil)
    ;; Terminal output is not something to undo.
    (buffer-disable-undo)
    ;; No micro-sleeps between short reads: output lands as it arrives.
    ;; `make-process' reads this with the buffer current, so it reaches the
    ;; process ghostel starts after its mode function returns.  vterm
    ;; starts its process inside `vterm-mode', before any hook: see the
    ;; advice below.  Already nil by default on the Emacs 32 build this
    ;; runs on (checked 2026-10-23); kept for a build where it is t.
    (setq-local process-adaptive-read-buffering nil)
    (let ((inhibit-redisplay t) (inhibit-message t))
      (dolist (mode (append zetta-terminal-lean-minor-modes
                            (unless (derived-mode-p 'ghostel-mode)
                              zetta-terminal-lean-non-ghostel-minor-modes)))
        (when (and (fboundp mode) (boundp mode) (symbol-value mode))
          (ignore-errors (funcall mode -1)))))))

(add-hook 'after-change-major-mode-hook #'zetta-terminal-lean-buffer 90)

;; The current-line highlight is one global overlay, moved on every
;; command; `global-hl-line-buffers' (Emacs 30) is where it is told which
;; buffers to leave alone.  Added to the stock condition, which already
;; keeps it out of the minibuffer and internal buffers, not put in its place.
(defun zetta-terminal-buffer-live-p (buffer &rest _)
  "Non-nil when BUFFER is a terminal buffer; a `buffer-match-p' condition."
  (and (buffer-live-p buffer)
       (with-current-buffer buffer (zetta-terminal-buffer-p))))

;; After hl-line loads (ui/hl-line.el, later than this file), and once.
(with-eval-after-load 'hl-line
  (when (and (boundp 'global-hl-line-buffers)
             (not (string-match-p "zetta-terminal-buffer-live-p"
                                  (format "%S" global-hl-line-buffers))))
    (setq global-hl-line-buffers
          `(and ,global-hl-line-buffers (not zetta-terminal-buffer-live-p)))))

;; corfu asks `global-corfu-modes' before turning on in a buffer at all,
;; which is cheaper than turning it off afterwards.
(defvar global-corfu-modes)
(setq global-corfu-modes `((not ,@zetta-terminal-modes) t))

;; vterm creates its process inside the mode body, before any hook runs,
;; so the buffer-local setting above comes too late for it.
(define-advice vterm-mode (:around (fn &rest args) zetta-terminal-lean)
  "Start vterm's process without adaptive read buffering."
  (let ((process-adaptive-read-buffering nil))
    (apply fn args)))

;; Per-emulator knobs.  Redraw batching: how long output waits before the
;; screen is updated -- ghostel's default is 0.033, one frame at 30 Hz,
;; and `ghostel-adaptive-fps' stretches it under load; vterm's is 0.1.
;; Scrollback: what is retained, and so what each redraw and each GC has
;; to walk.  tmux keeps its own history inside ghostel here, so 1 MiB
;; (about a thousand 80-column rows; ghostel counts bytes) is plenty.
;; vterm's default of a thousand rows is kept.
(with-eval-after-load 'ghostel
  (setq ghostel-timer-delay 0.01
        ghostel-max-scrollback (* 1024 1024)))
(with-eval-after-load 'vterm
  (setq vterm-timer-delay 0.01))
;;; terminals.el ends here
