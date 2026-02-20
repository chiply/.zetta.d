;; -*- lexical-binding: t; -*-

(use-package org
  :ensure nil
  :mode ("\\.org" . org-mode)

  :config
  (setq-default org-indent-mode nil)
  (setq org-confirm-babel-evaluate nil
        ;; NOTE docs isn't clear on this, but this prevents org blocks from having leading tab for formatting purposes
        org-src-preserve-indentation t
        org-tags-column 0
        org-table-convert-region-max-lines 10000
        org-use-fast-todo-selection 'expert
        org-attach-store-link-p 'file
        org-hide-leading-stars nil
        org-archive-location "(todo) archive.org::* From %s"
        ;; org-agenda-files populated by zetta-logseq-update-agenda-files
        org-agenda-files '()
        org-persist-directory (expand-file-name
                               ".data/org-persist"
                               user-emacs-directory)
        org-id-locations-file (expand-file-name
                               ".data/org/.org-id-locations"
                               user-emacs-directory)
        org-startup-folded (quote nofold) ;; everything but drawers
        org-startup-indented t
        org-refile-use-outline-path 'file
        org-log-refile 'time
        org-log-redeadline 'time
        org-log-reschedule 'time
        org-log-into-drawer t
        ;; Custom: also log initial deadline/schedule creation
        zetta-org-log-initial-deadline 'time
        zetta-org-log-initial-schedule 'time
        org-outline-path-complete-in-steps nil
        org-refile-allow-creating-parent-nodes 'confirm
        org-refile-targets '((nil :maxlevel . 10) ;; current buf
                             (org-agenda-files :maxlevel . 10))
        org-src-window-setup 'plain
        org-src-lang-modes
        '(("bash" . sh) ("beamer" . latex) ("calc" . fundamental)
          ("emacs-lisp" . emacs-lisp) ("shell" . sh) ("sqlite" . sql)
          ("html" . web) ("js" . js2) ("jsx" . rjsx))
        org-table-shrunk-column-indicator "|"
        ;; these match Plain Org's states as their custom state
        ;; feature doesn't actually work
        org-todo-keywords
        '((sequence
           ;; self-explanatory
           "TODO(t!)"
           ;; in progress, aka 'DOING' 'WORKING ON' 'OPEN'
           "STARTED(s!)"
           ;; waiting on someone else, but still actively being
           ;; worked on.
           "WAITING(w!)" 
           ;; on hold, not actively being worked on or
           ;; with another team with an unknown
           ;; timeline. aka 'BLOCKED'
           "HOLD(h!)"
           ;; things that are high priority to bring
           ;; into the 'TODO' state next. use infrequently
           "NEXT(n!)"
           "|"
           ;; self-explanatory
           "DONE(d!)"
           ;; self-explanatory
           "CANCELLED(c!)"
           ;; use infrequently, different from
           ;; cancelled in that this is something that
           ;; is not necessary any longer due to the
           ;; fact that its purpose is being fulfilled
           ;; by something else.  cancelled is meant to
           ;; capture the cancellation of a task for
           ;; some other reason, whether a
           ;; reprioritization or scope-change
           "OBSOLETE(o!)"
           ))
        )


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
          ""
          ;;(if (string= ((project-name (project-current nil default-directory))) "-")
          ;;file
          ;;((project-name (project-current nil default-directory))))
          ))
      ))

  (defun zetta-org-open-at-point ()
    (interactive)
    (let ((browse-url-browser-function 'browse-url-default-browser))
      (call-interactively 'org-open-at-point)))

  ;; display
  ;; TODO these don't load immediately: fix
  ;;(add-to-list 'org-emphasis-alist '("*" (:foreground "black" :background "yellow")))

  ;; makes visible in focus mode
  ;; defer styling to hl-todo which allows finer grained control inside and outside of headings
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
      ;; NOTE adjusting height prevents overline from adding height to line
      (set-face-attribute 'org-block nil :background brushup-bg-1_0 :extend nil)
      (set-face-attribute 'org-block-begin-line nil :background brushup-bg-1_0 :underline brushup-bg-1 :weight 'normal :extend nil :foreground brushup-bg-6 :overline brushup-bg-3 :height 0.9)
      (set-face-attribute 'org-block-end-line nil :background brushup-bg-1_0 :weight 'normal :extend nil :foreground brushup-bg-3 :underline nil :overline nil :height 0.8)

      (set-face-attribute 'org-special-keyword nil :background brushup-bg :foreground brushup-bg-6 :extend nil)
      (set-face-attribute 'org-property-value nil :background brushup-bg :foreground brushup-bg-6 :extend nil)
      (set-face-attribute 'org-document-info-keyword nil :background brushup-bg :foreground brushup-bg-6 :extend nil)
      ))

  (defun zetta-org-go ()
    (interactive)
    (org-refile '(1)))

  (defun zetta-org-append ()
    (interactive)
    (org-insert-heading-respect-content)
    (evil-append 1)
    )

  (defun zetta-org-append-todo ()
    (interactive)
    (org-insert-heading-respect-content)
    (evil-append 1)
    )

  (defun call-zetta-org-todo-with-prefix ()
    (interactive)
    (let ((current-prefix-arg '(4)))
      (call-interactively 'zetta-org-todo)
      )
    )

  (defun zetta-org-call-tangle-with-prefix ()
    (interactive)
    (setq current-prefix-arg '(4))
    (call-interactively 'org-babel-tangle))
  

  :evil
  (evil-set-initial-state 'org-mode 'normal)



  :general
  (
   :keymaps '(org-mode-map)
   "<S-return>" 'org-edit-special
   "C-+" 'org-table-expand
   "C-_" 'org-table-shrink
   "s-j" 'org-next-visible-heading
   "s-k" 'org-previous-visible-heading
   "s-J" 'org-babel-next-src-block
   "s-K" 'org-babel-previous-src-block
   )
  (
   :keymaps '(org-mode-map org-agenda-mode-map)
   "C-c C-S-o" 'zetta-org-open-at-point
   "C-c C-o" 'org-open-at-point
   )
  (
   ;; TODO make this org-specific -- already tried, but couldn't get
   ;; the keybindings to work
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

   ;; tree structure
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

   ;; misc
   "m" (** org-mark-element)
   "M" (** org-mark-subtree)
   "C-t" (** zetta-org-call-tangle-with-prefix)
   "C-S-t" (** org-babel-tangle)
   )

  :hook (
         (org-ctrl-c-ctrl-c-final . org-table-shrink)
         (org-mode . (lambda () (progn
                                  (auto-fill-mode -1)
                                  (org-indent-mode -1)
                                  (visual-line-mode -1)
                                  ;; NOTE prevents indefinte
                                  ;; indentation of code blocks
                                  (electric-indent-mode -1)
                                  (toggle-truncate-lines -1)
                                  (when (fboundp 'undo-tree-mode)
                                    (undo-tree-mode +1))
                                  )))))

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
             ;; Handle key conflicts by appending numbers
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

(defun zetta-logseq-update-agenda-files ()
  "Add all (todo) files to org-agenda-files."
  (let ((todo-files (zetta-logseq-todo-files)))
    (dolist (file todo-files)
      (add-to-list 'org-agenda-files file t))))

;;; org-capture configuration
(require 'org-capture)

;; Build capture templates: base + logseq (todo) files
(setq org-capture-templates
      (append
       '(("o" "Simple capture"
          entry
          (file "~/logseq/pages/capture.org")
          "* %?\n%a"
          :prepend t))
       ;; Add logseq (todo) file templates dynamically
       (zetta-logseq-generate-capture-templates)))

;; Add (todo) files to agenda
(zetta-logseq-update-agenda-files)

;;; Log initial deadline/schedule creation
;; org-log-redeadline and org-log-reschedule only log *changes*, not initial
;; creation. These advice functions add logging when deadline/schedule is first set.

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
  "Advice to log when a deadline is initially set (not just changed).
Wraps `org-deadline' to detect when there was no previous deadline."
  (let ((had-deadline (org-entry-get nil "DEADLINE")))
    (funcall orig-fun arg time)
    ;; Log if this was an initial set (no previous deadline) and we're not removing
    (when (and (not had-deadline)
               (not (equal arg '(4)))  ; C-u removes deadline
               zetta-org-log-initial-deadline
               (org-entry-get nil "DEADLINE"))
      (zetta-org--log-initial-timestamp 'deadline (org-entry-get nil "DEADLINE")))))

(defun zetta-org-schedule-log-initial-a (orig-fun &optional arg time)
  "Advice to log when a schedule is initially set (not just changed).
Wraps `org-schedule' to detect when there was no previous schedule."
  (let ((had-schedule (org-entry-get nil "SCHEDULED")))
    (funcall orig-fun arg time)
    ;; Log if this was an initial set (no previous schedule) and we're not removing
    (when (and (not had-schedule)
               (not (equal arg '(4)))  ; C-u removes schedule
               zetta-org-log-initial-schedule
               (org-entry-get nil "SCHEDULED"))
      (zetta-org--log-initial-timestamp 'scheduled (org-entry-get nil "SCHEDULED")))))

(advice-add 'org-deadline :around #'zetta-org-deadline-log-initial-a)
(advice-add 'org-schedule :around #'zetta-org-schedule-log-initial-a)

(provide 'bootstrap-org)











