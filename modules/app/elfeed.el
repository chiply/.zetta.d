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

  (setq elfeed-protocol-fever-update-unread-only nil)
  (setq elfeed-protocol-fever-fetch-category-as-tag t)
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

  :hook (elfeed-search-update . elfeed-score-enable)
  )

;; Bind elfeed-search keys after evil-collection sets up its bindings.
;; Must be outside use-package with high depth so it runs after
;; evil-collection's hook.
(add-hook 'elfeed-search-mode-hook
          (lambda ()
            (evil-local-set-key 'normal "R" #'elfeed-protocol-fever-reinit)
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
;;; elfeed.el ends here
