;;; treemacs.el --- Configure treemacs -*- lexical-binding: t; -*-

;; Define commands before use-package so keybindings work before treemacs loads.
(defun zetta-refresh-treemacs ()
  (interactive)
  (let ((treemacs-buf (nth 0 (zetta-soda-mode-displayed-p "treemacs-mode")))
        (win (selected-window)))
    (when treemacs-buf
      (kill-buffer treemacs-buf)
      (treemacs)
      (select-window win))))

(defun zetta-soda-drink-treemacs ()
  (interactive)
  (let* ((win (selected-window))
         (treemacs-buf (nth 0 (zetta-soda-mode-displayed-p "treemacs-mode"))))
    (if treemacs-buf
        (select-window (get-buffer-window treemacs-buf))
      (treemacs)
      (select-window win))))

(defun zetta-soda-toggle-treemacs-follow-mode ()
  (interactive)
  (if treemacs-tag-follow-mode
      (progn
        (treemacs-tag-follow-mode -1)
        (treemacs-follow-mode 1))
    (treemacs-tag-follow-mode 1)))

;; Keybindings available immediately (not deferred to :config)
(general-define-key
 :keymaps 'menu-run-map
 "t" (repeatable-lite-wrap zetta-soda-drink-treemacs)
 "T" (repeatable-lite-wrap treemacs)
 "C-t" (repeatable-lite-wrap zetta-refresh-treemacs)
 "M-t" (repeatable-lite-wrap zetta-soda-toggle-treemacs-follow-mode))

(use-package treemacs
  :ensure (treemacs
           :files ("src/elisp/*.el"
                   "src/extra/*.el"
                   "src/scripts/*.py"))
  :commands (treemacs treemacs-select-window treemacs-add-project)

  :config
  ;; "Idea" theme no longer exists upstream — use "Default".
  (treemacs-load-theme "Default")

  (treemacs-resize-icons nil)

  (setq aw-ignored-buffers '("*Calc Trail*" " *LV*"))

  (setq-default
   treemacs-file-follow-delay 0.5
   treemacs-file-event-delay 2000
   treemacs-tag-follow-delay 1.0
   treemacs-display-in-side-window t
   treemacs-width 35
   treemacs-width-is-initially-locked nil)

  ;; Disable expensive modes that treemacs auto-enables during its own
  ;; init (via `treemacs-only-during-init').  Must happen in :config
  ;; (not :init) because treemacs re-enables them at load time.
  ;;
  ;; git-mode spawns a python subprocess on every node expansion —
  ;; biggest perf hit and source of number-or-marker-p errors.
  (treemacs-git-mode -1)

  ;; Filewatch-mode exhausts macOS file descriptors in large trees.
  (treemacs-filewatch-mode -1)

  ;; Only file-follow — tag-follow adds expensive idle-timer overhead.
  ;; Do NOT call (treemacs-project-follow-mode -1) — its teardown
  ;; unconditionally cancels a timer that doesn't exist when the mode
  ;; was never enabled, throwing (wrong-type-argument timerp nil).
  (treemacs-follow-mode t)
  (treemacs-tag-follow-mode -1)

  :general
  (
   :keymaps '(treemacs-mode-map)
   "o" 'treemacs-visit-node-ace
   "h" 'treemacs-visit-node-ace-horizontal-split
   "v" 'treemacs-visit-node-ace-vertical-split
   "d" 'treemacs-delete-file
   )

  :hook ((use-package--treemacs--post-config . brushup)
         (treemacs-mode . (lambda ()
                            (text-scale-set -2)
                            (toggle-truncate-lines -1)))))

(use-package treemacs-magit
  :ensure nil
  :after (treemacs magit))
;;; treemacs.el ends here
