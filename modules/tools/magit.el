;;; magit.el --- Configure magit -*- lexical-binding: t; -*-

(use-package compat :ensure nil :demand t)

(use-package ghub
  ;;:ensure (ghub :type git :host github :repo "magit/ghub" :tag "v4.1.1")
  :defer t
  :config
  ;; NOTE backwards compat with forge
  (setq ghub-default-host "api.github.com")
  )

(use-package magit
  :brushup
  ;; Magit ships its own green/red, picked for its own palette -- against a
  ;; strong theme they read as foreign.  Derive the hues from the theme's diff
  ;; faces and the backgrounds from the brushup gradient, so a diff sits in
  ;; the buffer rather than on top of it.
  (add-to-list
   'brushup-styles
   '(progn
      (dolist (spec (list (list 'magit-diff-added        'added   brushup-bg-1)
                          (list 'magit-diff-added-highlight   'added   brushup-bg-2)
                          (list 'magit-diff-removed      'removed brushup-bg-1)
                          (list 'magit-diff-removed-highlight 'removed brushup-bg-2)
                          (list 'magit-diff-base         'changed brushup-bg-1)
                          (list 'magit-diff-base-highlight    'changed brushup-bg-2)))
        (when (facep (nth 0 spec))
          (set-face-attribute (nth 0 spec) nil
                              :foreground (zetta-theme-color (nth 1 spec))
                              :background (nth 2 spec))))
      ;; context and hunk chrome follow the gradient, not a fixed grey
      (dolist (spec (list (cons 'magit-diff-context brushup-bg)
                          (cons 'magit-diff-context-highlight brushup-bg-1)
                          (cons 'magit-diff-hunk-heading brushup-bg-2)
                          (cons 'magit-diff-hunk-heading-highlight brushup-bg-3)))
        (when (facep (car spec))
          (set-face-attribute (car spec) nil
                              :background (cdr spec)
                              :foreground 'unspecified)))))
  ;;:ensure (magit :type git :host github :repo "magit/magit" :tag "v4.1.1")
  :commands (magit-status magit-blame magit-log magit-branch magit-commit
             magit-push magit-pull magit-fetch magit-stage magit-stage-modified
             magit-tag magit-show-refs zetta-magit-project)
  :init

  (setq magit-branch-read-upstream-first 'fallback)
  (defun zetta-magit-project ()
    (interactive)
    (let ((dir (completing-read "Project: " (project-known-project-roots))))
      (magit-status dir)))

  (setq magit-display-buffer-function #'magit-display-buffer-same-window-except-diff-v1)

  :config
  (setq magit-git-executable (or (executable-find "git") "git"))

  ;; project.el
  (keymap-substitute project-prefix-map #'project-vc-dir #'magit)
  (cl-nsubstitute-if
   '(magit "magit")
   (pcase-lambda (`(,cmd _)) (eq cmd #'project-vc-dir))
   project-switch-commands)

  (setq magit-process-finish-apply-ansi-colors t)

  ;; NOTE neither works??
  ;;(setopt magit-format-file-function #'magit-format-file-nerd-icons)
  ;;(setopt magit-format-file-function #'magit-format-file-all-the-icons)

  ;;(add-hook 'after-save-hook 'magit-after-save-refresh-status)

  ;;(require 'magit-margin)
  ;;(require 'magit-section)

  ;(setq magit-log-margin-show-shortstat t)
  ;(setq magit-status-margin '(t age-abbreviated magit-log-margin-width nil 6))
  ;(setq magit-log-margin '(t age-abbreviated magit-log-margin-width nil 6))
  ;(add-hook 'magit-status-mode-hook 'magit-toggle-log-margin-style)
  ;(add-hook 'magit-log-mode-hook 'magit-toggle-log-margin-style)
  (add-hook 'magit-status-sections-hook #'magit-insert-worktrees)

  (general-unbind :keymaps 'magit-status-mode-map :states 'normal "M-<tab>")
  (general-unbind :keymaps 'magit-mode-map :states 'normal "M-<tab>")
  (general-unbind :keymaps 'magit-section-mode-map :states 'normal "M-<tab>")

  (general-unbind :keymaps 'magit-status-mode-map :states 'normal "C-<tab>")
  (general-unbind :keymaps 'magit-mode-map :states 'normal "C-<tab>")
  (general-unbind :keymaps 'magit-section-mode-map :states 'normal "C-<tab>")

  (general-define-key
   :keymaps 'menu-vc-map
   "g" 'magit-status
   "B" 'magit-branch
   "b" 'magit-blame
   "t" 'magit-tag
   "s" 'magit-stage
   "S" 'magit-stage-modified
   "p" 'magit-push
   "c" 'magit-commit
   "l" 'magit-log
   "r" 'magit-show-refs
   "d" 'vc-diff
   "f" 'magit-fetch
   "p" 'magit-pull
   )

  (general-define-key
   :keymaps 'launch-map
   "G" 'zetta-magit-project)

  (general-define-key
   :keymaps 'text-mode-map
   "C-<return>" 'with-editor-finish
   )
  (general-define-key
   :keymaps '(magit-mode-map magit-log-mode-map magit-blob-mode-map
                             magit-diff-mode-map magit-refs-mode-map
                             magit-blame-mode-map magit-stash-mode-map
                             magit-cherry-mode-map
                             magit-reflog-mode-map
                             magit-status-mode-map
                             magit-process-mode-map
                             magit-section-mode-map
                             magit-stashes-mode-map
                             magit-repolist-mode-map
                             magit-revision-mode-map
                             magit-log-select-mode-map
                             magit-merge-preview-mode-map
                             magit-submodule-list-mode-map
                             magit-blame-read-only-mode-map)
   "C-<tab>" 'tab-line-switch-to-next-tab
   "C-S-<tab>" 'tab-line-switch-to-prev-tab
   "M-S-<tab>" 'st-switch-space-by-name
   "M-<tab>" 'st-go-to-last-space
   )

  )
;;; magit.el ends here
