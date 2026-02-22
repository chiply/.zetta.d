;;; cleanup.el --- Configure startup cleanup -*- lexical-binding: t; -*-

;;;;;;;;;;;;;;;;;;;;;; very strange -- something is adding this hook to org-mode, which causes it to break
(remove-hook 'org-mode-hook 'org)
(setq request-storage-directory (expand-file-name ".data/request" user-emacs-directory))

;; not sure why this isn't working in embark -- may not work here either, i think something overrides this
;; maybe which key setup in meow?
;;(setq prefix-help-command #'embark-prefix-help-command)

;; truly cannot tell what is ovewriting this upstream but should figure it out
(setq prefix-help-command 'versatile-C-h)

(tab-bar-mode +1)

(if debug-on-error
    (toggle-debug-on-error))


(general-unbind :keymaps 'minibuffer-local-map "C-r" nil)

(defun consult-selection-history-prompt (&optional history index bol)
  (interactive)
  (cl-letf (((symbol-function 'consult--current-history)
             '(lambda () (list consult-omni--selection-history))))
    (consult-history)))

(general-define-key :keymaps 'minibuffer-local-map "C-r" 'consult-history)
;; TODO doesn't work when calling from vertico
(general-define-key :keymaps 'minibuffer-local-map "C-S-r" 'consult-selection-history-prompt)

(add-to-list 'savehist-additional-variables 'consult--buffer-history)
(add-to-list 'savehist-additional-variables 'consult--find-history)
(add-to-list 'savehist-additional-variables 'consult--grep-history)
(add-to-list 'savehist-additional-variables 'consult--isearch-history-narrow)
(add-to-list 'savehist-additional-variables 'consult--line-history)
(add-to-list 'savehist-additional-variables 'consult--line-multi-history)
(add-to-list 'savehist-additional-variables 'consult--man-history)
(add-to-list 'savehist-additional-variables 'consult--minor-mode-menu-history)
(add-to-list 'savehist-additional-variables 'consult--path-history)
(add-to-list 'savehist-additional-variables 'consult--theme-history)
(add-to-list 'savehist-additional-variables 'consult-compile--history)
(add-to-list 'savehist-additional-variables 'consult-gh--dashboard-history)
(add-to-list 'savehist-additional-variables 'consult-gh--files-history)
(add-to-list 'savehist-additional-variables 'consult-gh--gitignore-templates-history)
(add-to-list 'savehist-additional-variables 'consult-gh--license-key-history)
(add-to-list 'savehist-additional-variables 'consult-gh--notifications-history)
(add-to-list 'savehist-additional-variables 'consult-gh--orgs-history)
(add-to-list 'savehist-additional-variables 'consult-gh--repos-history)
(add-to-list 'savehist-additional-variables 'consult-gh--search-code-history)
(add-to-list 'savehist-additional-variables 'consult-gh--search-issues-history)
(add-to-list 'savehist-additional-variables 'consult-gh--search-prs-history)
(add-to-list 'savehist-additional-variables 'consult-gh--search-repos-history)
(add-to-list 'savehist-additional-variables 'consult-gh--known-repos-list)
(add-to-list 'savehist-additional-variables 'consult-imenu--history)
(add-to-list 'savehist-additional-variables 'consult-isearch-history-map)
(add-to-list 'savehist-additional-variables 'consult-kmacro--history)
(add-to-list 'savehist-additional-variables 'consult-omni--apps-select-history)
(add-to-list 'savehist-additional-variables 'consult-omni--calc-select-history)
(add-to-list 'savehist-additional-variables 'consult-omni--email-select-history)
(add-to-list 'savehist-additional-variables 'consult-omni--search-history)
(add-to-list 'savehist-additional-variables 'consult-omni--selection-history)
(add-to-list 'savehist-additional-variables 'consult-org--history)
(add-to-list 'savehist-additional-variables 'consult-project-extra--project-history)
(add-to-list 'savehist-additional-variables 'consult-xref--history)
(add-to-list 'savehist-additional-variables 'consult--yank-pop-history)
(add-to-list 'savehist-additional-variables 'kill-ring)
(add-to-list 'savehist-additional-variables 'biblio--search-history)
(add-to-list 'savehist-additional-variables 'elfeed-search-filter-history)
(add-to-list 'savehist-additional-variables 'transient-history)
(add-to-list 'savehist-additional-variables 'bookmark-view-history)



;; needed to load savehist data since initializing the package
;; overwrites the history
(savehist-mode 1)
;;; cleanup.el ends here
