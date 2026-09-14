;;; hyperbole.el --- Configure GNU Hyperbole -*- lexical-binding: t; -*-

;; GNU Hyperbole: hypertextual information management — implicit buttons,
;; the Koutliner, HyRolo, smart keys, etc.  Installed from GNU ELPA via elpaca.
;;
;; We keep Hyperbole's FULL default key setup (`hkey-init' = t: shift-mouse
;; Smart Keys, the C-c bindings, etc.) but relocate the two bindings that
;; would clash with this distro:
;;
;;   * The minibuffer menu, default {C-h h}, is moved to {C-h H} so the stock
;;     {C-h h} (view-hello-file) and the which-key/embark `C-h' prefix help are
;;     left untouched.
;;   * The keyboard Action Key, default {M-RET} (which org-mode wants for
;;     `org-meta-return'), is moved to {s-H}.  The Assist Key is the prefixed
;;     variant {C-u s-H}.  The shift-mouse Smart Keys keep their defaults.

;; --- Fix HyRolo's consult-grep handoff for directory search paths ---
;; When `hyrolo-file-list' contains a directory, the interactive grep
;; commands (`hyrolo-grep'/`hyrolo-fgrep') read input through consult, which
;; runs ripgrep *inside* that directory and so reports bare file names
;; relative to it.  `hyrolo-grep-input' hands those names back, and HyRolo
;; then re-expands them against the invocation `default-directory' (not the
;; search dir), producing non-existent paths -- so the assembled *HyRolo*
;; buffer shows "No matching entries" even though consult found matches.
;; Re-root the names against `hyrolo-file-list' so only the matched files are
;; assembled (fast) and the consult front-end is left untouched.

(defun zetta-hyrolo--search-roots ()
  "Directory roots to resolve consult-relative HyRolo file names against.
Each entry of `hyrolo-file-list' contributes its own directory (a
directory entry contributes itself; a file or wildcard entry contributes
its parent directory)."
  (delq nil
        (mapcar (lambda (p)
                  (let ((ep (hpath:expand p)))
                    (if (file-directory-p ep)
                        (file-name-as-directory ep)
                      (file-name-directory ep))))
                hyrolo-file-list)))

(defun zetta-hyrolo--reroot (files roots)
  "Resolve each name in FILES to an existing path under one of ROOTS.
Absolute names are kept if they exist; search-relative names (as returned
by `consult-grep', which runs inside the search directory) are expanded
against ROOTS.  Unresolvable names are dropped."
  (delq nil
        (mapcar (lambda (f)
                  (if (file-name-absolute-p f)
                      (and (file-exists-p f) f)
                    (seq-some (lambda (root)
                                (let ((cand (expand-file-name f root)))
                                  (and (file-exists-p cand) cand)))
                              roots)))
                files)))

(defun zetta-hyrolo-fix-consult-handoff (result)
  "Re-root consult-grep's relative file names in RESULT for HyRolo's assembler.
`hyrolo-grep-input' returns (PATTERN MATCHING-FILES) when driven through
consult.  consult runs ripgrep inside the search directory, so
MATCHING-FILES are bare names relative to it; HyRolo would otherwise
re-expand them against the wrong `default-directory' and find nothing.
Resolve them against `hyrolo-file-list' so only the matched files are
assembled, leaving the consult front-end untouched.  If nothing resolves,
return RESULT unchanged so the assembler does not fall back to scanning
every file."
  (if (and (consp result) (consp (cdr result)) (cadr result))
      (let ((rerooted (zetta-hyrolo--reroot (cadr result)
                                            (zetta-hyrolo--search-roots))))
        (if rerooted
            (list (car result) rerooted)
          result))
    result))

;; --- HyRolo: retrieve matches WITH their ancestors ---
;; HyRolo retrieval is downward-only: a match pulls in its entry plus all
;; descendants, never the ancestor headings above it (verified empirically,
;; 2026-08-06).  The logical-search engine can do better: with its
;; INCLUDE-SUB-ENTRIES flag, `hyrolo-fgrep-logical' evaluates the query over
;; each entry's whole subtree starting from the top level, so a deep match
;; causes the top-level ancestor to match and the entire hierarchy is
;; emitted -- ancestors, descendants, and siblings within that tree.  No
;; defcustom exposes this, and the interactive spec feeds the same prefix
;; arg to both COUNT-ONLY and INCLUDE-SUB-ENTRIES (so {C-u} gets you a
;; count, not the hierarchy) -- hence this wrapper.  Caveat: unlike the
;; consult-driven greps (ripgrep), the logic engine loads and scans every
;; rolo file in elisp, so a search over the full ~/kb file list blocks for
;; a while -- expect seconds, not instant.


;;; --- HyRolo over the (todo) corpus -------------------------------------
;;
;; The rolo reads the same (todo) files the agenda and `org-queue' do, and
;; it has to follow the same test/real switch: `zetta-org-toggle-todo-source'
;; rebuilds `org-agenda-files' from scratch precisely so the two corpora can
;; never both be live, and a rolo still pointed at ~/kb/todo/ during a test
;; session would reopen exactly that hole.
;;
;; In test mode the list is the fixture ALONE -- not the fixture plus the
;; usual notes and wiki roots.  A search run while testing should not be
;; able to surface real notes, the same reasoning that keeps
;; `zetta-extra-agenda-files' out of a test session.  The cost is that the
;; rolo stops being a general knowledge search until you toggle back, which
;; is the intended trade.
;;
;; Defined at top level, not in `:config': `use-package hyperbole' is
;; `:defer 1', so its config runs a second AFTER the modules finish loading.
;; A toggle in between would otherwise be silently overwritten -- so the
;; toggle and the config call the same function, and whichever runs last
;; produces the same answer.

(defvar zetta-org-todo-source)
(declare-function zetta-org-todo-dir "org")
(declare-function zetta-logseq-todo-files "org")
(declare-function hyrolo-fgrep "hyrolo")
(declare-function hyrolo-grep "hyrolo")

(defcustom zetta-hyrolo-base-file-list
  (list "~/.rolo.org"
        (zetta-kb-file "notes/") (zetta-kb-file "wiki/") (zetta-kb-file "inbox.org")
        (zetta-kb-file "readwise/") (zetta-kb-file "org-remark/"))
  "Rolo sources that are not the (todo) corpus.
`zetta-hyrolo-update-file-list' appends the active (todo) directory to
these to produce `hyrolo-file-list'."
  :type '(repeat string) :group 'zetta)

(defun zetta-hyrolo-todo-dir ()
  "Return the active (todo) directory as a rolo path."
  (file-name-as-directory
   (if (fboundp 'zetta-org-todo-dir) (zetta-org-todo-dir) (zetta-kb-file "todo/"))))

(defun zetta-hyrolo-update-file-list ()
  "Rebuild `hyrolo-file-list' from the active (todo) corpus.
Returns the new list.

In real mode this is the base list, the (todo) directory, and
`zetta-extra-agenda-files' -- the project files ~/.private.el adds to the
agenda.  Those are agenda files, so the queue and every agenda command
already read them; a rolo that did not was quietly answering a different
question from everything else (measured: a day search for 2026-03-01
returned nothing while blog-posts.org carried `SCHEDULED: <2026-03-01 Sun>').

The capture inbox needs no special case here: `zetta-hyrolo-base-file-list'
has carried ~/kb/inbox.org since it was written, so the rolo has always
read it.  That is the opposite of the agenda, which was blind to the inbox
until `zetta-org-inbox-file' was added to the real corpus -- worth knowing
before adding it in both places and searching the file twice.

In test mode it is the fixture alone -- the extras follow the real kb and
stay out of a test session, the same rule `zetta-logseq-update-agenda-files'
applies."
  (setq hyrolo-file-list
        (if (and (boundp 'zetta-org-todo-source) (eq zetta-org-todo-source 'test))
            (list (zetta-hyrolo-todo-dir))
          (append zetta-hyrolo-base-file-list
                  (list (zetta-hyrolo-todo-dir))
                  (seq-filter #'file-exists-p
                              (bound-and-true-p zetta-extra-agenda-files))))))

(defun zetta-org-todo-rolo-open-regexp ()
  "Return a regexp matching any heading in a not-done state."
  (concat "^\\*+ +"
          (regexp-opt (or (and (boundp 'org-todo-keywords-1)
                               (boundp 'org-done-keywords)
                               (seq-difference org-todo-keywords-1
                                               org-done-keywords))
                          '("TODO" "PROG" "WAIT" "QUES" "HOLD" "IDEA"))
                      t)))

;;;###autoload
(defun zetta-org-todo-rolo (&optional all)
  "Search the active (todo) corpus with HyRolo.

Assembles matching entries from every agenda file into `*HyRolo*', with
each entry's sub-entries under it.  The scope is `org-agenda-files' --
the same set `org-queue' harvests and every agenda command reads, so a
browse and a plan can never disagree about what exists.  `e' there opens the entry in its own
file -- the display buffer is read-only, so this browses and jumps rather
than editing in place.

With ALL (\\[universal-argument]), skip the prompt and assemble every
entry in a not-done state: the whole open backlog, including HOLD and
IDEA, since this is a view rather than a plan.

The term is read through HyRolo's own input function, so this gets the
same live consult/vertico ripgrep -- completion, narrowing, preview --
that `M-x hyrolo-fgrep' gets, scoped to these files.

The file list is passed explicitly rather than through `hyrolo-file-list',
so this always reads the corpus the toggle currently selects even if
something else has rebound that variable."
  (interactive "P")
  (require 'hyrolo)
  (require 'hsys-consult nil t)
  (let ((files (org-agenda-files)))
    (unless files
      (user-error "No files in the %s corpus"
                  (if (boundp 'zetta-org-todo-source) zetta-org-todo-source "current")))
    (if all
        (hyrolo-grep (zetta-org-todo-rolo-open-regexp) nil files)
      ;; Route the prompt through `hyrolo-grep-input' rather than reading a
      ;; string ourselves.  With consult and vertico active -- which they
      ;; are here -- that runs a live ripgrep with completion and preview
      ;; over the files given, instead of a bare `read-string' with no
      ;; candidates; it is also the function `zetta-hyrolo-fix-consult-handoff'
      ;; above is advised onto, so calling it the other way silently opted
      ;; out of that repair too.  Mirrors `hyrolo-fgrep''s own interactive
      ;; spec, differing only in passing a scoped PATH-LIST.
      (let* ((input (hyrolo-grep-input #'read-string "Find rolo string" files))
             (matched (mapcar #'expand-file-name (or (cadr input) files))))
        (hyrolo-fgrep (car input) current-prefix-arg matched nil nil nil t)))))

(declare-function zetta-logseq--ordinal-suffix "org")
(declare-function hyrolo-expand-path-list "hyrolo")
(declare-function hyrolo-grep-input "hyrolo")

(defun zetta-hyrolo-day-regexp (time)
  "Return a regexp matching TIME's date the way this kb actually writes it.

Measured across the kb rather than assumed, because the two halves of it
disagree and share no substring:

  ~/kb/todo/   org timestamps, always ISO -- <2026-09-08 Tue>,
               [2026-09-08 Sun 11:59:56], SCHEDULED:/DEADLINE: lines.  A
               bare ISO date matches every one of those, brackets and
               planning keyword included, so it is not worth enumerating
               them.
  ~/kb/notes/  Logseq journal links -- [[Aug 12th, 2026]].  Month
               abbreviation and an ORDINAL day, so nothing about it
               resembles the ISO form and it has to be matched in its own
               right.  Built with `zetta-logseq--ordinal-suffix', the same
               function `zetta-logseq--format-date' uses to write them.

The two are alternated, so one day search covers both halves."
  (let* ((iso (format-time-string "%Y-%m-%d" time))
         (day (string-to-number (format-time-string "%d" time)))
         (journal (format "[[%s %d%s, %s]]"
                          (format-time-string "%b" time)
                          day
                          (if (fboundp 'zetta-logseq--ordinal-suffix)
                              (zetta-logseq--ordinal-suffix day)
                            "")
                          (format-time-string "%Y" time))))
    (concat "\\(" (regexp-quote iso) "\\|" (regexp-quote journal) "\\)")))

;;;###autoload
(defun zetta-hyrolo-day (&optional wide)
  "Assemble every entry mentioning a given day into `*HyRolo*'.

Prompts with `org-read-date', so the day can be given as a weekday name
\(\"tue\" -- the coming Tuesday, \"-tue\" the last one), \"today\",
an offset (\"+2\"), or a full date.  The date is then matched in both
forms this kb writes dates in; see `zetta-hyrolo-day-regexp'.

Searches the active (todo) corpus by default.  With WIDE
\(\\[universal-argument]) it searches the whole rolo corpus instead --
which is where the journal links are, and currently where nearly all the
dates are: the (todo) files carry 2 SCHEDULED and 6 DEADLINE between
them, so a day search over them alone will usually come back empty until
they are migrated."
  (interactive "P")
  (require 'hyrolo)
  (let* ((time (org-read-date nil t nil "Rolo day: "))
         (regexp (zetta-hyrolo-day-regexp time))
         (files (if wide
                    (hyrolo-expand-path-list hyrolo-file-list)
                  (org-agenda-files))))
    (unless files
      (user-error "No files to search in the %s corpus"
                  (if (boundp 'zetta-org-todo-source) zetta-org-todo-source
                    "current")))
    (message "%s across %d file%s"
             (format-time-string "%A %-d %B %Y" time)
             (length files) (if (= 1 (length files)) "" "s"))
    (hyrolo-grep regexp nil files)))

(declare-function ibut:create "hbut")

(defun zetta-hyperbole-quiet-ibut-probe (fn &rest args)
  "Run FN -- Hyperbole's implicit-button probe -- without org-element noise.

Pressing the Action Key runs every registered ibtype at point, and several
of them look for Org links in buffers that are not in Org mode; that is
deliberate (`org-link-outside-org-mode' exists for exactly that).  Org
answers by calling `display-warning' from `org-element-at-point', so a
single keypress in *HyRolo* emits

  Warning (org-element): `org-element-at-point' cannot be used in
  non-Org buffer #<buffer *HyRolo*> (hyrolo-mode)

Upstream tried to silence this -- `hsys-org-link-at-p' wraps its parse in
`with-suppressed-warnings ((org-element))' with a comment saying it works
outside Org mode anyway -- but that macro only affects the BYTE COMPILER.
It does nothing about a `display-warning' call at runtime, which is what
this is.  So suppress the display for the duration of the probe: the
warning is still logged to *Warnings*, it just stops interrupting."
  (let ((warning-suppress-types (cons '(org-element) warning-suppress-types)))
    (apply fn args)))

(defun zetta-hyperbole-ibtype-ignore-invalid-regexp (fn &rest args)
  "Run ibtype FN, treating an invalid regexp as \"no button here\".

`ibut:create' calls every ibtype inside a handler that does this:

  (error (progn (message \"%S: %S\" itype err) (debug)))

-- it pops the DEBUGGER on any error an ibtype signals, whatever
`debug-on-error' is set to.  So an ibtype that chokes on the text under
point does not fail quietly, it drops you into a backtrace.

`ibtypes::pathname' does choke: it builds a regexp out of text at point,
and some buffer contents produce (invalid-regexp \"Unmatched ) or \\\\)\").
An unparseable regexp built from arbitrary buffer text means \"this is not
a path\", which is a normal answer for a predicate, not a defect worth a
backtrace.  Other error classes are left alone so genuine breakage still
surfaces."
  (condition-case err
      (apply fn args)
    (invalid-regexp
     (message "Hyperbole ibtype skipped: %s" (error-message-string err))
     nil)))

(defvar hyrolo-auto-mode-alist)

(defun zetta-hyrolo-use-real-org-mode ()
  "Stop HyRolo opening .org files in `hyrolo-org-mode'.

HyRolo prepends `hyrolo-auto-mode-alist' to `auto-mode-alist' while it
reads files, so an .org file it opens gets `hyrolo-org-mode' -- an
`outline-mode' derivative that exists, in upstream's words, to avoid \"the
time-consuming initializations\" of the real major mode.  The let-binding
is scoped to the read, but THE BUFFER IS NOT: your (todo) files stay open
in that mode afterwards.

That breaks everything downstream, silently and confusingly, because
hyrolo does `(put 'hyrolo-org-mode 'derived-mode-parent 'org-mode)' -- so
`derived-mode-p' answers yes while none of Org's buffer-locals exist.
`org-todo-line-regexp' is nil there, and the first org function to touch
such a buffer dies on `(looking-at nil)'.

Measured, after one `,-o-V' search over the real corpus: 13 buffers left
in `hyrolo-org-mode', 3 of them agenda files, and both `org-queue-harvest'
and `org-other-agenda' then failed with (wrong-type-argument stringp nil).

The rolo reads the same files the agenda and the queue do, so they have to
agree about what mode those files are in.  Markdown and .otl keep the fast
path -- nothing else here reads those."
  (setq hyrolo-auto-mode-alist
        (seq-remove (lambda (cell) (eq (cdr cell) 'hyrolo-org-mode))
                    hyrolo-auto-mode-alist)))

;;;###autoload
(defun zetta-hyrolo-restore-org-buffers ()
  "Put agenda-file buffers left in `hyrolo-org-mode' back into `org-mode'.

A repair for buffers poisoned before `zetta-hyrolo-use-real-org-mode' ran
-- or by any other path that opens an agenda file through HyRolo.  Only
touches buffers that visit a file in `org-agenda-files'; leaves HyRolo's
own scratch reads alone."
  (interactive)
  (let ((agenda (mapcar #'expand-file-name (org-agenda-files)))
        (fixed 0))
    (dolist (buffer (buffer-list))
      (with-current-buffer buffer
        (when (and (eq major-mode 'hyrolo-org-mode)
                   (buffer-file-name)
                   (member (expand-file-name (buffer-file-name)) agenda))
          (org-mode)
          (setq fixed (1+ fixed)))))
    (when (called-interactively-p 'interactive)
      (message "%d agenda buffer%s restored to org-mode" fixed
               (if (= fixed 1) "" "s")))
    fixed))

(defcustom zetta-hyrolo-org-minor-modes
  '(org-fragtog-mode parrot-mode)
  "Org minor modes to switch off in the HyRolo display buffer.

Anything this config hangs on `org-mode-hook' belongs here, because the
display buffer passes through `org-mode' and does not come back out
clean; see `zetta-hyrolo-drop-org-minor-modes'."
  :type '(repeat symbol) :group 'zetta)

(defun zetta-hyrolo-drop-org-minor-modes ()
  "Turn off Org minor modes left behind in the HyRolo display buffer.

`hyrolo-mode' sets `major-mode' by hand and never calls
`kill-all-local-variables' (hyrolo.el, near \"setq major-mode
'hyrolo-mode\"), while the display buffer passes THROUGH `org-mode' as it
gathers entries from .org files -- upstream marks one of its own cache
variables `permanent-local' specifically to survive those mode changes.
So every buffer-local org-mode leaves behind lives on in the finished
buffer, including the minor modes `org-mode-hook' switched on.

`org-fragtog' is the one that shows.  Its `post-command-hook' entry calls
`org-element-context' on every keystroke, and org-element refuses to parse
a buffer that is not in Org mode, so moving point in *HyRolo* streams

  Warning (org-element): `org-element-at-point' cannot be used in
  non-Org buffer #<buffer *HyRolo*> (hyrolo-mode)

into the echo area.  `parrot-mode' is hooked to `org-mode' here too and
leaks the same way -- harmless, but a mode-line animation has no business
in a read-only match buffer.

Upstream anticipated exactly this class of bug: `hyrolo-mode' nullifies
`add-log-current-defun-function', `imenu-generic-expression',
`imenu-create-index-function' and `which-func-mode', with a comment saying
they would otherwise call `org-element-at-point' outside Org mode.  It
cannot know which minor modes a given config hangs on `org-mode-hook',
which is why this is here rather than there."
  (dolist (mode zetta-hyrolo-org-minor-modes)
    (when (and (boundp mode) (symbol-value mode) (fboundp mode))
      (funcall mode -1))))

(add-hook 'hyrolo-mode-hook #'zetta-hyrolo-drop-org-minor-modes)

(general-define-key
 :keymaps 'menu-org-map
 "V" 'zetta-org-todo-rolo
 "d" 'zetta-hyrolo-day)

(defun zetta-hyrolo-grep-with-ancestors (term)
  "HyRolo search for TERM, retrieving the full hierarchy around each match.
Unlike `hyrolo-grep'/`hyrolo-fgrep', whose results show only the matching
entry and its descendants, this emits the entire top-level record tree
containing each match, ancestor headings included.  TERM is a plain string;
multi-word terms match as an exact phrase."
  (interactive "sFind rolo term (with ancestors): ")
  (hyrolo-fgrep-logical (format "(and %S)" term) nil t))

;; --- HyWiki: make sure a WikiWord always has a real page file on disk ---
;; HyWiki writes a page file when it first creates the page, but a WikiWord can
;; end up registered in its referent hash with no file behind it -- the hash and
;; the on-disk pages drift apart, or the file is deleted later.  Then the Action
;; Key only opens an empty, file-less buffer that reports "no changes to save",
;; so nothing is written and the WikiWord stops being highlighted after a
;; restart.  Every follow/create path funnels through `hywiki-display-page', so
;; seed a missing (or empty, not-yet-open) page file with an Org title there.

(defun zetta-hywiki-ensure-page-file (&optional wikiword file-name)
  "Ensure the HyWiki page file for WIKIWORD/FILE-NAME is a real, titled file.
Advised onto `hywiki-display-page' as `:before'.  Writes the page file with an
Org `#+title:' line when it is missing, or when it exists but is empty and not
already open in a buffer -- so following a WikiWord always lands in a real,
non-empty page, even if HyWiki's referent hash and the on-disk pages have
drifted apart.  Any #section:Lnum:Cnum suffix is stripped first so we seed the
real page rather than a `WikiWord#Section' stub.  Files with content, or already
open in a buffer, are untouched."
  ;; Resolve (and seed) the *page* file: strip any #section:Lnum:Cnum suffix
  ;; first, because `hywiki-get-page-file' otherwise appends it to the file name
  ;; (e.g. `HyWikiWord.org#Description') and we would create that stub instead of
  ;; the real page -- so following `WikiWord#Section' opens an empty buffer
  ;; rather than the section.  As a final guard, never seed a name still carrying
  ;; a `#'.
  (let* ((reference (or file-name wikiword))
         (page (and reference (hywiki-word-strip-suffix reference)))
         (file (and page (ignore-errors (hywiki-get-page-file page)))))
    (when (and (stringp file)
               (not (string-search "#" (file-name-nondirectory file)))
               (file-writable-p file)
               (not (get-file-buffer file))
               (or (not (file-exists-p file))
                   (let ((size (file-attribute-size (file-attributes file))))
                     (and size (zerop size)))))
      (let ((title (file-name-sans-extension (file-name-nondirectory file))))
        (write-region (format "#+title: %s\n\n" title) nil file nil 0)))))

;; HyWiki's frame-wide WikiWord re-highlight walks every window with a
;; `sit-for 0' redisplay each -- with SVG tab/mode/header lines that is a
;; visible whole-frame flash plus cursor churn (`with-selected-window').
;; It fires per `post-self-insert' lookup while typing capital-letter
;; words, and on every `hywiki-directory' mtime change (lockfiles,
;; autosaves, the .hywiki.eld cache, syncthing deliveries -- the wiki now
;; lives in the synced ~/kb tree).  The original empty-hash skip
;; (#98) only masked the zero-pages case; with real pages the pass ran
;; raw again.  Debounce instead: coalesce every trigger into ONE pass,
;; run after Emacs has been idle -- never mid-keystroke.  The empty-hash
;; skip is preserved.  (Upstream Hyperbole issue; guarded here.)
(defvar zetta--hywiki-rehighlight-pending nil
  "Cons of (ORIG . ARGS) for the most recent coalesced re-highlight call.")
(defvar zetta--hywiki-rehighlight-timer nil)
(defun zetta-hywiki-debounce-frame-rehighlight (orig &rest args)
  "Coalesce HyWiki frame-wide re-highlights into one idle-time pass.
Around advice for `hywiki-maybe-highlight-wikiwords-in-frame'.  Skips
entirely while the referent hash is empty (nothing to highlight);
otherwise defers ORIG until 0.7s of idle time, collapsing bursts of
triggers (typing, directory mtime churn) into a single repaint."
  (unless (and (boundp 'hywiki--referent-hasht)
               (hash-table-p hywiki--referent-hasht)
               (zerop (hash-table-count hywiki--referent-hasht)))
    (setq zetta--hywiki-rehighlight-pending (cons orig args))
    (unless (timerp zetta--hywiki-rehighlight-timer)
      (setq zetta--hywiki-rehighlight-timer
            (run-with-idle-timer
             0.7 nil
             (lambda ()
               (setq zetta--hywiki-rehighlight-timer nil)
               (when zetta--hywiki-rehighlight-pending
                 ;; Upstream's pass forces a redisplay per window via
                 ;; `sit-for 0' ("display buffer before font-locking") —
                 ;; meaningless at idle in already-displayed windows, and
                 ;; the source of the residual once-per-burst flash.
                 ;; Neutralize it for this deferred invocation only.
                 (cl-letf (((symbol-function 'sit-for) #'ignore))
                   (apply (car zetta--hywiki-rehighlight-pending)
                          (cdr zetta--hywiki-rehighlight-pending))))))))))

;; HyWiki completion offers a bogus `zsh#no matches found...' candidate.
;; `hywiki-completion-at-point' lists page candidates by globbing `./PREFIX*.org'
;; through `shell-command-to-string', and discards the glob's no-match error --
;; but only in its POSIX form (`grep: ...: No such file or directory').  When
;; `shell-file-name' is zsh, an unmatched glob aborts with `zsh: no matches
;; found: ...' *before* grep runs, so that text slips past HyWiki's filter and
;; shows up as a completion candidate.  Run the command under a POSIX shell so
;; the no-match degrades to the error HyWiki already handles.
(defun zetta-hywiki-completion-posix-shell (orig &rest args)
  "Run `hywiki-completion-at-point' under a POSIX shell.
Around advice: bind `shell-file-name'/`shell-command-switch' to a POSIX `sh'
so HyWiki's page-name glob yields the `No such file or directory' no-match
error it filters, instead of zsh's unfiltered `no matches found' -- which would
otherwise appear as a bogus `zsh#...' completion candidate."
  (let ((shell-file-name (or (executable-find "sh") "/bin/sh"))
        (shell-command-switch "-c"))
    (apply orig args)))

;; Official GitHub mirror -- git.savannah.gnu.org is slow and
;; intermittently times out on CI runners (cold-run clone flake, PR
;; #114's 29.4 job, 2026-07-23).  A true mirror shares commit SHAs, so
;; the lockfile pin holds; verified the pinned f076ff8 present on the
;; mirror 2026-07-23.
(use-package hyperbole
  :ensure (hyperbole :host github :repo "rswgnu/hyperbole")
  :defer 1
  :init
  ;; Keep Hyperbole's default key initialization; we relocate two keys below.
  (setq hkey-init t)
  :config
  (hyperbole-mode 1)

  ;;(setq hsys-org-enable-smart-keys t)

  ;; --- HyWiki: highlight/buttonize WikiWords (pages live in ~/hywiki/) ---
  ;; `hyperbole-mode' alone does NOT highlight WikiWords; the global
  ;; `hywiki-mode' does.  `hywiki-directory' defaults to ~/hywiki/, which is
  ;; where the generated chiply.dev WikiWord pages live.  Follow a WikiWord
  ;; with the Action Key {s-H} (relocated from {M-RET} below).
  ;;(require 'hywiki)
  (setq hywiki-directory (zetta-kb-file "wiki"))
  (hywiki-mode 1)

  (add-to-list 'brushup-styles
               '(set-face-attribute 'hywiki--word-face nil
                                   :foreground "goldenrod3"
                                   ))


  ;; Make sure following a WikiWord always lands in a real page file on disk,
  ;; titled with the WikiWord, even if HyWiki's referent hash and the pages on
  ;; disk have drifted apart (see `zetta-hywiki-ensure-page-file').
  (advice-add 'hywiki-display-page :before #'zetta-hywiki-ensure-page-file)

  ;; Debounce the whole-frame WikiWord re-highlight: one idle-time pass
  ;; instead of a sit-for flash per trigger (see
  ;; `zetta-hywiki-debounce-frame-rehighlight').
  (advice-add 'hywiki-maybe-highlight-wikiwords-in-frame :around
              #'zetta-hywiki-debounce-frame-rehighlight)

  ;; The buffer-(de)highlight paths force a redisplay per buffer the same
  ;; way (sit-for 0, "display before font-locking") -- a flash on buffer
  ;; switches/opens and referent-table updates.  Same cure: run them with
  ;; sit-for neutralized; normal redisplay paints the results anyway.
  (defun zetta-hywiki-quiet-sit-for (orig &rest args)
    "Run ORIG with `sit-for' neutralized to suppress forced redisplays."
    (cl-letf (((symbol-function 'sit-for) #'ignore))
      (apply orig args)))
  (advice-add 'hywiki-word-highlight-in-buffers :around
              #'zetta-hywiki-quiet-sit-for)
  (advice-add 'hywiki-word-dehighlight-in-buffers :around
              #'zetta-hywiki-quiet-sit-for)

  ;; Keep zsh's `no matches found' glob error out of HyWiki completion
  ;; candidates (see `zetta-hywiki-completion-posix-shell').
  (advice-add 'hywiki-completion-at-point :around
              #'zetta-hywiki-completion-posix-shell)

  ;; --- HyWiki: allow single-letter WikiWords (e.g. C, R, D) ---
  ;; `hywiki-word-regexp' matches a capital followed by one-or-more letters
  ;; (`[[:upper:]][[:alpha:]]+'), so a lone capital like `C' is never recognized
  ;; as a WikiWord.  Relax the `+' to `*' so a single capital qualifies.  Since
  ;; `hywiki-word-regexp' is a `defconst' that the suffix/exact/buttonize regexps
  ;; are `concat'-ed from at load time, rebuild those from the new base value, and
  ;; drop the cached `hywiki--any-wikiword-regexp-list' so it regenerates.
  ;; Tradeoff: every standalone capital (I, A, ...) becomes a WikiWord *candidate*
  ;; for the Action Key and buttonize-as-you-type; persistent highlighting still
  ;; only fires for capitals that have a real page in `hywiki-directory'.
  (setq hywiki-word-regexp
        (format "\\<\\([[:upper:]][[:alpha:]]*\\)\\>\\(?:%s\\)?"
                (regexp-quote hywiki-file-suffix))
        hywiki-word-with-optional-suffix-regexp
        (concat hywiki-word-regexp hywiki-word-section-regexp "??"
                hywiki-word-line-and-column-numbers-regexp "?")
        hywiki-word-with-optional-suffix-exact-regexp
        (concat "\\`" hywiki-word-regexp "\\(#[^][#\n\r\f]+\\)??"
                hywiki-word-line-and-column-numbers-regexp "?\\'")
        hywiki--word-and-buttonize-character-regexp
        (concat "\\(" hywiki-word-with-optional-suffix-regexp "\\)"
                hywiki--buttonize-character-regexp)
        hywiki--any-wikiword-regexp-list nil)

  ;; --- Relocate the minibuffer menu: {C-h h} -> {C-h H} ---
  ;; Hyperbole binds `hyperbole' to {C-h h} globally; undo that and rebind.
  (when (eq (lookup-key (current-global-map) (kbd "C-h h")) 'hyperbole)
    (global-set-key (kbd "C-h h") #'view-hello-file))
  (global-set-key (kbd "C-h H") #'hyperbole)

  ;; --- Relocate the keyboard Action/Assist Key: {M-RET} -> {s-H} ---
  ;; Free the default M-RET variants from `hyperbole-mode-map' (so org-mode's
  ;; M-RET is no longer shadowed), then bind the Action Key on s-H via the
  ;; supported `hkey-set-key' helper.  Assist Key = {C-u s-H}.
  (dolist (k '("M-RET" "M-<return>" "ESC RET" "ESC <return>"))
    (define-key hyperbole-mode-map (kbd k) nil))
  (hkey-set-key (kbd "s-H") #'hkey-either)

  ;; --- Give Hyperbole the physical M-<return> in outline buffers ---
  ;; evil-collection's outline module binds the physical key M-<return> to
  ;; `outline-insert-heading' in the normal-state aux map of `outline-mode-map'
  ;; (which `outline-minor-mode' inherits via `set-keymap-parent'), and evil's
  ;; keymaps sit in `emulation-mode-map-alists', outranking `hyperbole-mode-map'.
  ;; So in e.g. an elisp buffer (outline-minor-mode + evil normal state) the
  ;; physical M-<return> ran the outline command while the ASCII {M-RET} still
  ;; ran Hyperbole's Action Key.  Rebind the physical key to `hkey-either' too so
  ;; both forms match.  This package is `:defer 1', so `evil-collection-init'
  ;; (hence the outline setup this overrides) has already run.
  (when (fboundp 'evil-collection-define-key)
    (evil-collection-define-key 'normal 'outline-mode-map
      (kbd "M-<return>") 'hkey-either))

  ;; Keep HyRolo out of the major mode of files everything else reads.
  (zetta-hyrolo-use-real-org-mode)

  ;; Guards for the Action Key probe; see the two functions above.
  (advice-add 'ibut:create :around #'zetta-hyperbole-quiet-ibut-probe)
  (when (fboundp 'ibtypes::pathname)
    (advice-add 'ibtypes::pathname :around
                #'zetta-hyperbole-ibtype-ignore-invalid-regexp))

  ;; --- HyRolo: search the kb as the rolo source ---
  ;; Built from `zetta-hyrolo-base-file-list' plus whichever (todo) corpus
  ;; the source toggle currently selects; see the commentary above.
  (zetta-hyrolo-update-file-list)
  ;; Make the consult-driven grep commands resolve their matched files
  ;; correctly (see `zetta-hyrolo-fix-consult-handoff' above).
  (advice-add 'hyrolo-grep-input :filter-return
              #'zetta-hyrolo-fix-consult-handoff))

;;; hyperbole.el ends here
