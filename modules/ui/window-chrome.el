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
  `ace'          no header line, and a mode line cut down to just the
                 ace-window badge (`zetta-modeline-svg-bare-format').  For
                 a buffer you glance at and dismiss: nothing on the full
                 line describes it, but the key for jumping back OUT of it
                 is worth keeping
  `none'         neither

`ace' is the one value that puts content in a bar; the rest only ever take
bars AWAY, and a buffer listed as `both' is left exactly as its own mode
set it up."
  :type '(alist :key-type (choice (symbol :tag "Major mode")
                                  (regexp :tag "Buffer name"))
                :value-type (choice (const :tag "Both bars" both)
                                    (const :tag "Mode line only" mode-line)
                                    (const :tag "Header line only" header-line)
                                    (const :tag "Ace badge only" ace)
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

(defun zetta-window-chrome-apply ()
  "Give the current buffer the bars its rule says it gets.

Buffer-local, and -- apart from `ace' -- one-way: a bar the rule keeps is
left alone rather than re-asserted, so treemacs\\='s own mode line
(built in `treemacs.el\\=')
survives being told it may keep it."
  (when-let* ((chrome (zetta-window-chrome--rule)))
    (pcase chrome
      ('ace
       (setq-local header-line-format nil)
       (setq-local mode-line-format
                   (and (fboundp 'zetta-modeline-svg-bare-format)
                        ;; No SVG mode line in play (telephone-line is on, or
                        ;; this module loaded on its own).  No bar is closer
                        ;; to the intent than a full one would be.
                        (zetta-modeline-svg-bare-format))))
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

(provide 'window-chrome)
;;; window-chrome.el ends here
