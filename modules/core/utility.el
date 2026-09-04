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
  '((t :inherit link :foreground "purple"))
  "Face for links."
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
;; The replacement is four hues -- the only four EVERY theme reliably
;; defines, via `zetta-theme-color' -- at two strengths each.  Strength is
;; the gradient step the wash is weighted against, so a strong wash is
;; further off the page than a subtle one on a light theme and a dark one
;; alike.  Eight slots covers the vocabulary below with room spare, and
;; every slot is separable: hues by colour, strengths by lightness.
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
    (zetta-highlight-info        accent  . brushup-bg-2)
    (zetta-highlight-info-strong accent  . brushup-bg-4))
  "Log highlighter faces as (FACE THEME-COLOUR-KIND . WEIGHT-ANCHOR).")

(dolist (slot zetta-highlight-slots)
  (custom-declare-face
   (car slot) '((t :inherit highlight))
   (format "Log highlighter: %s." (car slot)) :group 'zetta))

(defvar zetta-highlight-saturation '(0.35 . 0.70)
  "Saturation floor and ceiling for a highlighter wash.
Louder than the org-remark pens, which sit inside prose and should stay
quiet -- these sit in a wall of log output and have to be spotted from
across the buffer.  Raising the ceiling further buys very little: the four
washes are held to a common luminance, so they separate on chroma alone
and that curve flattens fast.")

(defvar zetta-highlight-hue-separation 0.13
  "Least distance, in turns of the colour wheel, between two highlighter hues.
0.13 is a little under 50 degrees; four hues have 0.25 to play with, so this
leaves a theme most of its own character and only bends a genuine collision.")

(defun zetta-highlight-hues ()
  "The four highlighter hues, spread apart wherever the theme crowds them.
Ordered so `error' and `success' keep their own hue outright -- red for
broken and green for fine are the two a reader decodes without thinking --
and `warning' or `accent' is what moves when a palette has to give."
  (let* ((kinds '(error success warning accent))
         (colors (mapcar #'zetta-theme-color kinds))
         (hues (zetta-hue-separate (mapcar #'zetta-hue-of colors)
                                   zetta-highlight-hue-separation)))
    (cl-mapcar (lambda (kind color hue)
                 (cons kind (if hue (zetta-with-hue color hue) color)))
               kinds colors hues)))

(defun zetta-highlight-refresh-faces ()
  "Re-tint the log highlighter faces from the current theme."
  (when (fboundp 'zetta-hue-wash)
    (let ((hues (zetta-highlight-hues)))
      (pcase-dolist (`(,face ,kind . ,anchor) zetta-highlight-slots)
      (when (and (facep face) (boundp anchor))
        (let ((wash (zetta-hue-wash (alist-get kind hues)
                                    (symbol-value anchor)
                                    zetta-highlight-saturation)))
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
    ;; mutations -- notable rather than good, but they are the writes, so
    ;; they take the strong end of the hue the reads sit on
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
