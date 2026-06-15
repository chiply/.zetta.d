;;; elfeed.el --- Configure elfeed -*- lexical-binding: t; -*-

;; These need to be outside of the use-package since they're used in
;; the general definitions.
(defun my-elfeed-filter (filter-string)
  "Set and apply a custom elfeed search filter."
  (lambda () (interactive)
    (elfeed-search-set-filter filter-string)
    (elfeed-search-update--force)))

(defun elfeed-tag-selection-as (mytag)
  "Returns a function that tags an elfeed entry or selection as MYTAG"
  (lambda ()
    "Toggle a tag on an Elfeed search selection"
    (interactive)
    (elfeed-search-toggle-all mytag)))

(use-package elfeed-protocol
  :ensure (elfeed-protocol :host github :repo "fasheng/elfeed-protocol")
  :after elfeed
  :demand t
  :config

  ;; UNREAD-ONLY is required for reader.miniflux.app: the hosted
  ;; miniflux's entry ids auto-increment across ALL tenants, so fever's
  ;; default incremental strategy -- request the next maxsize ids after
  ;; the last-seen id -- almost never hits OUR entries (verified: update
  ;; requested ids ...572-...771 after mark ...571 and parsed 0, while
  ;; new posts sat unread on the server).  With unread-only, each update
  ;; fetches the server's actual unread_item_ids list instead.
  (setq elfeed-protocol-fever-update-unread-only t)
  (setq elfeed-protocol-fever-fetch-category-as-tag t)
  ;; Do NOT raise this: reader.miniflux.app caps fever responses at 50
  ;; items per request (verified: 60 ids requested -> 50 returned), so a
  ;; bigger batch silently DROPS the rest.
  (setq elfeed-protocol-fever-maxsize 50)
  ;; elfeed-protocol-feeds set in ~/.private.el

  (setq elfeed-protocol-enabled-protocols '(fever))
  (elfeed-protocol-enable)
  (message "loaded elfeed protocol")
  )

(use-package elfeed
  :after embark
  :commands elfeed
  :ensure t
  :config
  (setq elfeed-use-curl t)
  (elfeed-set-timeout 36000)
  (setq elfeed-curl-extra-arguments '("--insecure"))
  (defun prot-common-crm-exclude-selected-p (input)
    "Filter out INPUT from `completing-read-multiple'.
Hide non-destructively the selected entries from the completion
table, thus avoiding the risk of inputting the same match twice.

To be used as the PREDICATE of `completing-read-multiple'."
    (if-let* ((pos (string-match-p crm-separator input))
              (rev-input (reverse input))
              (element (reverse
                        (substring rev-input 0
                                   (string-match-p crm-separator rev-input))))
              (flag t))
        (progn
          (while pos
            (if (string= (substring input 0 pos) element)
                (setq pos nil)
              (setq input (substring input (1+ pos))
                    pos (string-match-p crm-separator input)
                    flag (when pos t))))
          (not flag))
      t))

  (defun prot-elfeed--format-tags (tags sign)
    "Prefix SIGN to each tag in TAGS."
    (mapcar (lambda (tag)
              (format "%s%s" sign tag))
            tags))

  (defun prot-elfeed-search-tag-filter ()
    "Filter Elfeed search buffer by tags using completion.

Completion accepts multiple inputs, delimited by `crm-separator'.
Arbitrary input is also possible, but you may have to exit the
minibuffer with something like `exit-minibuffer'."
    (interactive)
    (unwind-protect
        (elfeed-search-clear-filter)
      (let* ((elfeed-search-filter-active :live)
             (db-tags (elfeed-db-get-all-tags))
             (plus-tags (prot-elfeed--format-tags db-tags "+"))
             (minus-tags (prot-elfeed--format-tags db-tags "-"))
             (all-tags (delete-dups (append plus-tags minus-tags)))
             (tags (completing-read-multiple
                    "Apply one or more tags: "
                    all-tags #'prot-common-crm-exclude-selected-p t))
             (input (string-join `(,elfeed-search-filter ,@tags) " ")))
        (setq elfeed-search-filter input))
      (elfeed-search-update :force)))
  (setq elfeed-search-title-max-width 100)
  (defun elfeed-search-format-date (date)
    (format-time-string "%Y-%m-%d %H:%M" (seconds-to-time date)))

  (defun elfeed-show-eww-open (&optional use-generic-p)
    "open with eww"
    (interactive "P")
    (let ((browse-url-browser-function #'eww-browse-url))
      (elfeed-show-visit use-generic-p)))

  ;; TODO replace and condittionally transform if reddit to reddit.old
  (defun elfeed-search-eww-open (&optional use-generic-p)
    "open with eww"
    (interactive "P")
    (let ((browse-url-browser-function #'eww-browse-url))
      (elfeed-search-browse-url use-generic-p)))

  ;; embark
  (defun embark-target-elfeed-entry ()
    "Target elfeed entry at point."
    (when (derived-mode-p 'elfeed-search-mode)
      (when-let* ((entry (elfeed-search-selected :ignore-region)))
        (cons 'elfeed-entry entry))))

  ;; Add to embark target finders
  (add-to-list 'embark-target-finders 'embark-target-elfeed-entry)

  ;; TODO update -- add any single entry actions here -- this is how
  ;; we can get instant eww, wombag integration, etc... maybe have an
  ;; org capture?
  ;; TODO THINK weigh whether we want to do this... one the one hand it
  ;; makes adding bindings less cognitively demanding because you
  ;; don't have to worry about conflicts with active maps (for example
  ;; evil stuff which can be used to navigate the buffer).  on the
  ;; other hand, it requires an extra key press -- for example,
  ;; imagine having to do embark act, read every single time you want
  ;; to mark an entry as read... is it posisble that there is a subset
  ;; of actions that might better belong in an embark keymap, and
  ;; others you might want at top level?
  (defvar-keymap embark-elfeed-entry-map
    :doc "Keymap for elfeed entry actions"
    "o" #'elfeed-search-browse-url
    "y" #'elfeed-search-yank-link
    "u" #'elfeed-search-tag-all-unread
    "r" #'elfeed-search-untag-all-unread
    "+" #'elfeed-search-tag-all
    "-" #'elfeed-search-untag-all)

  ;; Register the keymap
  (add-to-list 'embark-keymap-alist '(elfeed-entry . embark-elfeed-entry-map))

  :brushup
  (add-to-list 'brushup-styles
               '(progn
                  ;; NOTE this will still work with dark because dark
                  ;; themse also modify the FG, but we don't change
                  ;; that here
                  (set-face-attribute 'elfeed-search-title-face nil
                                      :weight 'unspecified
                                      :background brushup-bg-1
                                      :inherit nil)
                  (set-face-attribute 'elfeed-search-unread-title-face nil
                                      :weight 'unspecified
                                      :background brushup-bg
                                      :inherit nil)
                  (set-face-attribute 'elfeed-search-feed-face nil
                                      :weight 'unspecified
                                      :foreground brushup-fg-2
                                      :inherit nil)
                  (set-face-attribute 'elfeed-search-tag-face nil
                                      :weight 'unspecified
                                      :foreground brushup-fg-4
                                      :inherit nil)))

  :general
  (
   :states '(normal)
   :keymaps '(elfeed-show-mode-map)
   "C-c C-S-o" 'zetta-org-open-at-point
   "C-c C-o" 'org-open-at-point
   "B" 'elfeed-show-eww-open
   "SPC" 'elfeed-show-next
   "S-SPC" 'elfeed-show-prev
   )

  ;; NB: elfeed-score-enable used to be hooked on `elfeed-search-update'
  ;; here -- but enable RELOADS the score file and stats file and runs
  ;; serde cleanup every call, so every search refresh paid that cost.
  ;; It is called once in the elfeed-score :config below; that's enough.
  )

;; Bind elfeed-search keys after evil-collection sets up its bindings.
;; Must be outside use-package with high depth so it runs after
;; evil-collection's hook.
(add-hook 'elfeed-search-mode-hook
          (lambda ()
            ;; R = INCREMENTAL update (fetch only entries newer than the
            ;; stored update mark, sync pending read/star states).
            ;; gR = full resync: re-fetches and re-parses EVERY starred
            ;; and unread entry -- slow against a 50k-entry db; only for
            ;; first sync, recovery, or pulling remote read-state
            ;; changes for old entries (fever's API has no better way).
            (evil-local-set-key 'normal "R" #'elfeed-update)
            (evil-local-set-key 'normal "gR" #'elfeed-protocol-fever-reinit)
            (evil-local-set-key 'normal "tt" #'prot-elfeed-search-tag-filter)
            ;; quick filters
            (evil-local-set-key 'normal "fu" (my-elfeed-filter "@6-months-ago +unread"))
            (evil-local-set-key 'normal "fy" (my-elfeed-filter "@6-months-ago +unread +youtube"))
            (evil-local-set-key 'normal "fp" (my-elfeed-filter "@6-months-ago +unread +podcast"))
            (evil-local-set-key 'normal "fd" (my-elfeed-filter "@6-months-ago +unread +data"))
            (evil-local-set-key 'normal "fr" (my-elfeed-filter "@6-months-ago +unread +reddit"))
            (evil-local-set-key 'normal "fe" (my-elfeed-filter "@6-months-ago +unread +emacs"))
            (evil-local-set-key 'normal "fh" (my-elfeed-filter "@6-months-ago +unread +hackernews"))
            (evil-local-set-key 'normal "fn" (my-elfeed-filter "@6-months-ago +unread +npr"))
            (evil-local-set-key 'normal "fw" (my-elfeed-filter "@6-months-ago +unread +watches"))
            (evil-local-set-key 'normal "fl" (my-elfeed-filter "@6-months-ago +readlater"))
            (evil-local-set-key 'normal "fm" (my-elfeed-filter "@6-months-ago +myblog"))
            ;; quick tags
            (evil-local-set-key 'normal "l" (elfeed-tag-selection-as 'readlater))
            (evil-local-set-key 'normal "d" (elfeed-tag-selection-as 'junk))
            (evil-local-set-key 'normal "B" #'elfeed-search-eww-open)
            ;; keep the headline in the same position when hitting r
            (evil-local-set-key 'normal "r"
                                (lambda () (interactive)
                                  (elfeed-search-untag-all-unread)
                                  (evil-scroll-line-down 1)))
            (evil-local-set-key 'normal "tR" #'elfeed-search-tag-all-unread))
          90)

(use-package elfeed-org
  :demand t
  :ensure t
  :after elfeed org
  :config
  (setq rmh-elfeed-org-files
        (list
         (expand-file-name "elfeed.org" user-emacs-directory)
         ))
  (elfeed-org)
  (message "loaded elfeed-org")
  )

(use-package elfeed-score
  :ensure (elfeed-score :type git :host github :repo "sp1ff/elfeed-score")
  :after elfeed-org
  :demand t
  :config
  (progn
    (elfeed-score-enable)
    ;; FREEZE FIX: elfeed-protocol/Fever fires `elfeed-update-hooks' once per
    ;; protocol sub-feed, each with the curl queue already drained, so
    ;; elfeed-score's `elfeed-score-rule-stats-update-hook' (guarded only by
    ;; (= (elfeed-queue-count-total) 0)) passes every time and writes the WHOLE
    ;; rule-stats file once per feed -- ~300 full-file writes (each a visible
    ;; "Wrote .../tmpXXXX") per sync, a multi-second freeze.  Replace that
    ;; per-feed write with ONE debounced idle write per sync, disable the
    ;; mid-scoring periodic flush (every 64 matches -- same whole-file write on
    ;; a different trigger), and persist once more on exit.
    (remove-hook 'elfeed-update-hooks #'elfeed-score-rule-stats-update-hook)
    (setq elfeed-score-rule-stats-dirty-threshold nil)
    (defun zetta-elfeed-score-stats-write ()
      "Persist elfeed-score rule stats now, if enabled."
      (when (and (bound-and-true-p elfeed-score-rule-stats-file)
                 (fboundp 'elfeed-score-rule-stats-write))
        (ignore-errors
          (elfeed-score-rule-stats-write elfeed-score-rule-stats-file))))
    (defvar zetta-elfeed-score-stats--timer nil)
    (defun zetta-elfeed-score-stats-write-debounced (&rest _)
      "Persist rule stats once, after update activity settles."
      (when (timerp zetta-elfeed-score-stats--timer)
        (cancel-timer zetta-elfeed-score-stats--timer))
      (setq zetta-elfeed-score-stats--timer
            (run-with-idle-timer 3 nil #'zetta-elfeed-score-stats-write)))
    (add-hook 'elfeed-update-hooks #'zetta-elfeed-score-stats-write-debounced)
    (add-hook 'kill-emacs-hook #'zetta-elfeed-score-stats-write)
    (define-key elfeed-search-mode-map "=" elfeed-score-map))
  (setq elfeed-search-print-entry-function #'elfeed-score-print-entry)
  ;; TODO add as a hook?
  (message "loaded elfeed score")

  ;; NOTE overriding the fn - probably shouldn't live here since this
  ;; could entail features introduced by other packages, but remember
  ;; there are issues loading all the elfeed stuff from 1 file
  (defun elfeed-score-print-entry (entry)
    "Print ENTRY to the Elfeed search buffer.
This implementation is derived from `elfeed-search-print-entry--default'."
    (let* ((date (elfeed-search-format-date (elfeed-entry-date entry)))
           (title (or (elfeed-meta entry :title) (elfeed-entry-title entry) ""))
           (title-faces (elfeed-search--faces (elfeed-entry-tags entry)))
           (feed (elfeed-entry-feed entry))
           (feed-title
            (when feed
              (or (elfeed-meta feed :title) (elfeed-feed-title feed))))
           (tags (mapcar #'symbol-name (elfeed-entry-tags entry)))
           (tags-str (mapconcat
                      (lambda (s) (propertize s 'face 'elfeed-search-tag-face))
                      tags ","))
           (title-width (- (window-width) 10 elfeed-search-trailing-width))
           (title-column (elfeed-format-column
                          title (elfeed-clamp
                                 elfeed-search-title-min-width
                                 title-width
                                 elfeed-search-title-max-width)
                          :left))
	       (score
            (elfeed-score-format-score
             (elfeed-score-scoring-get-score-from-entry entry))))
      (insert score)
      (insert (propertize title-column 'face title-faces 'kbd-help title) " ")
      (when feed-title
        (insert (propertize feed-title 'face 'elfeed-search-feed-face) " "))
      (when tags
        (insert "(" tags-str ")"))
      (insert " ")
      (insert (propertize date 'face 'font-lock-comment-face) " ")))

  (defun elfeed-score-sort (a b)
    "Return non-nil if A should sort before B.

`elfeed-score' will substitute this for the Elfeed scoring function."

    (let ((a-score (elfeed-score-scoring-get-score-from-entry a))
          (b-score (elfeed-score-scoring-get-score-from-entry b)))
      (if (> a-score b-score)
          t
        (let ((a-date (elfeed-entry-date a))
              (a-title (elfeed-entry-title a))
              (b-date (elfeed-entry-date b))
              (b-title (elfeed-entry-title b))
              )
          (and
           (eq a-score b-score)
           (> a-date b-date)
           (string> a-title b-title))))))

  :general
  (
   :states '(normal)
   :keymaps '(elfeed-search-mode-map)
   "x" 'elfeed-score-explain))

;;;; consult-elfeed (a la consult-mu)
;; Search recent entries from anywhere with live preview: candidates are
;; the most recent `zetta-consult-elfeed-limit' db entries (title, feed
;; and tags all match the filter -- type "unread" to narrow to unread),
;; previews render in *elfeed-entry* as you move, RET opens the entry.

(defcustom zetta-consult-elfeed-limit 2000
  "Most-recent entries offered by `zetta-consult-elfeed'.
The db holds tens of thousands; formatting them all would lag the
minibuffer, and old entries are reachable via elfeed's own search."
  :type 'integer :group 'zetta)

(defvar zetta-consult-elfeed--history nil)

(defun zetta-elfeed--ensure-db ()
  "Ensure the elfeed db is loaded AND its index is a usable avl-tree.
`elfeed-db-ensure' only loads when `elfeed-db' is nil, so it cannot
recover a db left half-loaded or with a clobbered global (index not an
avl-tree) -- which makes `with-elfeed-db-visit' signal
\"Wrong type argument: avl-tree-, nil\".  Force a fresh load from disk
in that case so elfeed commands self-heal instead of erroring."
  (require 'elfeed-db)
  (elfeed-db-ensure)
  (unless (avl-tree-p elfeed-db-index)
    (setq elfeed-db nil)
    (elfeed-db-load)))

(defun zetta-consult-elfeed--candidates ()
  "Format the most recent db entries as propertized candidate strings."
  (let ((n 0) out)
    (with-elfeed-db-visit (entry feed)
      (let* ((date (format-time-string "%Y-%m-%d" (elfeed-entry-date entry)))
             (title (or (elfeed-meta entry :title) (elfeed-entry-title entry) ""))
             (feed-title (and feed (or (elfeed-meta feed :title)
                                       (elfeed-feed-title feed))))
             (tags (mapconcat #'symbol-name (elfeed-entry-tags entry) ","))
             (cand (concat
                    (propertize date 'face 'font-lock-comment-face) " "
                    title " "
                    (and feed-title
                         (propertize feed-title 'face 'elfeed-search-feed-face))
                    (and (> (length tags) 0)
                         (concat " " (propertize (concat "(" tags ")")
                                                 'face 'elfeed-search-tag-face))))))
        (push (propertize
               (if (fboundp 'consult--tofu-encode)
                   (concat cand (consult--tofu-encode n))
                 cand)
               'zetta-elfeed-entry entry)
              out)
        (when (>= (setq n (1+ n)) zetta-consult-elfeed-limit)
          (elfeed-db-return))))
    (nreverse out)))

(defun zetta-consult-elfeed--show (entry)
  "Render ENTRY in *elfeed-entry* for PREVIEW, without re-running the mode.
Return the buffer (so the consult preview can display it).

`elfeed-show-entry' calls `elfeed-show-mode' on EVERY invocation, and that
runs `kill-all-local-variables', which strips `tab-line-format'.  After the
first preview *elfeed-entry* is already on screen WITH its tab-line, so
re-running the mode strips the tab-line on the live buffer; the heavy
`elfeed-show-refresh' that follows gives redisplay a chance to paint the
stripped state, and `global-tab-line-mode' restores it a moment later --
i.e. the tab-line flashes once per candidate (visible when the tab-line is
kept during preview, `zetta-consult-preview-keep-tab-line').  Reuse the live
elfeed-show buffer in place, running the major mode only when it is not
already active, so the tab-line is never stripped between previews.

Also bypasses `elfeed-show-entry' (and so its `:after' advice -- org-remark
auto-notes), which we do not want firing for every candidate the cursor
crosses anyway."
  (let ((buff (get-buffer-create "*elfeed-entry*")))
    (with-current-buffer buff
      (unless (derived-mode-p 'elfeed-show-mode)
        (elfeed-show-mode))
      (setq elfeed-show-entry entry)
      (elfeed-show-refresh))
    buff))

(defun zetta-consult-elfeed--state ()
  "Preview state function: render the candidate entry in *elfeed-entry*."
  (let ((preview (consult--buffer-preview)))
    (lambda (action cand)
      (if (eq action 'preview)
          (funcall preview 'preview
                   (when-let* ((entry (and cand (get-text-property
                                                 0 'zetta-elfeed-entry cand))))
                     (ignore-errors (zetta-consult-elfeed--show entry))))
        (funcall preview action nil)))))

(defun zetta-consult-elfeed ()
  "Search recent elfeed entries with preview (a la consult-mu).
Filters over title, feed and tags of the `zetta-consult-elfeed-limit'
most recent entries; RET opens the selection in the show buffer.

Preview is MANUAL (press \\`C-=' to preview the current candidate),
matching the other heavy consult commands: each preview renders a full
elfeed entry (shr/HTML, ~0.2s+), so auto-previewing on every keystroke
froze the picker -- especially the first render, which sets up
`elfeed-show-mode'.  For preview-while-browsing instead, set
`:preview-key' to e.g. \\='(:debounce 0.3 any)."
  (interactive)
  (require 'elfeed)
  (zetta-elfeed--ensure-db)
  (let* ((cand (consult--read
                (zetta-consult-elfeed--candidates)
                :prompt "Elfeed entry: "
                :category 'elfeed-entry
                :require-match t
                :sort nil
                :preview-key "C-="
                :lookup #'consult--lookup-member
                :state (zetta-consult-elfeed--state)
                :history 'zetta-consult-elfeed--history))
         (entry (and cand (get-text-property 0 'zetta-elfeed-entry cand))))
    (when entry (elfeed-show-entry entry))))

;;;; Prune old entries to keep the db (and its saves) small
;; `elfeed-db-save' serializes the WHOLE index with one synchronous `prin1';
;; its cost scales with entry count, so a 50k-entry db freezes Emacs for
;; seconds on every save.  Dropping old, already-read entries shrinks the
;; index and shortens that freeze proportionally.  Fever resync won't bring
;; old read entries back (the server only sends recent/unread), so this is
;; safe for an elfeed-protocol setup.

(defcustom zetta-elfeed-prune-keep-months 6
  "`zetta-elfeed-prune' removes read entries older than this many months.
Unread and protected entries (`zetta-elfeed-prune-protect-tags') are kept."
  :type 'integer :group 'zetta)

(defvar zetta-elfeed-prune-protect-tags '(unread starred important)
  "Entries carrying any of these tags are never removed by `zetta-elfeed-prune'.")

(defun zetta-elfeed-prune--victims (cutoff)
  "Collect read, unprotected entries older than CUTOFF (a `float-time').
Gathers into a list first -- never mutates the index mid-traversal."
  (let (out)
    (with-elfeed-db-visit (entry _feed)
      (when (< (elfeed-entry-date entry) cutoff)
        (unless (seq-some (lambda (tag) (memq tag (elfeed-entry-tags entry)))
                          zetta-elfeed-prune-protect-tags)
          (push entry out))))
    out))

(defun zetta-elfeed-prune (&optional months)
  "Remove old, already-read entries to shrink the elfeed db and speed saves.
Removes entries older than MONTHS (prefix arg; default
`zetta-elfeed-prune-keep-months') that are read and not tagged in
`zetta-elfeed-prune-protect-tags'.  Backs up the index to index.bak first,
then removes from the in-memory db, runs `elfeed-db-gc' to reclaim content,
and saves.  Fever resync will not re-add old read entries.

To restore: copy index.bak over index in `elfeed-db-directory' and restart."
  (interactive (list (and current-prefix-arg
                          (prefix-numeric-value current-prefix-arg))))
  (require 'elfeed)
  (zetta-elfeed--ensure-db)
  (let* ((months (or months zetta-elfeed-prune-keep-months))
         (cutoff (- (float-time) (* months 30 24 60 60)))
         (total (hash-table-count elfeed-db-entries))
         (victims (zetta-elfeed-prune--victims cutoff))
         (n (length victims)))
    (cond
     ((zerop n)
      (message "elfeed-prune: nothing to remove (0 read entries older than %d months)"
               months))
     ((yes-or-no-p
       (format "elfeed-prune: remove %d of %d entries (read, older than %d months)? "
               n total months))
      (let ((backup (expand-file-name "index.bak" elfeed-db-directory)))
        (copy-file (expand-file-name "index" elfeed-db-directory) backup t)
        (message "elfeed-prune: backed up index -> %s" backup))
      (dolist (entry victims)
        (let ((id (elfeed-entry-id entry)))
          (avl-tree-delete elfeed-db-index id)
          (remhash id elfeed-db-entries)))
      (message "elfeed-prune: removed %d entries; running gc + save..." n)
      (elfeed-db-gc)
      (let ((t0 (float-time)))
        (elfeed-db-save)
        (message "elfeed-prune: done -- %d -> %d entries; db-save now %.2fs"
                 total (hash-table-count elfeed-db-entries)
                 (- (float-time) t0)))))))

;;;; Background auto-update (mu4e-style)
;; Incremental pulls in the background, so opening elfeed shows fresh
;; entries without a foreground update.  The network side is async curl;
;; only parsing runs on the main thread, one maxsize-entry batch at a
;; time.  The FIRST run also loads elfeed and its db (the one-time
;; multi-second index load for a 50k-entry db), so it waits for genuine
;; idle rather than firing mid-typing.

(defvar zetta-elfeed-auto-update-interval (* 15 60)
  "Seconds between background incremental elfeed updates.")

(defvar zetta-elfeed--auto-update-timer nil
  "Active timer for `zetta-elfeed--auto-update', or nil.")

(defun zetta-elfeed--auto-update ()
  "Incrementally update all elfeed feeds in the background."
  (require 'elfeed)
  (elfeed-update))

(unless zetta-elfeed--auto-update-timer
  (setq zetta-elfeed--auto-update-timer
        (run-with-idle-timer
         120 nil
         (lambda ()
           (zetta-elfeed--auto-update)
           (setq zetta-elfeed--auto-update-timer
                 (run-with-timer zetta-elfeed-auto-update-interval
                                 zetta-elfeed-auto-update-interval
                                 #'zetta-elfeed--auto-update))))))
;;; elfeed.el ends here
