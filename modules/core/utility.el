;;; utility.el --- Configure utility functions -*- lexical-binding: t; -*-

;; 1Password integration — canonical definitions are in init.el
;; (loaded early for ~/.private.el).  See source/op-secrets.env.tpl.

(defun zetta-wget ()
  (interactive)
  (let ((dir "~/Downloads/")
        (url (eww-current-url)))
    ;; download the asset (pdf)
    (async-shell-command
     (concat "cd " dir " && " "wget " url))
    ;; add bibtex entry
    (org-ref-url-html-to-bibtex (expand-file-name "bibliography.bib" zetta-literature-dir) url)))

;; note!  embark act on links browses to them...

;; presumably get these from some interactive function

;; works reasonably well
(defun zetta-download-pdf ()
  (interactive)
  (let* ((url (eww-current-url))
         (title (read-from-minibuffer "Title: "))
         (key (downcase (replace-regexp-in-string " " "-" title)))
         )
    (async-shell-command (concat "cd ~/Downloads/ && wget " url))

    (progn
      (find-file (expand-file-name "bibliography.bib" zetta-literature-dir))
      (evil-goto-line)
      (insert
       "\n"
       (format "@online{%s,\n" key)
       (format "  title = {%s},\n" title)
       (format "  url = {%s},\n" url)
       "}\n\n"
       )
      (save-buffer)
      (backward-word)
      (kill-new url)
      (org-ref-open-bibtex-notes)
      )
    )
  ;; download pdf
  )

(defun append-to-zsh-history (command)
  (let ((timestamp (format-time-string "%s"))
        (hist-file (expand-file-name "~/.zsh_history")))
    (write-region
     (format ": %s:0;%s\n" timestamp command)
     nil hist-file t)))

;;; Functions moved from bootstrap-zettafn.el

(defface zetta-link-face
  '((t :inherit link :underline nil))
  "Face for file paths in log output.

Inherits `link\=' outright rather than overriding its colour.  It used to
force `:foreground \"purple\"\=' -- a literal #a020f0 no theme ever chose, and
the loudest thing in a compile buffer on any page that is not itself violet.
Paths are most of the lines in one.

Paths and URLs are both clickable and both belong to the theme\='s link
colour, so the underline is what separates them: `link\=' keeps it and means
an address you can open, this one drops it.  Same call as
`zetta-vc-marker-ladder\=' -- a distinction a marker can carry by shape does
not also need to be carried by hue."
  :group 'basic-faces)

;;; ------------------------------------------------------------------
;;; Log-output highlighters
;;; ------------------------------------------------------------------
;; `zetta-highlight-phrases' used to name modus-themes faces --
;; `modus-themes-subtle-red' and friends.  Those were removed in
;; modus-themes 5.0.0 (`define-obsolete-face-alias ... nil'), so every
;; phrase mapped to one has been painting nothing at all, on modus as much
;; as on any other theme.  A face symbol that names no face is not an
;; error, it is simply no attributes, which is why this failed silently.
;;
;; The replacement is three hues and a neutral, at two strengths each.
;;
;; Three, not four, because a palette does not owe us four separable hues
;; and doric-earth does not have them: it paints `error' at hue 0,
;; `warning' at 23 and `accent' at 32, three quarters of its vocabulary
;; inside 32 degrees, with `success' alone out at 120.  Asked for a fourth
;; hue clear of the others, separation had to reach 79 degrees away to
;; magenta -- a colour that theme uses nowhere, and the loudest thing on
;; the screen for exactly the reason an over-saturated wash is.
;;
;; So `info' gives up its hue instead.  It is the slot that can afford to:
;; error, warning and success are read at a glance from across the buffer,
;; where `info' marks SELECT, COMMIT, a token, an arrow -- things you are
;; already reading the word of.  Same call as `zetta-vc-marker-ladder',
;; where a marker that names itself has nothing left for colour to encode.
;; The three that remain then separate cleanly, at 47 and 50 degrees, and
;; every one of them is a colour the theme actually paints.
;;
;; Strength is
;; the gradient step the wash is weighted against, so a strong wash is
;; further off the page than a subtle one on a light theme and a dark one
;; alike.  Eight slots covers the vocabulary below with room spare, and
;; every slot is separable: hues by colour, strengths by lightness AND
;; chroma, both of which now come from that gradient step.
;;
;; This is not the same call as the VC gutter or the TODO keywords, which
;; deliberately carry no hue (see `zetta-vc-marker-ladder').  There the
;; marker names itself and colour had nothing left to encode.  Here the
;; point is to see at a glance that the bottom of a 2000-line test run has
;; gone red without reading a word of it, so hue IS the content.
(defvar zetta-highlight-slots
  '((zetta-highlight-bad         error   . brushup-bg-2)
    (zetta-highlight-bad-strong  error   . brushup-bg-4)
    (zetta-highlight-warn        warning . brushup-bg-2)
    (zetta-highlight-warn-strong warning . brushup-bg-4)
    (zetta-highlight-good        success . brushup-bg-2)
    (zetta-highlight-good-strong success . brushup-bg-4)
    (zetta-highlight-info        nil     . brushup-bg-2)
    (zetta-highlight-info-strong nil     . brushup-bg-4))
  "Log highlighter faces as (FACE THEME-COLOUR-KIND . WEIGHT-ANCHOR).

KIND nil means the slot carries no hue at all and takes the page\='s own
colour at the anchor\='s weight -- see `zetta-highlight--neutral-wash\='.")

(dolist (slot zetta-highlight-slots)
  (custom-declare-face
   (car slot) '((t :inherit highlight))
   (format "Log highlighter: %s." (car slot)) :group 'zetta))

;; There is no saturation knob here any more.  There used to be an HSL
;; floor-and-ceiling pair, on the reasoning that log washes should sit
;; louder than a wash inside prose, and it did not do what it said: HSL
;; saturation is not an amount of colour, so a single clamp put the four
;; washes between chroma 15 and chroma 61 on doric-earth -- warning over
;; four times as saturated as the page, red half as saturated as green at
;; the same nominal strength.  That spread was the clash.
;;
;; `zetta-hue-wash' now takes both lightness and chroma from the anchor, so
;; how loud a wash is is decided in exactly one place: which gradient step
;; a slot names below.  Want them louder?  Move a slot from `brushup-bg-2'
;; to `brushup-bg-4'.  Want the whole family louder?  That is a question
;; about the theme's gradient, which is the right place for it to be asked.

(defvar zetta-highlight-hue-separation 0.13
  "Least distance, in turns of the colour wheel, between two highlighter hues.
0.13 is a little under 50 degrees; four hues have 0.25 to play with, so this
leaves a theme most of its own character and only bends a genuine collision.

This is what separation ASKS for.  What it may spend getting there is
`zetta-highlight-hue-rotation\=', and on a crowded palette that cap binds
first.")

(defvar zetta-highlight-hue-rotation 0.125
  "Furthest a highlighter hue may be rotated to clear its neighbours, in turns.
0.125 is 45 degrees.

Without a cap, separation will go as far around the wheel as it takes, and
on a warm theme that means inventing a colour.  doric-earth paints `error\='
at hue 0, `warning\=' at 23 and `accent\=' at 32 -- three of its four inside 32
degrees -- so the nearest angle clearing 47 degrees for `accent\=' was 313,
a magenta the theme uses nowhere.  It was the loudest thing on screen, and
for the same reason an over-saturated wash is: nothing else on the page
agrees with it.

Capped, `accent\=' lands at 77 instead and the four read as a warm ramp --
red, orange, gold -- plus green.  That is 30 degrees between the closest
pair rather than the 47 asked for, which is the honest trade: a theme that
does not have four separable hues cannot be made to have them, and the
strengths are still there to tell a pair apart.  Raise it to let separation
roam again, or set it to 0 to pin every wash to its theme hue outright.")

(defun zetta-highlight-hues ()
  "The three highlighter hues, spread apart wherever the theme crowds them.
Ordered so `error' and `success' keep their own hue outright -- red for
broken and green for fine are the two a reader decodes without thinking --
and `warning' is what moves when a palette has to give.

`accent' is deliberately absent: the fourth slot carries no hue.  See the
commentary above `zetta-highlight-slots' for why."
  (let* ((kinds '(error success warning))
         (colors (mapcar #'zetta-theme-color kinds))
         (hues (zetta-hue-separate (mapcar #'zetta-hue-of colors)
                                   zetta-highlight-hue-separation
                                   zetta-highlight-hue-rotation)))
    (cl-mapcar (lambda (kind color hue)
                 (cons kind (if hue (zetta-with-hue color hue) color)))
               kinds colors hues)))

(defun zetta-highlight--neutral-wash (anchor)
  "ANCHOR\='s weight in the page\='s own colour, carrying no hue of its own.

Chroma comes from the page rather than from ANCHOR, which is what makes
this read as a darker patch of the page instead of a fourth colour: the
gradient steps are themselves tinted, and at ANCHOR\='s chroma this would
come out a khaki as saturated as the hued washes and merely a different
angle from them.

Falls back to ANCHOR untouched if either colour cannot be read."
  (let ((al (zetta-color--lch anchor))
        (pl (and (boundp 'brushup-bg) (stringp brushup-bg)
                 (zetta-color--lch brushup-bg))))
    (if (and al pl)
        (zetta-color--render (nth 0 al) (nth 1 pl) (nth 2 pl))
      anchor)))

(defun zetta-highlight-refresh-faces ()
  "Re-tint the log highlighter faces from the current theme."
  (when (fboundp 'zetta-hue-wash)
    (let ((hues (zetta-highlight-hues)))
      (pcase-dolist (`(,face ,kind . ,anchor) zetta-highlight-slots)
      (when (and (facep face) (boundp anchor))
        (let ((wash (if kind
                        (zetta-hue-wash (alist-get kind hues)
                                        (symbol-value anchor))
                      (zetta-highlight--neutral-wash (symbol-value anchor)))))
          (set-face-attribute
           face nil
           :background wash
           ;; Log output arrives pre-coloured -- ANSI escapes in a terminal
           ;; buffer, compilation faces in a compile buffer -- and none of
           ;; it was picked to sit on a wash.  `zetta-readable-on' hands
           ;; back the theme's own ink whenever it reads, so on the subtle
           ;; slots this changes nothing; it only bites on a strong wash
           ;; that the buffer's own foreground would have drowned in.
           :foreground (if (fboundp 'zetta-readable-on)
                           (zetta-readable-on wash)
                         'unspecified))))))))
;; This file loads BEFORE core/line-utils.el (see source/init-data/init-data.el,
;; where core/utility.el is tenth and core/line-utils.el twenty-eighth), so
;; `zetta-hue-wash' does not exist yet and the call below is a guarded no-op on
;; the first pass.  Registering on `brushup-styles' is not enough to recover:
;; `brushup-mode' runs `brushup' from the bootstrap, before any module loads,
;; so the first pass is already gone by the time the entry is added and the
;; faces would sit on their cold-start `highlight' inherit until the next theme
;; change.  Same after-init catch-up line-utils.el uses for the same reason.
(zetta-highlight-refresh-faces)
(with-eval-after-load 'brushup
  (add-to-list 'brushup-styles '(zetta-highlight-refresh-faces) t))
(add-hook (if (boundp 'elpaca-after-init-hook) 'elpaca-after-init-hook 'after-init-hook)
          #'zetta-highlight-refresh-faces)

(defvar zetta-highlight-phrase-alist
  '(;; failures
    ("error"             . zetta-highlight-bad-strong)
    ("failed"            . zetta-highlight-bad)
    ("HOOK_ERRORED"      . zetta-highlight-bad)
    ("ROLLBACK"          . zetta-highlight-bad)
    ("500"               . zetta-highlight-bad-strong)
    ("400"               . zetta-highlight-bad)
    ("401"               . zetta-highlight-bad)
    ("402"               . zetta-highlight-bad)
    ("404"               . zetta-highlight-bad)
    ;; cautions
    ("warning"           . zetta-highlight-warn-strong)
    ("debug"             . zetta-highlight-warn)
    ("422"               . zetta-highlight-warn)
    ;; successes
    ("PIPELINE_SUCCESS"  . zetta-highlight-good-strong)
    ("STEP_SUCCESS"      . zetta-highlight-good)
    ("200"               . zetta-highlight-good)
    ("201"               . zetta-highlight-good)
    ("Captured stdout call" . zetta-highlight-good)
    ;; mutations -- notable rather than good, and the slot they share with
    ;; the reads has no hue to tell them apart with, so the writes take its
    ;; strong end and the reads its subtle one
    ("COMMIT"            . zetta-highlight-info-strong)
    ("INSERT"            . zetta-highlight-info-strong)
    ("UPDATE"            . zetta-highlight-info-strong)

    ("DELETE"            . zetta-highlight-info-strong)
    ;; reads, identifiers, flow
    ("SELECT"            . zetta-highlight-info)
    ("New Records"       . zetta-highlight-info)
    ("token"             . zetta-highlight-info)
    ("Starting workflow" . zetta-highlight-info)
    ("-->"               . zetta-highlight-info)
    ("!="                . zetta-highlight-info))
  "Literal phrases to highlight in log output, and the slot each takes.

Capitalisation here is not cosmetic, it is the case-sensitivity switch.
`highlight-phrase' matches smart-case: an all-lowercase phrase folds case
and catches every spelling, while a phrase carrying any capital matches
exactly.  So \"error\" is one entry that finds ERROR, Error and error,
where the old ERROR/Error/error trio laid up to three overlays on the same
word at two different strengths and left which one you saw to overlay
order.  The SQL keywords go the other way on purpose: \"SELECT\" stays
upper case so it does not light up the word select in ordinary prose.

A phrase still matches inside a longer word -- error within HOOK_ERRORED,
which has an entry of its own.  Wrap an entry in \\_< \\_> if that matters."
  )

(defvar zetta-highlight-regexp-alist
  '(;; a diff + / - with exactly one space either side
    (" \\+ " . zetta-highlight-good)
    (" - "   . zetta-highlight-bad)
    ;; [a-fA-F], not [a-f]: this moved from `highlight-phrase' -- which
    ;; folds case -- to `highlight-regexp', which does not, and an
    ;; uppercase uuid would otherwise have gone quietly unmatched
    ("[a-fA-F0-9]\\{8\\}-[a-fA-F0-9]\\{4\\}-[a-fA-F0-9]\\{4\\}-[a-fA-F0-9]\\{4\\}-[a-fA-F0-9]\\{12\\}"
     . zetta-highlight-info)
    ;; paths and urls keep the link faces: they are not a log CATEGORY,
    ;; they are things you click
    ("\\(/\\|~\\)[^ ]+\\.[a-zA-Z0-9]+" . zetta-link-face)
    ("http\\(s\\)?://[^ ]+" . link))
  "Regexps to highlight in log output, and the face each takes.")

(defun zetta-highlight-phrases ()
  "Highlight the phrases and patterns worth spotting in log output."
  (interactive)
  (pcase-dolist (`(,phrase . ,face) zetta-highlight-phrase-alist)
    (highlight-phrase phrase face))
  (pcase-dolist (`(,re . ,face) zetta-highlight-regexp-alist)
    (highlight-regexp re face)))

(defun zetta-minify-path (path)
  "Abbreviate PATH, keeping only first 2 chars of each component except the last directory."
  (let* ((path (abbreviate-file-name path))
         (path-split (split-string path "/"))
         (leaf-dir-name (car (last path-split 2)))
         (path-split (butlast path-split 2)))
    (concat
     (mapconcat
      (lambda (s) (if (> (length s) 1) (substring s 0 2) s))
      path-split "/")
     "/" leaf-dir-name)))

(defun zetta-create-scratch-buffer (mode)
  "Create a new scratch buffer to work in. (could be any mode)"
  (interactive "sMode: ")
  (switch-to-buffer (get-buffer-create (concat "*scratch-" mode "*")))
  (funcall (intern mode)))

(defun zetta-general-describe-keybindings (&optional arg)
  "Show all keys that have been bound with general in an org buffer.
Any local keybindings will be shown first followed by global keybindings.
With a non-nil prefix ARG only show bindings in active maps."
  (interactive "P")
  (with-output-to-temp-buffer "*General Keybindings*"
    (let* ((keybindings (append
                         (copy-alist general-keybindings)
                         (list (cons 'local general-local-keybindings))))
           (active-maps (current-active-maps)))
      (dolist (keymap general-describe-priority-keymaps)
        (let ((keymap-cons (assq keymap keybindings)))
          (when (and keymap-cons
                     (or (null arg)
                         (and (boundp (car keymap-cons))
                              (memq (symbol-value (car keymap-cons))
                                    active-maps))))
            (general--print-keymap-heading keymap-cons)
            (setq keybindings (assq-delete-all keymap keybindings)))))
      (when general-describe-keymap-sort-function
        (setq keybindings (funcall general-describe-keymap-sort-function
                                   keybindings)))
      (dolist (keymap-cons keybindings)
        (when (or (null arg)
                  (and (boundp (car keymap-cons))
                       (memq (symbol-value (car keymap-cons)) active-maps)))
          (general--print-keymap-heading keymap-cons)))))

  (with-current-buffer "*General Keybindings*"
    (write-region
     (point-min)
     (point-max)
     (expand-file-name "keybindings.org" user-emacs-directory)
     t)
    (kill-buffer)))

(defun zetta-build-docs ()
  (interactive)
  (with-current-buffer (find-file-noselect (expand-file-name "read.org" user-emacs-directory))
    (org-babel-execute-buffer)
    (save-buffer)
    (org-open-file (org-html-export-to-html))
    (kill-buffer)))

;;; utility.el ends here
