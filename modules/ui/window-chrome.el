;;; window-chrome.el --- Which bars a buffer gets -*- lexical-binding: t; -*-

;; One place to say that a given buffer should go without a mode line, a
;; header line, or both.
;;
;; Most buffers want both bars and get them from the global defaults that
;; `modeline-svg.el' and `header-line-svg.el' install.  A few do not: a
;; sidebar is narrow enough that two bars around a one-line-per-entry list
;; is mostly frame, and a buffer you glance at and dismiss -- *Messages*,
;; *Backtrace*, *Warnings* -- has almost nothing worth putting in either
;; bar, its name being on the tab already.  Almost: those are windows you
;; want to jump straight back out of, so they keep a mode line cut down to
;; the ace-window key and nothing else.
;;
;; The rule is applied when a buffer is DISPLAYED rather than when it is
;; created, which is what makes a name-based rule work at all: *Messages*
;; and *Warnings* are built by Emacs before any module here loads, so there
;; is no hook of theirs left to attach to.  It is re-applied on every
;; window-buffer change, so a buffer that acquires its major mode late is
;; still caught.
;;
;; This file only decides WHETHER a bar is shown.  What goes in one is the
;; business of the bar's own module -- and of `treemacs.el', which builds
;; the sidebar's own minimal mode line.

(defcustom zetta-window-chrome-rules
  '((treemacs-mode . ace)
    ;; A terminal draws its own everything.  The mode line's file-shaped
    ;; content -- position, size, encoding, the modified flag -- describes
    ;; nothing about a shell, and the header line's breadcrumbs describe a
    ;; path the shell is not at; both are chrome around a window whose
    ;; whole point is the text inside it.  The ace key stays: a terminal
    ;; is a window you jump out of constantly.
    ;;
    ;; `comint-mode' is the broad stroke -- it is Emacs's own name for "a
    ;; buffer with an interactive process at a prompt", so it covers
    ;; `shell-mode', the `inferior-*' REPLs, sql, ielm and *Async Shell
    ;; Command* in one line.  The three before it are the terminals that
    ;; are NOT comint: ghostel and vterm talk to a real terminal
    ;; emulator, eshell is its own lisp shell, `term-mode' its own thing.
    (ghostel-mode . ace)
    (vterm-mode . ace)
    (eshell-mode . ace)
    (term-mode . ace)
    ;; Listed BEFORE the comint rule that would otherwise catch it
    ;; (`shell-command-mode' is comint-derived): the *Async Shell
    ;; Command* buffer is command OUTPUT, not a prompt you type at, and
    ;; the running-command spinner is drawn in the HEADER line -- see
    ;; `zetta-header-line-svg-line1-format' in line-utils.el, started
    ;; from the `shell-command-mode' hook in term/shell.el.  `ace' would
    ;; take that bar away and the spinner with it, so it gets `spinner'
    ;; instead: the same bare mode line, and a header line holding the
    ;; spinner and nothing else.
    (shell-command-mode . spinner)
    (comint-mode . ace)
    ("\\`\\*\\(Messages\\|Backtrace\\|Warnings\\)\\*\\'" . ace))
  "Buffers that get less than the usual two bars.

An alist of (MATCHER . CHROME), consulted in order; the first match wins,
and a buffer matching nothing keeps both bars.

MATCHER is either a major-mode symbol -- tested with `derived-mode-p', so
a mode's children match too -- or a regexp matched against the buffer name.

CHROME is what the buffer KEEPS:

  `both'         both bars (the default for an unmatched buffer; useful as
                 an early entry to exempt one buffer from a later regexp)
  `mode-line'    the mode line only
  `header-line'  the header line only
  `ace'          no header line, and the minimal mode line
                 (`zetta-modeline-svg-bare-format') -- which is NO mode line
                 at all unless the buffer put something in
                 `zetta-modeline-svg-bare-extra', as treemacs does.  The
                 name is historical: this used to keep a mode line for the
                 sake of the ace-window badge, and that badge now lives in
                 the tab line, shown only while a window is being picked
  `spinner'      `ace', plus a one-row header line holding the running
                 command spinner and nothing else
                 (`zetta-header-line-svg-spinner-format').  For a buffer
                 that is watching a process rather than showing a place:
                 the breadcrumbs have nothing to say, but whether the thing
                 is still running does
  `none'         neither

`ace' and `spinner' are the values that put content in a bar; the rest only
ever take bars AWAY, and a buffer listed as `both' is left exactly as its
own mode set it up."
  :type '(alist :key-type (choice (symbol :tag "Major mode")
                                  (regexp :tag "Buffer name"))
                :value-type (choice (const :tag "Both bars" both)
                                    (const :tag "Mode line only" mode-line)
                                    (const :tag "Header line only" header-line)
                                    (const :tag "Ace badge only" ace)
                                    (const :tag "Ace badge + spinner header" spinner)
                                    (const :tag "Neither bar" none)))
  :group 'zetta)

(defun zetta-window-chrome--rule ()
  "Return the CHROME symbol for the current buffer, or nil if no rule matches."
  (seq-some (lambda (rule)
              (let ((matcher (car rule)))
                (and (cond ((symbolp matcher) (derived-mode-p matcher))
                           ((stringp matcher) (string-match-p matcher (buffer-name))))
                     (cdr rule))))
            zetta-window-chrome-rules))

(declare-function zetta-modeline-svg-bare-format "modeline-svg")
(declare-function zetta-header-line-svg-spinner-format "header-line-svg")

(defun zetta-window-chrome-apply ()
  "Give the current buffer the bars its rule says it gets.

Buffer-local, and -- apart from `ace' -- one-way: a bar the rule keeps is
left alone rather than re-asserted, so treemacs\\='s own mode line
(built in `treemacs.el\\=')
survives being told it may keep it."
  (when-let* ((chrome (zetta-window-chrome--rule)))
    (pcase chrome
      ((or 'ace 'spinner)
       (setq-local mode-line-format
                   (and (fboundp 'zetta-modeline-svg-bare-format)
                        ;; No SVG mode line in play (telephone-line is on, or
                        ;; this module loaded on its own).  No bar is closer
                        ;; to the intent than a full one would be.
                        (zetta-modeline-svg-bare-format)))
       (setq-local header-line-format
                   (and (eq chrome 'spinner)
                        (fboundp 'zetta-header-line-svg-spinner-format)
                        (zetta-header-line-svg-spinner-format))))
      (_
       (unless (memq chrome '(both mode-line))
         (setq-local mode-line-format nil))
       (unless (memq chrome '(both header-line))
         (setq-local header-line-format nil))))))

(defun zetta-window-chrome-sync (&optional frame)
  "Apply `zetta-window-chrome-rules' to every buffer shown on FRAME."
  (dolist (w (window-list frame 'no-mini))
    (with-current-buffer (window-buffer w)
      (zetta-window-chrome-apply))))

;; Two hooks, for the two ways a buffer can come to need this: it gets
;; displayed (the only signal available for buffers Emacs built before this
;; file loaded), or it changes major mode while already on screen.
(add-hook 'window-buffer-change-functions #'zetta-window-chrome-sync)
(add-hook 'after-change-major-mode-hook #'zetta-window-chrome-apply)

;; Buffers already on screen when this loads have had both signals already.
(add-hook 'emacs-startup-hook #'zetta-window-chrome-sync)

;;; ------------------------------------------------------------------
;;; popper.  A popup buffer can also be a ruled one -- *Messages* is
;;; both -- and popper asserts a mode line of its own on every popup it
;;; shows: `popper--modified-mode-line' rebuilds the buffer's format
;;; from the DEFAULT value plus `popper-mode-line', and
;;; `popper--restore-mode-lines' puts the plain default back when the
;;; popup is buried.  Either one overwrites what the rule set, so a
;;; ruled buffer wore the FULL line for as long as it was a popup.
;;;
;;; Neither path is hookable (`popper-open-popup-hook' fires too early
;;; to help, and burying has no hook at all), so both are advised.  The
;;; rule wins only where a rule exists; every other popup keeps
;;; popper's indicator exactly as before.
;;; ------------------------------------------------------------------
(with-eval-after-load 'popper
  (define-advice popper--modified-mode-line
      (:around (fn) zetta-window-chrome)
    "Leave a ruled buffer's mode line to `zetta-window-chrome-rules'."
    (if (zetta-window-chrome--rule)
        ;; Re-assert rather than just decline: popper and
        ;; `window-buffer-change-functions' race to touch a newly shown
        ;; popup, and this way the rule holds whichever lands first.
        (progn (zetta-window-chrome-apply) mode-line-format)
      (funcall fn)))

  (define-advice popper--restore-mode-lines
      (:after (win-buf-alist) zetta-window-chrome)
    "Re-apply the rule to buffers popper just reset to the default line."
    (dolist (buf (mapcar #'cdr win-buf-alist))
      (when (buffer-live-p buf)
        (with-current-buffer buf
          (zetta-window-chrome-apply))))))

(provide 'window-chrome)
;;; window-chrome.el ends here
