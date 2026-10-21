;;; git-gutter.el --- Configure diff-hl -*- lexical-binding: t; -*-

;; nicer alternative, but doesn't seem to work in the margins
;; fringe mode is nicer, but overlaps with too much other stuff
(use-package diff-hl)

(use-package git-gutter
  :init
  (global-git-gutter-mode)

  :config
  (setq git-gutter:window-width 2)
  (setq git-gutter:update-interval 2)
  ;; Binary buffers: git-gutter:live-update writes the buffer to a
  ;; temp file to diff it, and raw image/pdf bytes can't be utf-8
  ;; encoded — Emacs pops the select-safe-coding-system warning +
  ;; minibuffer prompt on every idle tick for any image visited
  ;; inside a git repo.  A gutter is meaningless for these anyway.
  (setq git-gutter:disabled-modes
        '(image-mode doc-view-mode pdf-view-mode archive-mode tar-mode))
  ;; The live-update idle timer is global and trusts buffer-local
  ;; state blindly: async diff sentinels can leave git-gutter:enabled
  ;; t in buffers where the mode never enabled (no vcs-type), and the
  ;; timer then errors every tick — "Error running timer
  ;; 'git-gutter:live-update': (wrong-type-argument arrayp nil)".
  ;; Only live-update where the mode is actually on and initialized.
  (defun zetta-git-gutter--live-update-sane-p (&rest _)
    (and git-gutter-mode git-gutter:vcs-type))
  (advice-add 'git-gutter:live-update :before-while
              #'zetta-git-gutter--live-update-sane-p)

  ;;;; What the gutter diffs against
  ;; After Karthik Chikmagalur, "Fringe Matters: Finding the Right
  ;; Difference" (karthinks.com).  The gutter is plain `git diff' by
  ;; default -- the worktree against the index.  On a feature branch that
  ;; is only what changed since the last commit, and it empties every time
  ;; you commit; the picture worth having there is what the BRANCH has
  ;; done to the file, i.e. the diff against where it left main.  He sets
  ;; diff-hl's `diff-hl-reference-revision'; the gutter here is git-gutter
  ;; (it computes, svg-margin draws), and `git-gutter:start-revision' is
  ;; the same knob.  It is buffer-local and a safe directory-local, so a
  ;; project can also pin it for good:
  ;;   ((nil . ((git-gutter:start-revision . "main"))))
  ;;
  ;; One caveat while a reference is set: "stage hunk" and "revert hunk"
  ;; act on the hunk AS DIFFED, so revert goes back to the reference's
  ;; text, not to HEAD's, and a hunk that is already committed has
  ;; nothing to stage.
  (defvar zetta-git-gutter-project-references nil
    "Alist of (REPOSITORY-ROOT . REVISION): gutter references set this session.
A repository without an entry diffs against the index.")

  (defun zetta-git-gutter--git (&rest args)
    "Run git with ARGS in `default-directory'; its trimmed output, or nil."
    (with-temp-buffer
      (when (eq 0 (ignore-errors
                    (apply #'process-file "git" nil '(t nil) nil args)))
        (let ((out (string-trim (buffer-string))))
          (unless (string-empty-p out) out)))))

  (defun zetta-git-gutter--root ()
    "Root of the repository `default-directory' is in, or nil."
    (when-let* ((root (vc-git-root default-directory)))
      (expand-file-name root)))

  (defun zetta-git-gutter--main-branch ()
    "The branch this repository forks from: origin's HEAD, else main or master."
    (or (zetta-git-gutter--git "symbolic-ref" "--short"
                               "refs/remotes/origin/HEAD")
        (seq-find (lambda (branch)
                    (zetta-git-gutter--git "rev-parse" "--verify" "--quiet"
                                           branch))
                  '("main" "master"))))

  (defun zetta-git-gutter--fork-point (rev)
    "The commit where HEAD and REV diverged, abbreviated.
The fork point and not REV's tip: against the tip, everything REV has
gained since the branch left it shows up as if this branch had removed
it.  For an ancestor of HEAD the two are the same commit."
    (when-let* ((base (zetta-git-gutter--git "merge-base" "HEAD" rev)))
      (zetta-git-gutter--git "rev-parse" "--short" base)))

  (defun zetta-git-gutter--read-revision ()
    "Read a revision, completing over branches and tags."
    (let ((main (zetta-git-gutter--main-branch)))
      (completing-read
       (format-prompt "Gutter reference" main)
       (split-string (or (zetta-git-gutter--git
                          "for-each-ref" "--format=%(refname:short)"
                          "refs/heads" "refs/remotes" "refs/tags")
                         "")
                     "\n" t)
       nil nil nil 'git-gutter:revision-history main)))

  (defun zetta-git-gutter--rediff (ref)
    "Diff the current buffer against REF (nil: the index) and redraw.
A diff still in flight is dropped first: `git-gutter' declines to start
a second one, and that one was started against the old reference."
    (setq git-gutter:start-revision ref)
    (when-let* ((file (git-gutter:base-file))
                (running (get-buffer (git-gutter:diff-process-buffer file))))
      (kill-buffer running))
    (git-gutter))

  (defun zetta-git-gutter--adopt-reference ()
    "Give a buffer whose gutter just came on its repository's reference."
    (when-let* ((root (and zetta-git-gutter-project-references
                           (zetta-git-gutter--root)))
                (ref (alist-get root zetta-git-gutter-project-references
                                nil nil #'equal)))
      (zetta-git-gutter--rediff ref)))
  (add-hook 'git-gutter-mode-on-hook #'zetta-git-gutter--adopt-reference)

  (defun zetta-git-gutter-toggle-reference (&optional arg)
    "Switch the gutter between \"since the last commit\" and \"since main\".
With a reference set, the gutter marks what the current branch has done
to each file -- committed or not -- rather than only what is unstaged.
The reference is the commit where the branch forked from origin's HEAD
\(else main or master), and it covers every buffer of the repository,
including ones opened later this session.  Called again, back to the
index.

With prefix ARG, read the revision to compare against instead."
    (interactive "P")
    (let* ((root (or (zetta-git-gutter--root)
                     (user-error "Not in a git repository")))
           (default-directory root)
           (rev (cond (arg (zetta-git-gutter--read-revision))
                      ((assoc root zetta-git-gutter-project-references) nil)
                      ((zetta-git-gutter--main-branch))
                      (t (user-error "No origin/HEAD, main or master here; \
name a revision with a prefix argument"))))
           (ref (and rev
                     (or (zetta-git-gutter--fork-point rev)
                         (user-error "No common ancestor with `%s'" rev)))))
      (setf (alist-get root zetta-git-gutter-project-references
                       nil 'remove #'equal)
            ref)
      (dolist (buffer (buffer-list))
        (with-current-buffer buffer
          (when (and (bound-and-true-p git-gutter-mode)
                     (equal (zetta-git-gutter--root) root))
            (zetta-git-gutter--rediff ref))))
      (if ref
          (message "Gutter: changes since %s (forked at %s)" rev ref)
        (message "Gutter: changes since the index"))))

  ;; add indicator to margin showing the current line number

  :brushup
  (add-to-list 'brushup-styles
               '(progn
                  (setq brushup-git-gutter-foreground brushup-bg-6
                        brushup-git-gutter-background brushup-bg)
                  ;; Added/deleted/modified were all one colour, so the gutter
                  ;; said "something changed" but never what.  The three hues
                  ;; come from `zetta-vc-marker-ladder' -- three rungs of the
                  ;; theme's own ink ladder rather than the red/green/yellow
                  ;; diff stoplight, which is three colours from outside the
                  ;; theme run down the edge of every window to encode a
                  ;; distinction any three shades can carry.
                  (set-face-attribute 'git-gutter:added nil
                                      :foreground (zetta-vc-marker-color 'added)
                                      :background 'unspecified)
                  (set-face-attribute 'git-gutter:deleted nil
                                      :foreground (zetta-vc-marker-color 'removed)
                                      :background 'unspecified)
                  (set-face-attribute 'git-gutter:modified nil
                                      :foreground (zetta-vc-marker-color 'modified)
                                      :background 'unspecified)
                  (set-face-attribute 'git-gutter:separator nil
                                      :foreground brushup-git-gutter-foreground
                                      :background 'unspecified)
                  ))

  (general-define-key
   :keymaps 'menu-project-map
   "g" (** git-gutter)
   "G" 'zetta-git-gutter-toggle-reference
   "j" (** git-gutter:next-hunk)
   "k" (** git-gutter:previous-hunk))

  :hook (use-package--git-gutter--post-config . brushup)
  )
;;; git-gutter.el ends here
