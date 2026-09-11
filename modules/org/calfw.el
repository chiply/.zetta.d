;;; calfw.el --- Configure calfw calendar -*- lexical-binding: t; -*-

;; Two things calfw does not get right on its own here: its palette, and the
;; width of its ellipsis.
;;
;; The palette is hard-coded hues -- Slategray4 headers, red2 Sundays, Blue
;; Saturdays, a SlateBlue grid, an amber today, and a Seagreen4 "source
;; colour" that every event inherits as a green block.  None of it is read
;; from the theme, so the calendar is the one buffer that does not belong to
;; whatever is loaded.  `zetta-calfw-apply-palette' repaints the lot from
;; brushup's ladder and no hue at all: the weekend is a deeper GROUND rather
;; than a different colour, today is INVERTED (ink as the ground, page as the
;; text -- the strongest thing a theme offers without importing a colour),
;; and everything else steps down from there.
;;
;; The ellipsis is a layout bug rather than a taste one.  calfw pads every
;; cell to a column count measured with `string-width', which counts U+2026
;; as one column -- but a CJK-capable default font (the `xiaolai-mono'
;; fontaine preset, say) draws it FULL width, so every truncated cell renders
;; one cell too wide.  Only the cells that were actually truncated drift,
;; which is why the table looks randomly ragged rather than uniformly
;; shifted.  `zetta-calfw--ellipsis' measures the glyph and picks the first
;; candidate that really occupies one cell.

(require 'cl-lib)

;; brushup's palette (bootstrap-brushup.el), read by `zetta-calfw-apply-palette'
;; and by the `:brushup' registration below.
(defvar brushup-styles)
(defvar brushup-bg)
(defvar brushup-bg-1)
(defvar brushup-bg-2)
(defvar brushup-bg-3)
(defvar brushup-fg)
(defvar brushup-fg-1)
(defvar brushup-fg-2)
(defvar brushup-fg-3)
(defvar brushup-fg-4)
(defvar brushup-fg-6)

(defvar calfw-item-separator-color-face)

(declare-function calfw-composite-color "calfw")
(declare-function calfw-cp-get-component "calfw")
(declare-function calfw--cp-update "calfw")
(declare-function calfw-cp-resize "calfw")
(declare-function calfw-default-window-dims "calfw")
(declare-function calfw--cursor-to-date "calfw")
(declare-function calfw-component-dest "calfw")
(declare-function calfw-dest-width "calfw")
(declare-function calfw-dest-height "calfw")

;;; ------------------------------------------------------------------
;;; Ellipsis
;;; ------------------------------------------------------------------

(defcustom zetta-calfw-ellipsis-candidates '("…" "⋯" "›" ".")
  "Truncation marks calfw may use, best first.

The first one that occupies exactly one CELL -- not merely one column by
`string-width' -- is the one it gets.  U+2026 is the right glyph and wins
whenever the default font draws it narrow; U+22EF is the same three dots
at single width in the CJK-capable families where U+2026 is not."
  :type '(repeat string) :group 'zetta)

(defvar zetta-calfw--ellipsis nil
  "Cached (FONT-KEY . MARK) from the last `zetta-calfw--ellipsis' measurement.")

(defun zetta-calfw--ellipsis ()
  "The truncation mark that fits one cell in the current default font.

Measured rather than assumed, and re-measured whenever the font changes:
which candidate wins is a property of the FONT, not of the theme or the
config, and this config switches fontaine presets between families that
disagree about it.  The measurement costs a temporary buffer, so the
answer is cached against the cell width and family that produced it."
  (let ((key (list (frame-char-width)
                   (face-attribute 'default :family nil 'default))))
    (if (equal key (car zetta-calfw--ellipsis))
        (cdr zetta-calfw--ellipsis)
      (let ((mark (or (and (display-graphic-p)
                           (ignore-errors
                             (seq-find
                              (lambda (c)
                                (and (= (string-width c) 1)
                                     (= (string-pixel-width c)
                                        (frame-char-width))))
                              zetta-calfw-ellipsis-candidates)))
                      ;; Nothing to measure against (batch, or a daemon
                      ;; before its first frame): calfw's own glyph.
                      "…")))
        (setq zetta-calfw--ellipsis (cons key mark))
        mark))))

(defun zetta-calfw--truncate-ellipsis (fn org limit &optional ellipsis)
  "Call FN on ORG, LIMIT and ELLIPSIS with a truncation mark that fits.

calfw asks for the default mark -- ELLIPSIS is t at all four of its call
sites -- so overriding the default is enough, and an explicit string is
left alone.  Advice rather than a buffer-local setting because calfw
builds its rows before the calendar buffer is current."
  (let ((truncate-string-ellipsis
         (if (eq ellipsis t) (zetta-calfw--ellipsis) truncate-string-ellipsis)))
    (funcall fn org limit ellipsis)))

;;; ------------------------------------------------------------------
;;; Palette
;;; ------------------------------------------------------------------

(defcustom zetta-calfw-content-wash 0.0
  "How much of a source's colour goes into the block behind its events.

calfw derives BOTH the ink and the ground of an event from one source
colour, at weights of 0.7 and 0.3 -- so a colour dark enough to read as
ink puts the ground three or four rungs off the page, which is why the
stock calendar is a wall of green slabs.  Splitting them makes the ink the
source colour outright and the ground a wash of it.

At 0 there is no ground: an event is ink on the page, and the grid is what
separates it from the next one.  That is the default because the events
are the only thing in the calendar you actually read, and a field that is
behind everything you read is not marking anything out."
  :type 'float :group 'zetta)

(defcustom zetta-calfw-period-wash 0.10
  "How much ink goes into the bar behind a multi-day event.

Unlike a single-day event, a period has to read as ONE thing spanning
several cells, and its own fill (calfw draws it as `-\=' between
parentheses) only says that within a cell.  So this stays above
`zetta-calfw-content-wash': a period is the one item that needs a ground."
  :type 'float :group 'zetta)

(defcustom zetta-calfw-stock-source-color "Seagreen4"
  "The colour calfw-org gives a source when the caller names none.

A source that arrived at this colour did not choose it -- it is the
default baked into `calfw-org-open-calendar', which offers the colour only
as an optional positional argument, so there is nowhere for this config to
say \"take it from the theme\" instead.  Events of such a source are drawn
on the ladder; a source with a colour of its own keeps it, which is what
would tell two calendars apart if there were ever two."
  :type 'string :group 'zetta)

(defun zetta-calfw--page ()
  "The page colour to wash event grounds toward."
  (or (bound-and-true-p brushup-bg) (face-background 'default nil t) "white"))

(defun zetta-calfw--fg-color (src-color &optional _other)
  "Ink for events of a source coloured SRC-COLOR.

A source colour IS the ink here, rather than calfw's blend of it with the
default foreground: the blend exists to keep a loud hue readable, and
nothing on the ladder is loud."
  (if (or (null src-color)
          (equal src-color zetta-calfw-stock-source-color))
      (or (bound-and-true-p brushup-fg-2) (face-foreground 'default nil t))
    src-color))

(defun zetta-calfw--wash (weight &optional color)
  "COLOR (default the theme\='s ink) at WEIGHT over the page.

`unspecified' at a WEIGHT of zero rather than the page colour itself.
They look the same on an opaque frame and do not on a translucent one: a
face background is painted OPAQUE, so a page-coloured ground would punch a
solid rectangle through a frame the rest of the buffer lets the desktop
through.  Not setting the attribute lets the buffer\='s own ground stand,
translucency included.

The rungs brushup offers are all heavier than the tints wanted inside a
cell, so the grounds here are measured in washes and stay ordered against
each other whatever the wash settings are."
  (if (<= weight 0)
      'unspecified
    (calfw-composite-color (or color (zetta-calfw--fg-color nil))
                           weight (zetta-calfw--page))))

(defun zetta-calfw--bg-color (src-color &optional _other)
  "Ground for events of a source coloured SRC-COLOR: a wash of its ink."
  (zetta-calfw--wash zetta-calfw-content-wash
                     (zetta-calfw--fg-color src-color)))

(defun zetta-calfw-apply-palette ()
  "Paint calfw from the theme's ladder, and re-render any open calendar.

The calendar is a table of nested fields, so the ladder is spent on saying
which field you are looking at rather than on colouring them in:

  today            INVERTED -- ink as the ground, page as the text
  weekend column   a ground one rung deeper than the weekday header
  header, events   one rung off the page, so the table reads as a table
  grid, disabled   the far end of the ladder; structure you read past

No hue anywhere.  A calendar is full of things a stoplight palette is
tempted to colour -- weekends, holidays, today, each source -- and none of
them mean good or bad, so all of them are prominence instead."
  (when (and (boundp 'brushup-bg) (facep 'calfw-grid-face))
    (cl-flet ((f (face &rest attrs)
                (when (facep face) (apply #'set-face-attribute face nil attrs))))
      ;; The frame around the month.
      (f 'calfw-title-face    :foreground brushup-fg-3)
      (f 'calfw-grid-face     :foreground brushup-bg-3)
      (f 'calfw-header-face   :foreground brushup-fg-2 :background brushup-bg-1
         :weight 'bold)
      ;; Weekends and holidays are DIFFERENT, not more important, so they
      ;; take a deeper ground and keep the same ink.
      (f 'calfw-saturday-face :foreground brushup-fg-2 :background brushup-bg-2
         :weight 'bold)
      (f 'calfw-sunday-face   :foreground brushup-fg-2 :background brushup-bg-2
         :weight 'bold)
      (f 'calfw-holiday-face  :foreground brushup-fg-2 :background brushup-bg-2
         :slant 'italic)
      ;; The cells.  Half a wash for the day title, so the row that names
      ;; the day reads as a band without competing with the events under
      ;; it -- which are a full wash, and are what you came to read.
      (f 'calfw-day-title-face   :background (zetta-calfw--wash 0.06))
      (f 'calfw-default-day-face :foreground brushup-fg-1 :weight 'bold)
      (f 'calfw-disable-face     :foreground brushup-fg-6)
      (f 'calfw-annotation-face  :foreground brushup-fg-4)
      ;; Today's cell is now the only filled field in the grid, so it takes
      ;; the lightest rung that still reads as filled -- the inverted title
      ;; above it is what actually identifies today.
      (f 'calfw-today-face       :background brushup-bg-1)
      (f 'calfw-today-title-face :background brushup-fg-2 :foreground brushup-bg
         :weight 'bold)
      ;; Contents.  `calfw-default-content-face' is the fallback for a
      ;; source with no colour; `calfw-periods-face' is where multi-day bars
      ;; land now that the period colours are off (see the advice below).
      (f 'calfw-default-content-face :foreground brushup-fg-2)
      (f 'calfw-periods-face   :foreground brushup-fg-1
         :background (zetta-calfw--wash zetta-calfw-period-wash)
         :slant 'normal)
      (f 'calfw-calendar-hidden-face :foreground brushup-fg-6 :strike-through t)
      ;; Toolbar.  The face named `-face' is the RAIL between the buttons,
      ;; not the buttons -- calfw paints its foreground and background alike
      ;; so the text inside it disappears.
      (f 'calfw-toolbar-face :foreground brushup-bg-1 :background brushup-bg-1)
      (f 'calfw-toolbar-button-off-face
         :foreground brushup-fg-4 :background brushup-bg :weight 'normal)
      (f 'calfw-toolbar-button-on-face
         :foreground brushup-fg :background brushup-bg :weight 'bold))
    ;; A colour string, not a face: calfw drops it straight into an
    ;; `:underline' attribute when a source asks for item separators.
    (setq calfw-item-separator-color-face brushup-bg-2)
    (zetta-calfw-rerender-open-calendars)))

(defun zetta-calfw-rerender-open-calendars ()
  "Re-render every live calendar so a theme change reaches its events.

Event colours are baked into the text properties of the rendered
calendar, so repainting the faces is not enough -- the events would keep
the old theme's ink until something else forced a redraw.  `calfw--cp-update'
re-renders from the data calfw already holds, which is the cheap half of
`calfw-refresh-calendar-buffer': no org file is re-scanned."
  (dolist (buf (buffer-list))
    (with-current-buffer buf
      (when (derived-mode-p 'calfw-calendar-mode 'cfw:calendar-mode)
        (when-let* ((cp (calfw-cp-get-component t)))
          (calfw--cp-update cp))))))


;;; ------------------------------------------------------------------
;;; Responsive sizing
;;; ------------------------------------------------------------------
;; calfw is already responsive in the only sense that matters to the LAYOUT:
;; `calfw--calc-param' divides the window between the view's columns and
;; rows, so a cell is as wide and as tall as the space allows and the
;; calendar fits by construction.  What it does not do is notice that the
;; window moved -- the size is read once, into the destination, when the
;; calendar is created.
;;
;; So nothing here computes a fit; the fit is calfw's.  This just tells it
;; when to recompute one, which turns out to be the entire problem: the
;; resize hook this config already had tested `cfw:calendar-mode', a symbol
;; calfw dropped when it renamed everything to `calfw-', so it had quietly
;; never fired.
;;
;; What is NOT worth chasing: the few lines usually left below the last week.
;; Every week row has to be the same whole number of lines, so up to
;; ROWS-1 lines of the window are unspendable -- measured at a window of 40
;; lines, a five-week month renders 37 and the next size up renders 42.  That
;; gap is quantisation, not slack, and no amount of re-measuring closes it.

(defcustom zetta-calfw-fit-delay 0.3
  "Seconds of idle before a resized window\='s calendar is re-drawn.

A re-draw costs on the order of 150ms here -- far too much to spend from a
redisplay hook, and far too much to spend on every intermediate size of a
window drag.  Waiting for idle buys exactly one re-draw per gesture, after
the gesture."
  :type 'number :group 'zetta)

(defvar zetta-calfw--fit-pending nil
  "Non-nil when an idle fit pass is already armed.")

(defun zetta-calfw-fit-window (win)
  "Re-draw the calendar in WIN at the size WIN can show.

Returns non-nil if it re-drew.  Does nothing when the size calfw already
holds is the size the window already has, which is what keeps the idle
pass free in the common case of a window that did not move."
  (when (window-live-p win)
    (with-current-buffer (window-buffer win)
      (when-let* (((derived-mode-p 'calfw-calendar-mode))
                  (cp (calfw-cp-get-component t))
                  (dims (calfw-default-window-dims win))
                  (dest (calfw-component-dest cp)))
        (unless (and (eql (calfw-dest-width dest) (car dims))
                     (eql (calfw-dest-height dest) (cdr dims)))
          ;; `calfw--cp-update' erases the buffer, so the cursor has to
          ;; travel as a DATE: the character position it sat at addresses a
          ;; different day once the cells are a different size.
          ;;
          ;; The plain property read, NOT `calfw-cursor-to-nearest-date'.
          ;; That one hunts for a neighbouring date with `line-move', an
          ;; interactive movement command that reads `line-move-visual' and
          ;; measures against the SELECTED window -- neither of which means
          ;; anything from an idle timer looking at somebody else's window.
          ;; Off a date, the cursor simply does not travel.
          (let ((date (calfw--cursor-to-date)))
            (calfw-cp-resize cp (car dims) (cdr dims))
            (calfw--cp-update cp date))
          t)))))

(defun zetta-calfw-fit-windows ()
  "Fit every displayed calendar to its window.  Runs on idle."
  (setq zetta-calfw--fit-pending nil)
  (dolist (win (window-list-1 nil nil 'visible))
    (zetta-calfw-fit-window win)))

(defun zetta-calfw--schedule-fit (&rest _)
  "Arm one idle fit pass.  Runs inside redisplay, so it does no work itself.

Armed once rather than debounced by cancelling: an idle timer set at the
start of a drag does not fire until the drag stops, which is the same
result as re-arming on every intermediate size and none of the churn."
  (unless zetta-calfw--fit-pending
    (setq zetta-calfw--fit-pending t)
    (run-with-idle-timer zetta-calfw-fit-delay nil #'zetta-calfw-fit-windows)))

;;; ------------------------------------------------------------------
;;; Package
;;; ------------------------------------------------------------------

;; calfw-org.el ships in the same repo as calfw.  Declared as its own
;; elpaca order the pair coordinates through elpaca's monorepo machinery,
;; which deadlocks on a cold first clone ("Waiting on monorepo" forever --
;; measured on every cold CI run and a cold local build, 2026-07-22; warm
;; it resolves instantly, which is why no working machine ever saw it).
;; Building both files as ONE order removes the coordination entirely;
;; the calfw-org use-package below stays for config but ensures nothing.
(use-package calfw
  :ensure (calfw :files ("calfw.el" "calfw-compat.el" "calfw-org.el"))
  :commands (cfw:open-calendar-buffer)
  :config
  ;; Both hooks, because they answer different questions: the window this
  ;; calendar is in got bigger, and this calendar got put in a different
  ;; window.  Either invalidates the size calfw is holding.
  (add-hook 'window-size-change-functions #'zetta-calfw--schedule-fit)
  (add-hook 'window-buffer-change-functions #'zetta-calfw--schedule-fit)

  (advice-add 'calfw--render-truncate :around #'zetta-calfw--truncate-ellipsis)
  (advice-add 'calfw-make-fg-color :override #'zetta-calfw--fg-color)
  (advice-add 'calfw-make-bg-color :override #'zetta-calfw--bg-color)
  ;; Multi-day bars go back to `calfw-periods-face'.  calfw derives a period
  ;; colour from the source and then MEMOISES it into the source struct, so
  ;; a theme change could never reach one; returning nil is how calfw itself
  ;; says "this source has no period colour, use the face" -- and a face is
  ;; the thing brushup already knows how to repaint.
  (advice-add 'calfw--source-period-bgcolor-get :override #'ignore)
  (advice-add 'calfw--source-period-fgcolor-get :override #'ignore)
  (zetta-calfw-apply-palette)

  (with-eval-after-load 'evil
    ;; Calendar grid — hjkl navigation, SPC for details, RET to open
    (evil-set-initial-state 'cfw:calendar-mode 'normal)
    (evil-define-key 'normal calfw-calendar-mode-map
      "h" 'calfw-navi-previous-day-command
      "j" 'calfw-navi-next-week-command
      "k" 'calfw-navi-previous-week-command
      "l" 'calfw-navi-next-day-command
      "^" 'calfw-navi-goto-week-begin-command
      "$" 'calfw-navi-goto-week-end-command
      "<" 'calfw-navi-prev-view
      ">" 'calfw-navi-next-view
      "t" 'calfw-navi-goto-today-command
      "." 'calfw-navi-goto-today-command
      "R" 'calfw-refresh-calendar-buffer
      (kbd "SPC") 'calfw-show-details-command
      (kbd "TAB") 'calfw-navi-next-item-command
      (kbd "<backtab>") 'calfw-navi-prev-item-command
      (kbd "M-g") 'calfw-navi-goto-date-command
      "D" 'calfw-change-view-day
      "W" 'calfw-change-view-week
      "T" 'calfw-change-view-two-weeks
      "M" 'calfw-change-view-month
      (kbd "RET") 'calfw-org-onclick
      "q" 'bury-buffer)

    ;; Details buffer — scrollable item list with org navigation
    (evil-set-initial-state 'calfw-details-mode 'normal)
    (evil-define-key 'normal calfw-details-mode-map
      "j" 'next-line
      "k" 'previous-line
      "h" 'calfw-details-navi-prev-command
      "l" 'calfw-details-navi-next-command
      (kbd "TAB") 'calfw-details-navi-next-item-command
      (kbd "<backtab>") 'calfw-details-navi-prev-item-command
      (kbd "RET") 'calfw-org-onclick
      (kbd "C-f") 'scroll-up-command
      (kbd "C-b") 'scroll-down-command
      "q" 'calfw-details-kill-buffer-command))

  :brushup
  (add-to-list 'brushup-styles '(zetta-calfw-apply-palette)))

(autoload 'calfw-org-open-calendar "calfw-org" "Open calfw calendar with org agenda." t)

(use-package calfw-org
  :ensure nil  ; built as part of the calfw order above (same repo)
  :after calfw
  :demand t)

;;; calfw.el ends here
