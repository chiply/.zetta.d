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
  (setq hywiki-directory (expand-file-name "~/kb/wiki"))
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

  ;; --- HyRolo: search the Logseq pages as the rolo source ---
  (setq hyrolo-file-list '("~/.rolo.org" "~/kb/notes/" "~/kb/wiki/"
                           "~/kb/todo/" "~/kb/inbox.org"))
  ;; Make the consult-driven grep commands resolve their matched files
  ;; correctly (see `zetta-hyrolo-fix-consult-handoff' above).
  (advice-add 'hyrolo-grep-input :filter-return
              #'zetta-hyrolo-fix-consult-handoff))

;;; hyperbole.el ends here
