;;; org.el --- Configure org-mode -*- lexical-binding: t; -*-

;;; Core org-mode setup (moved from bootstrap-org.el)

(defun zetta-org-sort-buffer (type)
  "Sort all entries in the buffer recursively by TYPE.
TYPE is a character: ?a alphabetic, ?t timestamp, ?p priority, ?o TODO order."
  (interactive "cSort by: [a]lpha [t]imestamp [p]riority [o]rder ")
  (org-map-entries (lambda () (ignore-errors (org-sort-entries nil type))) nil 'file))

;;; Calendar display and styling

(add-to-list 'display-buffer-alist
             '("\\*Calendar\\*"
               (display-buffer-in-side-window)
               (side . top)
               (slot . 0)
               (window-height . fit-window-to-buffer)
               (preserve-size . (nil . t))))

(setq calendar-week-start-day 1
      calendar-mark-holidays-flag t
      calendar-day-header-array ["Su" "Mo" "Tu" "We" "Th" "Fr" "Sa"]
      calendar-month-name-array ["Jan" "Feb" "Mar" "Apr" "May" "Jun"
                                 "Jul" "Aug" "Sep" "Oct" "Nov" "Dec"]
      calendar-month-abbrev-array ["Jan" "Feb" "Mar" "Apr" "May" "Jun"
                                   "Jul" "Aug" "Sep" "Oct" "Nov" "Dec"]
      calendar-intermonth-text
      '(propertize
        (format "%2d" (org-days-to-iso-week
                       (calendar-absolute-from-gregorian
                        (list month day year))))
        'font-lock-face 'font-lock-comment-face))

(add-hook 'calendar-mode-hook (lambda () (setq truncate-lines t)))

(defun zetta-calendar-grayscale-faces ()
  "Set calendar faces from the brushup gradient.

Previously six hardcoded greys behind an (if dark-p ...) test.  That flips
with the background but ignores the theme entirely -- #aaaaaa is the same
grey whatever palette is loaded.  The brushup foreground gradient already
expresses \"progressively less prominent than the body text\" in terms of
the live theme, which is exactly what a calendar wants."
  (let ((fg   (or (bound-and-true-p brushup-fg) (face-foreground 'default nil t)))
        (fg-3 (or (bound-and-true-p brushup-fg-3) (face-foreground 'shadow nil t)))
        (fg-5 (or (bound-and-true-p brushup-fg-5) (face-foreground 'shadow nil t)))
        (bg-2 (or (bound-and-true-p brushup-bg-2) (face-background 'default nil t))))
    (set-face-attribute 'calendar-today nil
                        :foreground fg :weight 'bold :underline t)
    (set-face-attribute 'calendar-weekday-header nil :foreground fg-3)
    (set-face-attribute 'calendar-weekend-header nil :foreground fg-5)
    (set-face-attribute 'holiday nil :foreground fg :background bg-2)
    (set-face-attribute 'calendar-month-header nil
                        :foreground fg-3 :weight 'bold)))

(add-hook 'calendar-mode-hook #'zetta-calendar-grayscale-faces)

(use-package org
  :ensure nil
  ;; \\' anchor is load-bearing: unanchored, this matched ".org" anywhere
  ;; in the PATH — e.g. kb/images/en.wikipedia.org/photo.jpg opened as an
  ;; org buffer of raw JPEG bytes.
  :mode ("\\.org\\'" . org-mode)

  :config
  (setq-default org-indent-mode nil)


  ;; LaTeX preview — dvisvgm produces SVG (vector, crisp on retina)
  (setq org-preview-latex-default-process 'dvisvgm)
  (plist-put org-format-latex-options :scale 1.5)

  (setq org-confirm-babel-evaluate nil
        org-src-preserve-indentation t
        org-tags-column 0
        org-table-convert-region-max-lines 10000
        org-use-fast-todo-selection 'expert
        org-attach-store-link-p 'file
        org-hide-leading-stars nil
        org-archive-location "(todo) archive.org::* From %s"
        org-agenda-files '()
        org-persist-directory (expand-file-name
                               ".data/org-persist"
                               user-emacs-directory)
        org-id-locations-file (expand-file-name
                               ".data/org/.org-id-locations"
                               user-emacs-directory)
        org-startup-folded (quote nofold)
        org-startup-indented t
        ;; Wrap #+begin_quote / #+begin_verse contents in the `org-quote' and
        ;; `org-verse' faces.  Off by default, which means that text carries
        ;; NO face at all and simply inherits `default' -- so any styling
        ;; aimed at `org-quote' silently does nothing.
        org-fontify-quote-and-verse-blocks t
        org-refile-use-outline-path 'file
        org-log-refile 'time
        org-log-redeadline 'time
        org-log-reschedule 'time
        org-log-into-drawer t
        zetta-org-log-initial-deadline 'time
        zetta-org-log-initial-schedule 'time
        org-outline-path-complete-in-steps nil
        org-refile-allow-creating-parent-nodes 'confirm
        ;; Files themselves are refile targets (filed as top-level
        ;; entries) — the flat (todo) files have no headings to file
        ;; under, and the capture flow is inbox-first + refile-later.
        org-refile-use-outline-path 'file
        org-refile-targets '((nil :maxlevel . 10)
                             (org-agenda-files :maxlevel . 10))
        org-src-window-setup 'plain
        org-src-lang-modes
        '(("bash" . sh) ("beamer" . latex) ("calc" . fundamental)
          ("emacs-lisp" . emacs-lisp) ("shell" . sh) ("sqlite" . sql)
          ("html" . web) ("js" . js2) ("jsx" . rjsx))
        org-table-shrunk-column-indicator "|"
        ;; 4-letter states (2026-08-08 migration: STARTED→PROG,
        ;; CANCELLED→NOPE; WAITING/NEXT/OBSOLETE had zero uses).
        ;; PROG = in progress, WAIT = blocked externally, QUES = open
        ;; question (pairs with the org-remark question pen), HOLD =
        ;; paused by choice (backlog skill vocabulary), IDEA =
        ;; someday/maybe, NOPE = cancelled.  Scheduling stays with
        ;; org's SCHEDULED timestamps, not a state.
        org-todo-keywords
        '((sequence
           "TODO(t!)"
           "PROG(p!)"
           "WAIT(w!)"
           "QUES(q!)"
           "HOLD(h!)"
           "IDEA(i!)"
           "|"
           "DONE(d!)"
           "NOPE(n!)")))

  ;; State faces.  A TODO keyword is a WORD -- "PROG", "WAIT", "NOPE" --
  ;; so it already says which state it is; the colour has nothing left to
  ;; encode but how much attention that state deserves.  Org's stock red
  ;; TODO and green DONE were the loudest thing on the page while saying
  ;; nothing the word did not, and they clash with any theme not built
  ;; around red and green.  So these walk the brushup ink ladder in four
  ;; prominence tiers, the same ladder `zetta-line-chip-ladder' and the VC
  ;; gutter markers use: loud or quiet by how far a state sits from the
  ;; page, never by what colour it is.  The rungs are `zetta-keyword-tiers',
  ;; shared with hl-todo -- which is hooked into `org-mode' and paints an
  ;; org heading's TODO on top of org's own face, so the two vocabularies
  ;; have to agree on what a given word weighs.
  ;;
  ;; The defface specs are cold-start fallbacks only, before
  ;; `zetta-org-todo-refresh-faces' has run.
  (defface zetta-org-todo-prog
    '((t :inherit org-todo)) "Face for the PROG todo keyword." :group 'org-faces)
  (defface zetta-org-todo-wait
    '((t :inherit org-todo)) "Face for the WAIT todo keyword." :group 'org-faces)
  (defface zetta-org-todo-ques
    '((t :inherit org-todo)) "Face for the QUES todo keyword." :group 'org-faces)
  (defface zetta-org-todo-hold
    '((t :inherit org-todo)) "Face for the HOLD todo keyword." :group 'org-faces)
  (defface zetta-org-todo-idea
    '((t :inherit org-todo)) "Face for the IDEA todo keyword." :group 'org-faces)
  (defface zetta-org-todo-nope
    '((t :inherit org-done :strike-through t))
    "Face for the NOPE todo keyword." :group 'org-faces)

  (defvar zetta-org-todo-face-tiers
    '((zetta-org-todo-prog . loud)
      (org-todo            . open)
      (zetta-org-todo-ques . open)
      (zetta-org-todo-wait . parked)
      (zetta-org-todo-hold . parked)
      (zetta-org-todo-idea . parked)
      (org-done            . closed)
      (zetta-org-todo-nope . closed))
    "Which prominence tier each TODO keyword face sits in.

Grouped by what the state asks of you, not by how far along it is.  WAIT
and HOLD differ in WHY nothing is happening -- blocked externally versus
parked by choice -- but they ask the same thing of a reader scanning the
file, which is nothing, so they share a rung and let the word carry the
rest.  `org-todo' and `org-done' are org's own faces, restyled here so a
keyword without an entry in `org-todo-keyword-faces' still follows the
ladder.")

  (defun zetta-org-todo-refresh-faces ()
    "Re-colour the org TODO keyword faces from the current theme's ink ladder."
    (pcase-dolist (`(,face . ,tier) zetta-org-todo-face-tiers)
      (when-let* (((facep face))
                  ((fboundp 'zetta-tier-color))
                  (color (zetta-tier-color tier)))
        (set-face-attribute
         face nil
         :foreground color
         ;; Weight is a second prominence axis that costs no colour: the
         ;; states that want something from you are heavy, the ones that
         ;; do not are not.  Org paints both `org-todo' and `org-done'
         ;; bold by default, which is half of why a finished heading used
         ;; to shout as loudly as an open one.
         :weight (if (memq tier '(loud open)) 'bold 'normal)
         ;; NOPE is the only struck state -- abandoned, not finished.
         ;; Set explicitly on every face so a theme that strikes `org-done'
         ;; does not leak the effect into the others.
         :strike-through (eq face 'zetta-org-todo-nope)))))
  (zetta-org-todo-refresh-faces)
  (add-to-list 'brushup-styles '(zetta-org-todo-refresh-faces) t)

  (setq org-todo-keyword-faces
        '(("PROG" . zetta-org-todo-prog)
          ("WAIT" . zetta-org-todo-wait)
          ("QUES" . zetta-org-todo-ques)
          ("HOLD" . zetta-org-todo-hold)
          ("IDEA" . zetta-org-todo-idea)
          ("NOPE" . zetta-org-todo-nope)))

  (defun orgtree-forward-orgtree (&optional arg)
    "Move ARG times to start of a set of the same orgtree characters."
    (interactive "P")
    (setq arg (or arg 1))
    (if (> arg 0)
        (progn (org-next-visible-heading 1) (point))
      (progn (org-next-visible-heading -1) (point))))

  (defun orgtree-backward-orgtree (&optional arg)
    "Move ARG times to end of a set of the same orgtree characters."
    (interactive "P")
    (orgtree-forward-orgtree (- (or arg 1))))

  (put 'orgtree 'forward-op 'orgtree-forward-orgtree)

  ;; Make org element types usable as thing-at-point things (bounds +
  ;; forward-op) so they work with `treesit-tap-forward-thing',
  ;; `bounds-of-thing-at-point' walkers, embark highlight (`*'), and
  ;; embark per-target-type nav (`C-j' / `C-k'). embark-org already
  ;; produces typed targets (e.g. `org-src-block') but supplies only
  ;; bounds via the target plist; thing-at-point itself doesn't know
  ;; how to find or move over them. This bridges that gap.
  (defun zetta-org-element-bounds (type)
    "Return (BEG . END) of nearest enclosing org element of TYPE at point."
    (when-let* ((elt (org-element-lineage (org-element-context)
                                          (list type) t)))
      (cons (org-element-property :begin elt)
            (org-element-property :end elt))))

  (defun zetta-org-define-element-thing (type forward-fn)
    "Define `org-TYPE' as a thing-at-point thing.
Bounds come from `zetta-org-element-bounds'; navigation uses
FORWARD-FN which must accept a numeric arg (positive = forward,
negative = backward)."
    (let ((sym (intern (format "org-%s" type))))
      (put sym 'bounds-of-thing-at-point
           (lambda () (zetta-org-element-bounds type)))
      (put sym 'forward-op forward-fn)
      sym))

  (defun zetta-org-forward-src-block (n)
    "Move N src blocks forward (negative for back)."
    (interactive "p")
    (if (>= n 0)
        (dotimes (_ n) (org-babel-next-src-block 1))
      (dotimes (_ (abs n)) (org-babel-previous-src-block 1))))

  (zetta-org-define-element-thing 'src-block
                                  'zetta-org-forward-src-block)

  ;; Map the embark target type onto the now-defined thing, so
  ;; Bridge E's C-j / C-k pick the right nav.
  (with-eval-after-load 'embark
    (setf (alist-get 'org-src-block embark-scope-nav-type-map)
          'org-src-block))

  (defun zett-org-get-title (file)
    (let (title)
      (when file
        (with-current-buffer
            (get-file-buffer file)
          (pcase (org-collect-keywords '("TITLE"))
            (`(("TITLE" . ,val))
             (setq title (car val)))))
        (if title
            title
          ""))))

  (defun zetta-org-open-at-point ()
    (interactive)
    (let ((browse-url-browser-function 'browse-url-default-browser))
      (call-interactively 'org-open-at-point)))

  (add-to-list
   'brushup-styles
   '(progn
      (set-face-attribute 'org-level-1 nil :height 0.9 :weight 'normal :slant 'normal :background brushup-bg :overline brushup-fg :extend nil :underline nil)
      (set-face-attribute 'org-level-2 nil :height 0.9 :weight 'normal :slant 'normal :background brushup-bg :overline brushup-fg :extend nil :underline nil)
      (set-face-attribute 'org-level-3 nil :height 0.9 :weight 'normal :slant 'normal :background brushup-bg :overline brushup-fg :extend nil :underline nil)
      (set-face-attribute 'org-level-4 nil :height 0.9 :weight 'normal :slant 'normal :background brushup-bg :overline brushup-fg :extend nil :underline nil)
      (set-face-attribute 'org-level-5 nil :height 0.9 :weight 'normal :slant 'normal :background brushup-bg :overline brushup-fg :extend nil :underline nil)
      (set-face-attribute 'org-level-6 nil :height 0.9 :weight 'normal :slant 'normal :background brushup-bg :overline brushup-fg :extend nil :underline nil)
      (set-face-attribute 'org-level-7 nil :height 0.9 :weight 'normal :slant 'normal :background brushup-bg :overline brushup-fg :extend nil :underline nil)
      (set-face-attribute 'org-level-8 nil :height 0.9 :weight 'normal :slant 'normal :background brushup-bg :overline brushup-fg :extend nil :underline nil)
      (set-face-attribute 'org-tag nil :height 1.00 :weight 'normal :slant 'normal :background brushup-bg-1_0 :foreground brushup-fg :underline nil :extend nil :overline t)
      (set-face-attribute 'org-block nil :background brushup-bg-1_0 :extend nil)
      (set-face-attribute 'org-block-begin-line nil :background brushup-bg-1_0 :underline brushup-bg-1 :weight 'normal :extend nil :foreground brushup-bg-6 :overline brushup-bg-3 :height 0.9)
      (set-face-attribute 'org-block-end-line nil :background brushup-bg-1_0 :weight 'normal :extend nil :foreground brushup-bg-3 :underline nil :overline nil :height 0.8)

      (set-face-attribute 'org-special-keyword nil :background brushup-bg :foreground brushup-bg-6 :extend nil)
      (set-face-attribute 'org-property-value nil :background brushup-bg :foreground brushup-bg-6 :extend nil)
      (set-face-attribute 'org-document-info-keyword nil :background brushup-bg :foreground brushup-bg-6 :extend nil)))

  (defun zetta-org-go ()
    (interactive)
    (org-refile '(1)))

  (defun zetta-org-append ()
    (interactive)
    (org-insert-heading-respect-content)
    (when (fboundp 'evil-append) (evil-append 1)))

  (defun zetta-org-append-todo ()
    (interactive)
    (org-insert-heading-respect-content)
    (when (fboundp 'evil-append) (evil-append 1)))

  (defun call-zetta-org-todo-with-prefix ()
    (interactive)
    (let ((current-prefix-arg '(4)))
      (call-interactively 'zetta-org-todo)))

  (defun zetta-org-call-tangle-with-prefix ()
    (interactive)
    (setq current-prefix-arg '(4))
    (call-interactively 'org-babel-tangle))

  :general
  (
   :keymaps '(org-mode-map)
   "<S-return>" 'org-edit-special
   "C-+" 'org-table-expand
   "C-_" 'org-table-shrink
   ;; org-mode binds C-, to `org-cycle-agenda-files' by default,
   ;; which shadows the global launch-map prefix from
   ;; `bootstrap-keys.el'.  Restore launch-map here.
   "C-," 'launch-map
   ;; `s-j' / `s-k' navigate by `treesit-tap-current-thing' (whatever
   ;; M-x treesit-tap-set-local was last invoked with, default `defun').
   ;; `s-J' / `s-K' still walk babel blocks. Old heading navigation
   ;; (`org-next/previous-visible-heading') remains on `org-shiftup' /
   ;; `org-shiftdown' and the standard org outline-cycle bindings.
   "s-j" 'treesit-tap-next
   "s-k" 'treesit-tap-prev
   "s-J" 'org-babel-next-src-block
   "s-K" 'org-babel-previous-src-block)
  (
   :keymaps '(org-mode-map org-agenda-mode-map)
   "C-c C-S-o" 'zetta-org-open-at-point
   "C-c C-o" 'org-open-at-point)
  (
   :keymaps '(org-agenda-mode-map)
   "C-c d" 'org-agenda-goto-date)
  (
   :keymaps '(org-mode-map)
   "C-c S" 'zetta-org-sort-buffer)

  :hook (
         (org-ctrl-c-ctrl-c-final . org-table-shrink)
         (org-mode . (lambda () (progn
                                  (auto-fill-mode -1)
                                  (org-indent-mode -1)
                                  (visual-line-mode -1)
                                  (electric-indent-mode -1)
                                  (toggle-truncate-lines -1)
                                  (when (fboundp 'undo-tree-mode)
                                    (undo-tree-mode +1)))))))

;; Auto-toggle LaTeX previews: render when cursor leaves, show source when entering
(use-package org-fragtog
  :hook (org-mode . org-fragtog-mode))

(with-eval-after-load 'evil
  (evil-set-initial-state 'org-mode 'normal))

(when (fboundp 'repeatable-wrap)
  (general-define-key
   :keymaps 'menu-org-map
   "g" (** zetta-org-go)
   "j" (** org-next-visible-heading)
   "k" (** org-previous-visible-heading)
   "U" (** outline-up-heading)
   "J" (** org-move-subtree-down)
   "K" (** org-move-subtree-up)

   "a" (** zetta-org-append)
   "T" (** zetta-org-append-todo)
   "8" (** org-toggle-heading)
   "o" 'org-capture
   "z" (** org-add-note)
   "S" (** org-schedule)
   "D" (** org-deadline)
   "t" (** call-zetta-org-todo-with-prefix)

   "h" (** org-metaleft)
   "H" (** org-shiftmetaleft)
   "l" (** org-metaright)
   "L" (** org-shiftmetaright)
   "-" (** org-cycle-list-bullet)
   "r" (** org-refile)
   "A" (** org-archive-subtree)
   "s" (** org-sort)
   "q" (** org-columns-quit)

   "TAB" (** org-cycle)
   "S-TAB" (** org-global-cycle)
   "i" (** org-tree-to-indirect-buffer)
   "G" (** org-sparse-tree)

   "m" (** org-mark-element)
   "M" (** org-mark-subtree)
   "C-t" (** zetta-org-call-tangle-with-prefix)
   "C-S-t" (** org-babel-tangle)))

;;; Logseq TODO files management
;; zetta-logseq-dir is defined in bootstrap-modules.el
(defvar zetta-logseq-pages-dir zetta-logseq-dir
  "Directory containing logseq pages.  Defaults to `zetta-logseq-dir'.")

(defun zetta-logseq-todo-files ()
  "Return list of files in logseq pages starting with '(todo)'."
  (when (file-directory-p zetta-logseq-pages-dir)
    (directory-files zetta-logseq-pages-dir t "^(todo).*\\.org$")))

(defun zetta-logseq-todo-file-name (file)
  "Extract the name part from a (todo) FILE path.
E.g., '(todo) emacs.org' -> 'emacs'"
  (let ((basename (file-name-base file)))
    (if (string-match "^(todo) \\(.+\\)$" basename)
        (match-string 1 basename)
      basename)))

(defun zetta-logseq-todo-capture-key (name)
  "Generate a capture key from NAME.
Uses first letter, or first two letters if conflicts exist."
  (downcase (substring name 0 1)))

(defun zetta-logseq-generate-capture-templates ()
  "Generate org-capture templates for all (todo) files."
  (let ((files (zetta-logseq-todo-files))
        (used-keys '())
        templates)
    (dolist (file files)
      (let* ((name (zetta-logseq-todo-file-name file))
             (base-key (zetta-logseq-todo-capture-key name))
             (key (if (member base-key used-keys)
                      (let ((i 2) new-key)
                        (while (member (setq new-key (format "%s%d" base-key i)) used-keys)
                          (setq i (1+ i)))
                        new-key)
                    base-key)))
        (push key used-keys)
        (push (list key
                    (format "TODO → %s" name)
                    'entry
                    (list 'file file)
                    "* TODO %?\n:PROPERTIES:\n:CREATED: %U\n:END:\n"
                    :prepend t)
              templates)))
    (nreverse templates)))

(defvar zetta-extra-agenda-files '()
  "Additional files to add to `org-agenda-files'.
Set this in ~/.private.el before modules load.")

(defun zetta-logseq-update-agenda-files ()
  "Add all (todo) files and `zetta-extra-agenda-files' to org-agenda-files."
  (let ((todo-files (zetta-logseq-todo-files)))
    (dolist (file todo-files)
      (add-to-list 'org-agenda-files file t)))
  (dolist (file zetta-extra-agenda-files)
    (when (file-exists-p file)
      (add-to-list 'org-agenda-files file t))))

;;; org-capture configuration (deferred until org loads)
(with-eval-after-load 'org
  (require 'org-capture)
  ;; mu4e-org (ships with mu4e's site-lisp) registers mu4e: org links so
  ;; %a from a mu4e buffer captures a link back to the message.
  (when (locate-library "mu4e-org")
    (require 'mu4e-org))
  ;; Two-gesture capture: notes land in the inbox (n, or N with an
  ;; org backlink to wherever capture was invoked via %a); TODO-ing
  ;; and routing happen later — C-c C-w in the capture buffer
  ;; (org-capture-refile) files directly elsewhere when the target is
  ;; already known.  The per-(todo)-file templates are retired: refile
  ;; covers routing (org-refile-use-outline-path 'file makes the flat
  ;; todo files themselves valid targets).  m stays as the mail
  ;; specialization — the sender/subject prefill has no generic
  ;; equivalent (%:fromname/%:subject only bind in mail buffers).
  (setq org-capture-templates
        '(("n" "Note"
           entry
           (file "~/kb/inbox.org")
           "* %?\n:PROPERTIES:\n:CREATED: %U\n:END:\n"
           :prepend t)
          ("N" "Note (with backlink)"
           entry
           (file "~/kb/inbox.org")
           "* %?\n:PROPERTIES:\n:CREATED: %U\n:END:\n%a\n"
           :prepend t)
          ("m" "Mail (capture message link)"
           entry
           (file "~/kb/todo/(todo) email.org")
           "* TODO %:fromname: %:subject\n:PROPERTIES:\n:CREATED: %U\n:END:\n%a\n%?"
           :prepend t)))
  (zetta-logseq-update-agenda-files))

;;; Log initial deadline/schedule creation
(defcustom zetta-org-log-initial-deadline nil
  "Non-nil means log when a deadline is initially set.
Can be `time' to log just timestamp, `note' to also prompt for a note,
or nil to disable."
  :type '(choice (const :tag "Off" nil)
                 (const :tag "Time" time)
                 (const :tag "Note" note))
  :group 'org)

(defcustom zetta-org-log-initial-schedule nil
  "Non-nil means log when a schedule is initially set.
Can be `time' to log just timestamp, `note' to also prompt for a note,
or nil to disable."
  :type '(choice (const :tag "Off" nil)
                 (const :tag "Time" time)
                 (const :tag "Note" note))
  :group 'org)

(defun zetta-org--log-initial-timestamp (type timestamp)
  "Log initial creation of TYPE (deadline or scheduled) with TIMESTAMP."
  (let* ((log-setting (if (eq type 'deadline)
                          zetta-org-log-initial-deadline
                        zetta-org-log-initial-schedule))
         (note-text (format "Initially %s on %s"
                            (if (eq type 'deadline) "set deadline" "scheduled")
                            (format-time-string
                             (org-time-stamp-format 'long 'inactive)))))
    (when log-setting
      (org-add-log-setup (if (eq type 'deadline) 'redeadline 'reschedule)
                         timestamp nil log-setting note-text))))

(defun zetta-org-deadline-log-initial-a (orig-fun &optional arg time)
  "Advice to log when a deadline is initially set (not just changed)."
  (let ((had-deadline (org-entry-get nil "DEADLINE")))
    (funcall orig-fun arg time)
    (when (and (not had-deadline)
               (not (equal arg '(4)))
               zetta-org-log-initial-deadline
               (org-entry-get nil "DEADLINE"))
      (zetta-org--log-initial-timestamp 'deadline (org-entry-get nil "DEADLINE")))))

(defun zetta-org-schedule-log-initial-a (orig-fun &optional arg time)
  "Advice to log when a schedule is initially set (not just changed)."
  (let ((had-schedule (org-entry-get nil "SCHEDULED")))
    (funcall orig-fun arg time)
    (when (and (not had-schedule)
               (not (equal arg '(4)))
               zetta-org-log-initial-schedule
               (org-entry-get nil "SCHEDULED"))
      (zetta-org--log-initial-timestamp 'scheduled (org-entry-get nil "SCHEDULED")))))

(advice-add 'org-deadline :around #'zetta-org-deadline-log-initial-a)
(advice-add 'org-schedule :around #'zetta-org-schedule-log-initial-a)

;;; Additional org-mode configuration

(use-package origami
  :init
  ;; Pre-define the face before origami loads.  The upstream defface uses
  ;; bare `:line-width 1` (needs cons cell in Emacs 29+) and unguarded
  ;; `face-attribute` that returns `unspecified` in batch mode.  Defining
  ;; the face here makes the upstream defface a no-op.
  (let ((bg (or (face-attribute 'highlight :background nil t) "gray")))
    (when (eq bg 'unspecified) (setq bg "gray"))
    (defface origami-fold-header-face
      `((t (:box (:line-width (1 . 1) :color ,bg) :background ,bg)))
      "Face used to display fold headers.")))

;; basic tweaks and bindings
(setenv "BROWSER" "chrome")

;; ob-restclient and ob-http alternatives
(use-package verb
  :after org
  :config
  (define-key org-mode-map (kbd "C-c C-r") verb-command-map)
  (org-babel-do-load-languages
   'org-babel-load-languages
   '((python . t) (emacs-lisp . t) (sql . t) (C . t) (sqlite . t)
     (js . t) (ditaa . t) (dot . t) (shell . t ) (latex . t )
     (verb . t)))
  )

;; by default, make inline images look like thumbnails.  If using
;; actual width of the image, then it takes up too much space in the
;; buffer
;;(setq org-image-actual-width 200)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; Flow / tasks
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;  Super Agenda

;; export backends
;;(require 'ox-beamer)
(use-package epresent)
(use-package ox-reveal
  :config
  (setq org-reveal-root "https://cdnjs.cloudflare.com/ajax/libs/reveal.js/3.6.0/"
        org-reveal-mathjax t))
(use-package htmlize )
(use-package ox-jekyll-md)

;; from the docs
;; "To stop Org from evaluating code blocks to speed exports, use the
;; header argument ‘:eval never-export’ (see Evaluating Code
;; Blocks). To stop Org from evaluating code blocks for greater
;; security, set the org-export-use-babel variable to nil, but
;; understand that header arguments will have no effect."
;; NOTE setting this to nil causes issues.  when dealing with an org
;; document and hot exporting, you can increase efficiency by
;; narrowing the buffer
(setq org-export-use-babel t)

;; convenient super bindinigs for organization
(setq zetta-captured-from-win "")

(general-define-key
 :kemaps 'override
 "s-t" '(lambda () (interactive)
          (setq zetta-captured-from-win (selected-window))
          (org-capture nil "h")
          (org-set-property "received" (format-time-string "%Y-%m-%d %a %H:%M"))
          (org-id-get-create)
          )
 "s-T" '(lambda () (interactive)
          (setq zetta-captured-from-win (selected-window))
          (org-capture nil "H")
          (org-set-property "received" (format-time-string "%Y-%m-%d %a %H:%M"))
          (org-id-get-create)
          )
 )

;; note order matters here as there is overlap between org
;; roam and org-mode (org-roam is in org mode, but it matches
;; for this first, so it displays in slot 2, not slot 1)
;;(zetta-side "^\\*org-roa*" 'right 2 0.20 0.30)

;;;;;;;;;;;;;;;;; Literature management
;;(zetta-side "bibliography.bib" 'right 2 0.30)

(setq org-ref-insert-link-function 'org-ref-insert-link-hydra/body
      org-ref-insert-label-function 'org-ref-insert-label-link
      org-ref-insert-ref-function 'org-ref-insert-ref-link
      org-ref-cite-onclick-function (lambda (_) (org-ref-citation-hydra/body)))

(defun gpc/open-node-roam-ref-url ()
  "Open the URL in this node's ROAM_REFS property, if one exists"
  (interactive)
  (when-let* ((ref-url (org-entry-get-with-inheritance "ROAM_REFS")))
    (browse-url ref-url)))

(defun gpc/open-node-roam-ref-url-eww ()
  "Open the URL in this node's ROAM_REFS property, if one exists"
  (interactive)
  (when-let* ((ref-url (org-entry-get-with-inheritance "ROAM_REFS")))
    (eww-browse-url ref-url)))

;;(add-hook 'org-mode-hook (lambda () (font-lock-add-keywords
;;nil
;;'(("^-\\{5,\\}"  0 '(:foreground "red" :weight bold))))))

;;(remove-hook 'org-mode-hook (lambda () (undo-tree-mode 1)))

(setq org-id-link-to-org-use-id t)

(setq org-time-stamp-formats
      '("<%Y-%m-%d %a>" . "<%Y-%m-%d %a %H:%M:%S>"))

(use-package ox
  :ensure nil
  :demand t
  :config
  ;; Load ox-md first so we can derive from 'md backend
  (require 'ox-md)
  ;; fropm https://emacs.stackexchange.com/questions/42471/how-to-export-markdown-from-org-mode-with-syntax
  (org-export-define-derived-backend 'mymd 'md
    :menu-entry
    '(?y "Export to My Markdown"
         ((?M "To temporary buffer"
              (lambda (a s v b) (org-mymd-export-as-markdown a s v)))
          (?m "To file" (lambda (a s v b) (org-mymd-export-to-markdown a s v)))
          (?o "To file and open"
              (lambda (a s v b)
                (if a (org-mymd-export-to-markdown t s v)
                  (org-open-file (org-mymd-export-to-markdown nil s v)))))))
    :translate-alist '((example-block . org-mymd-example-block)
                       (fixed-width . org-mymd-example-block)
                       (src-block . org-mymd-example-block)))

  (defun org-mymd-example-block (example-block _content info)
    "Transcode element EXAMPLE-BLOCK as ```lang ...'''."
    (format "```%s\n%s\n```"
            (org-element-property :language example-block)
            (org-remove-indentation
             (org-export-format-code-default example-block info))))

;;;###autoload
  (defun org-mymd-export-as-markdown (&optional async subtreep visible-only)
    "See `org-md-export-as-markdown'."
    (interactive)
    (org-export-to-buffer 'mymd "*Org My MD Export*"
      async subtreep visible-only nil nil (lambda () (text-mode))))

;;;###autoload
  (defun org-mymd-convert-region-to-md ()
    "See `org-md-convert-region-to-md'."
    (interactive)
    (org-export-replace-region-by 'mymd))

;;;###autoload
  (defun org-mymd-export-to-markdown (&optional async subtreep visible-only)
    "See `org-md-export-to-markdown'."
    (interactive)
    (let ((outfile (org-export-output-file-name ".md" subtreep)))
      (org-export-to-file 'mymd outfile async subtreep visible-only)))

;;;###autoload
  (defun org-mymd-publish-to-md (plist filename pub-dir)
    "Analogous to `org-md-publish-to-md'."
    (org-publish-org-to 'mymd filename ".md" plist pub-dir))

  (setq org-pandoc-options-for-markdown '((wrap . none)))

  )

(defun org-babel-tangle--unbracketed-link (params)
  "Get a raw link to the src block at point, without brackets.

The PARAMS are the 3rd element of the info for the same src block."
  (unless (string= "no" (cdr (assq :comments params)))
    (save-match-data
      (let* (;; The created link is transient.  Using ID is not necessary,
             ;; but could have side-effects if used.  An ID property may
             ;; be added to existing entries thus creating unexpected file
             ;; modifications.
             ;; CHANGED
             ;;(org-id-link-to-org-use-id nil)
             (l (org-no-properties
                 (cl-letf (((symbol-function 'org-store-link-functions)
                            (lambda () nil)))
                   (org-store-link nil))))
             (bare (and (string-match org-link-bracket-re l)
                        (match-string 1 l))))
        (when bare
          (if (and org-babel-tangle-use-relative-file-links
                   (string-match org-link-types-re bare)
                   (string= (match-string 1 bare) "file"))
              (concat "file:"
                      (file-relative-name (substring bare (match-end 0))
                                          (file-name-directory
                                           (cdr (assq :tangle params)))))
            bare))))))

;; needed by my blog
(defun org-add-custom-ids ()
  "Add CUSTOM_ID properties to each heading in the current Org buffer."
  (interactive)
  (save-excursion
    (goto-char (point-min))
    (while (re-search-forward org-heading-regexp nil t)
      (let* ((heading (org-get-heading t t t t))
             (custom-id (replace-regexp-in-string
                         "[^a-zA-Z0-9_-]" "-"
                         (downcase heading)))
             (existing-id (org-entry-get nil "CUSTOM_ID")))
        (org-set-property "CUSTOM_ID" custom-id)))))

(defvar my-org-treemap-temp-file "~/treemap.html") ; Firefox inside Snap can't access /tmp
(defvar my-org-treemap-command "treemap" "Executable to generate a treemap.")

(defun my-org-treemap-include-p (node)
  (not (or (member "notree" (org-element-property :tags node))
           (org-element-property-inherited :archivedp node 'with-self))))

(defun my-org-treemap--node-label (node)
  "Return heading title with CUSTOM_ID appended if present."
  (let ((title (org-no-properties (org-element-property :raw-value node)))
        (cid   (org-element-property :CUSTOM_ID node)))
    (if cid
        (format "%s" cid)
      title)))

(defun my-org-treemap-data (node &optional path)
  "Output the size of headings underneath this one."
  (let ((sub
         (apply
          'append
          (org-element-map
              (org-element-contents node)
              '(headline)
            (lambda (child)
              (if (my-org-treemap-include-p child)
                  (my-org-treemap-data
                   child
                   (append path (list (my-org-treemap--node-label node))))
                (list
                 (list
                  (-
                   (org-element-end child)
                   (org-element-begin child))
                  (string-join
                   (cdr
                    (append path
                            (list
                             (my-org-treemap--node-label node)
                             (my-org-treemap--node-label child))))
                   "/")
                  nil))))
            nil nil 'headline))))
    (append
     (list
      (list
       (-
        (org-element-end node)
        (org-element-begin node)
        (apply '+ (mapcar 'car sub))
        )
       (string-join
        (cdr
         (append path
                 (list (my-org-treemap--node-label node))))
        "/")
       (my-org-treemap-include-p node)))
     sub)))

(defun my-org-treemap ()
  "Generate a treemap."
  (interactive)
  (save-excursion
    (goto-char (point-min))
    (let ((file (expand-file-name (expand-file-name my-org-treemap-temp-file)))
          (data (cdr (my-org-treemap-data (org-element-parse-buffer)))))
      (with-temp-file file
        (call-process-region
         (mapconcat
          (lambda (entry)
            (if (elt entry 2)
                (format "%d %s\n" (car entry)
                        (replace-regexp-in-string org-link-bracket-re "\\2" (cadr entry)))
              ""))
          data
          "")
         nil
         my-org-treemap-command nil t t))
      (browse-url (concat "file://" (expand-file-name my-org-treemap-temp-file))))))

;; for blog
(setq org-use-sub-superscripts '{})
(setq org-export-with-sub-superscripts nil)

(setq org-html-with-latex 'mathjax)

;;; Logseq journals view

(defun zetta-logseq--ordinal-suffix (day)
  "Return ordinal suffix for DAY (1-31)."
  (cond
   ((memq day '(11 12 13)) "th")
   ((= (% day 10) 1) "st")
   ((= (% day 10) 2) "nd")
   ((= (% day 10) 3) "rd")
   (t "th")))

(defun zetta-logseq--format-date (time)
  "Format TIME as a Logseq journal date string like [[Mar 10th, 2026]]."
  (let ((day (string-to-number (format-time-string "%d" time))))
    (format "[[%s %d%s, %s]]"
            (format-time-string "%b" time)
            day
            (zetta-logseq--ordinal-suffix day)
            (format-time-string "%Y" time))))

(defun zetta-logseq--file-headings (file cache)
  "Return an alist of (LINE-NUMBER . HEADING-TEXT) for FILE.
Results are cached in hash table CACHE."
  (or (gethash file cache)
      (puthash file
               (with-temp-buffer
                 (insert-file-contents file)
                 (let ((headings nil)
                       (line 0))
                   (while (not (eobp))
                     (cl-incf line)
                     (when (looking-at "\\(\\*+\\)[ \t]+\\(.*\\)")
                       (push (cons line (match-string 2)) headings))
                     (forward-line 1))
                   (nreverse headings)))
               cache)))

(defun zetta-logseq--heading-at (line headings)
  "Find the nearest heading at or before LINE in HEADINGS alist."
  (let ((best nil))
    (dolist (h headings best)
      (when (<= (car h) line)
        (setq best (cdr h))))))

(defun zetta-logseq-journals (&optional dir n)
  "Show an org buffer with Logseq journal references for the last N days.
DIR is the Logseq graph directory to search (defaults to
`zetta-logseq-pages-dir').  N defaults to 30.
Each date becomes a heading; under it are org links to every
location where that date's journal link appears, annotated with
the nearest heading from the source file."
  (interactive (list (when current-prefix-arg
                       (read-directory-name "Logseq directory: " zetta-logseq-pages-dir))
                     (when current-prefix-arg
                       (read-number "Number of days: " 30))))
  (let* ((dir (or dir zetta-logseq-pages-dir))
         (n (or n 30))
         (dates (cl-loop for i from 0 below n
                         for time = (time-subtract (current-time)
                                                   (days-to-time i))
                         collect (cons (zetta-logseq--format-date time) time)))
         (rg-args (append (list "--no-heading" "-n" "--fixed-strings")
                          (cl-loop for (date . _) in dates
                                   append (list "-e" date))
                          (list (expand-file-name dir))))
         (hits (apply #'process-lines "rg" rg-args))
         (results (make-hash-table :test 'equal))
         (heading-cache (make-hash-table :test 'equal))
         (abs-dir (expand-file-name dir)))
    ;; group hits by date
    (dolist (line hits)
      (when (string-match "\\`\\(.+\\):\\([0-9]+\\):\\(.*\\)\\'" line)
        (let ((file (match-string 1 line))
              (lnum (match-string 2 line))
              (text (string-trim (match-string 3 line))))
          (dolist (entry dates)
            (when (string-search (car entry) text)
              (push (list file lnum text) (gethash (car entry) results)))))))
    ;; build org buffer
    (let ((buf (get-buffer-create "*Logseq Journals*")))
      (with-current-buffer buf
        (let ((inhibit-read-only t))
          (erase-buffer)
          (org-mode)
          (insert "#+title: Logseq Journals\n\n")
          (dolist (entry dates)
            (let* ((date-str (car entry))
                   (matches (reverse (gethash date-str results))))
              (insert (format "* %s\n" date-str))
              (if matches
                  (dolist (m matches)
                    (cl-destructuring-bind (file lnum text) m
                      (let* ((rel (file-relative-name file abs-dir))
                             (headings (zetta-logseq--file-headings file heading-cache))
                             (heading (zetta-logseq--heading-at
                                       (string-to-number lnum) headings))
                             (context (string-trim
                                       (replace-regexp-in-string
                                        (regexp-quote date-str) "" text))))
                        (insert (format "- [[file:%s::%s][%s]] — %s%s\n"
                                        file lnum rel
                                        (if heading
                                            (format "*%s* · " heading)
                                          "")
                                        context)))))
                (insert "  /no references/\n"))
              (insert "\n")))))
      (pop-to-buffer buf)
      (goto-char (point-min)))))

;;; org.el ends here
