;;; lsp.el --- Configure lsp-mode -*- lexical-binding: t; -*-

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; LSP MODE
;; NOTE: GC and read-process-output-max tuning is handled in early-init.el

;; can let you see what's being watched... useful for debugging purposes
;; (lsp--all-watchable-directories "~/source_code/workflow-activity-registry" lsp-file-watch-ignored-directories)

(use-package lsp-mode
  :init
  ;; Variables that can be set before lsp-mode loads
  (setq
   lsp-progress-via-spinner nil
   lsp-progress-spinner-type nil
   lsp-enable-completion-at-point t
   lsp-completion-provider :none
   lsp-idle-delay 0.500
   lsp-tooltip-idle-delay 0.500
   lsp-headerline-breadcrumb-enable nil
   lsp-enable-snippet nil
   lsp-enable-indentation nil
   lsp-enable-xref t
   lsp-eldoc-render-all nil
   lsp-eldoc-enable-hover nil
   ;; needs to be set.  we are activating flycheck separately
   lsp-diagnostics-provider :auto ;; :none
   lsp-semantic-highlighting nil
   lsp-signature-render-documentation nil
   lsp-signature-auto-activate nil
   lsp-enable-symbol-highlighting nil
   lsp-modeline-code-actions-enable nil
   lsp-session-file (expand-file-name
                     ".data/lsp/.lsp-session-v1" user-emacs-directory)
   lsp-log-io nil
   ;; performance
   lsp-use-plists t)

  ;; Custom variable for breadcrumb mode variant
  (defvar lsp-headerline-breadcrumb-enable-1 t)

  ;; python
  (setq lsp-language-id-configuration '())
  (add-to-list 'lsp-language-id-configuration '(python-ts-mode . "python"))
  ;; yaml
  (add-to-list 'lsp-language-id-configuration '(yaml-mode . "yaml"))
  ;; bash
  (add-to-list 'lsp-language-id-configuration '(sh-mode . "bash"))
  ;; sql
  (add-to-list 'lsp-language-id-configuration '(sql-mode . "sql"))
  ;; typescript
  (add-to-list 'lsp-language-id-configuration '(typescript-ts-mode . "typescript"))
  ;; tf just to avoid an error
  (add-to-list 'lsp-language-id-configuration '(terraform-mode . "terraform"))

  (setq lsp-terraform-server "terraform-ls")
  (setq lsp-terraform-ls-enable-show-reference t)
  (setq lsp-disabled-clients '(tfls))
  (setq lsp-terraform-ls-enable-show-reference t)
  (setq lsp-semantic-tokens-enable nil)
  (setq lsp-semantic-tokens-honor-refresh-requests nil)
  (setq lsp-enable-links t)

  (setq lsp-terraform-ls-prefill-required-fields t)

  (setq lsp-sqls-server (expand-file-name "~/go/bin/sqls"))
  ;; lsp-sqls-connections set in ~/.private.el

  :config
  ;; Add ignored directories
  (add-to-list 'lsp-file-watch-ignored-directories "[/\\\\]\\.nx\\'")
  (add-to-list 'lsp-file-watch-ignored-directories "[/\\\\]\\.ruff_cache\\'")
  (add-to-list 'lsp-file-watch-ignored-directories "[/\\\\]\\.cache\\'")

  ;; see issue: https://github.com/tigersoldier/company-lsp/issues/145
  (defun lsp--sort-completions (completions)
    (lsp-completion--sort-completions completions))

  (defun lsp--annotate (item)
    (lsp-completion--annotate item))

  (defun lsp--resolve-completion (item)
    (lsp-completion--resolve item))

  (defun lsp-describe-thing-at-point-1 ()
    "Display the type signature and documentation of the thing at point."
    (interactive)
    (let ((thing (zetta-contiguous-chars-at-point))
          (contents (-some->> (lsp--text-document-position-params)
                      (lsp--make-request "textDocument/hover")
                      (lsp--send-request)
                      (lsp:hover-contents))))
      (if (and contents (not (equal contents "")))
          (let* ((lsp-help-buf-name (concat "*L: " thing "*"))
                 (buf (get-buffer-create lsp-help-buf-name)))
            (with-current-buffer buf
              (text-mode)
              (erase-buffer)
              (insert (string-trim-right
                       (lsp--render-on-hover-content contents t)))
              (beginning-of-buffer))
            (display-buffer buf))
        (lsp--info "No content at point."))))

  (defun lsp-find-definition-1 ()
    "Display the type signature and documentation of the thing at point."
    (interactive)
    (lsp-find-definition)
    (let ((buf (current-buffer)))
      (bury-buffer)
      (display-buffer-in-side-window
       buf
       '((side . right)
         (window-width . 0.30)
         (window-parameters . ((no-delete-other-windows . 1)))))))

  (defun evil-goto-definition-1 ()
    "Display the type signature and documentation of the thing at point."
    (interactive)
    (evil-goto-definition)
    (let ((buf (current-buffer)))
      (bury-buffer)
      (display-buffer-in-side-window
       buf
       '((side . right)
         (slot . 1)
         (window-width . 0.30)
         (window-parameters . ((no-delete-other-windows . 1)))))))

  (defun lsp-headerline--enable-breadcrumb-1 ()
    "Enable headerline breadcrumb mode."
    (when (and lsp-headerline-breadcrumb-enable-1
               (lsp-feature? "textDocument/documentSymbol"))
      (lsp-headerline-breadcrumb-mode-1 1)))

  (defun lsp-headerline--disable-breadcrumb-1 ()
    "Disable headerline breadcrumb mode."
    (lsp-headerline-breadcrumb-mode-1 -1))

  (define-minor-mode lsp-headerline-breadcrumb-mode-1
    "Toggle breadcrumb on headerline."
    :group 'lsp-headerline
    :global nil
    (cond
     (lsp-headerline-breadcrumb-mode-1
      (add-hook 'xref-after-jump-hook #'lsp-headerline-check-breadcrumb nil t)
      (add-hook 'lsp-on-idle-hook #'lsp-headerline-check-breadcrumb nil t)
      (add-hook 'lsp-configure-hook #'lsp-headerline--enable-breadcrumb-1 nil t)
      (add-hook 'lsp-unconfigure-hook #'lsp-headerline--disable-breadcrumb-1 nil t))
     (t
      (remove-hook 'lsp-on-idle-hook #'lsp-headerline-check-breadcrumb t)
      (remove-hook 'lsp-configure-hook #'lsp-headerline--enable-breadcrumb-1 t)
      (remove-hook 'lsp-unconfigure-hook #'lsp-headerline--disable-breadcrumb-1 t)
      (remove-hook 'xref-after-jump-hook #'lsp-headerline-check-breadcrumb t)
      (setq lsp-headerline--path-up-to-project-segments nil))))

  ;; TODO turn into a function
  (add-hook 'lsp-configure-hook (lambda()
                                  (message "ran hook lsp-mode-hook")
                                  (lsp-headerline-breadcrumb-mode 0)
                                  (lsp-headerline-breadcrumb-mode-1 1)))

  (add-to-list 'lsp-language-id-configuration '("\\.svelte$" . "svelte"))
  (lsp-register-client
     (make-lsp-client :new-connection (lsp-stdio-connection "svelte-language-server")
                      :major-modes '(svelte-mode)
                      :priority 1
                      :server-id 'svelte-ls))
  (lsp-register-client
   (make-lsp-client :new-connection (lsp-stdio-connection "yaml-language-server")
                    :activation-fn (lsp-activate-on "yaml")
                    :server-id 'yaml-language-server))

  ;; lsp-yaml-schemas set in ~/.private.el

  (setq lsp-headerline-breadcrumb-icons-enable nil)
  (setq lsp-headerline-breadcrumb-enable-diagnostics t)
  (setq lsp-headerline-breadcrumb-segments '(symbols))
  (setq lsp-headerline-breadcrumb-enable-symbol-numbers nil)
  (setq lsp-headerline-arrow ">")

  ;; need to turn on and off for the breadcrumb to be used elsewhere
  (lsp-headerline-breadcrumb-mode 1)
  (lsp-headerline-breadcrumb-mode -1)
  (lsp-headerline-breadcrumb-mode-1 1)
  (lsp-headerline-breadcrumb-mode-1 -1)

  :commands lsp

  :brushup
  (add-to-list 'brushup-styles
               '(progn
                  (set-face-attribute 'lsp-headerline-breadcrumb-symbols-face nil
                                      :weight 'normal
                                      :background brushup-bg-2)
                  ))

  ;;:display
  ;; for the lsp help buffers
  ;;(zetta-side "^\\*L: *" 'right)

  :hook ((python-ts-mode . (lambda ()
                             (lsp-deferred)))
         ((svelte-mode . (lambda ()
                          (lsp))))
         )
  )

;;;;;;;;;;;;;;;;;;;;;;;;;;; Jumping to docs from point
(defun zetta-jump-to-doc ()
  (interactive)
  (condition-case nil
      (helpful-at-point)
    (error (lsp-describe-thing-at-point-1))))

(defun zetta-side-window-p (win)
  (window-parameter win 'window-slot))

(defun zetta-aw-window-list-nonside ()
  "Counts non side windows"
  (-filter (lambda (x) (not (zetta-side-window-p x))) (aw-window-list)))

;;;;;;;;;;;;;;;;;;;;;;;;;;; Jumping to definition from point
(defun zetta-jump-to-def ()
  (interactive)
  (let ((buf (current-buffer)))
    (aw-select "select a window: "
               (lambda (window)
                 (aw-switch-to-window window)
                 (switch-to-buffer buf)
                 (evil-goto-definition)
                 ))
    )
  )

(defun zetta-jump-to-def-vert ()
  (interactive)
  (let ((buf (current-buffer)))
    (if (> (length (zetta-aw-window-list-nonside)) 1)
        (aw-select "select a window: "
                   (lambda (window)
                     (aw-switch-to-window window)
                     (split-window-below)
                     (windmove-down)
                     (switch-to-buffer buf)
                     (evil-goto-definition)
                     )
                   )
      (progn
        (split-window-below)
        (windmove-down)
        (switch-to-buffer buf)
        (evil-goto-definition)
        )
      )
    )
  )

(defun zetta-jump-to-def-vert-1 ()
  (interactive)
  (let ((buf (current-buffer)))
    (if (> (length (zetta-aw-window-list-nonside)) 1)
        (aw-select "select a window: "
                   (lambda (window)
                     (aw-switch-to-window window)
                     (split-window-below)
                     (switch-to-buffer buf)
                     (evil-goto-definition)
                     ))
      (progn
        (split-window-below)
        (switch-to-buffer buf)
        (evil-goto-definition)
        )
      )
    )
  )

(defun zetta-jump-to-def-hor ()
  (interactive)
  (let ((buf (current-buffer)))
    (if (> (length (zetta-aw-window-list-nonside)) 1)
        (aw-select "select a window: "
                   (lambda (window)
                     (aw-switch-to-window window)
                     (split-window-right)
                     (windmove-right)
                     (switch-to-buffer buf)
                     (evil-goto-definition)
                     ))
      (progn
        (split-window-right)
        (windmove-right)
        (switch-to-buffer buf)
        (evil-goto-definition)))))

(defun zetta-jump-to-def-hor-1 ()
  (interactive)
  (let ((buf (current-buffer)))
    (if (> (length (zetta-aw-window-list-nonside)) 1)
        (aw-select "select a window: "
                   (lambda (window)
                     (aw-switch-to-window window)
                     (split-window-right)
                     (switch-to-buffer buf)
                     (evil-goto-definition)
                     ))
      (progn
        (split-window-right)
        (switch-to-buffer buf)
        (evil-goto-definition)))))

(defun zetta-jump-to-def-side ()
  (interactive)
  (let ((buf (current-buffer)))
    (select-window
     (display-buffer-in-side-window buf '(
                                          (side . right)
                                          (side . right)
                                          (slot . 0)
                                          (window-width . 0.30)
                                          (window-parameters . ((no-delete-other-windows . 1)))
                                          )))
    (evil-goto-definition)))

(general-define-key
 :keymaps 'launch-map
 "H" 'zetta-jump-to-doc)

(use-package lsp-ui
  :after lsp-mode
  :config
  ;; sideline

  ;;(setq lsp-ui-sideline-show-hover t)
  ;;(setq lsp-ui-sideline-show-symbol t)
  ;;(setq lsp-ui-sideline-show-diagnostics t)
  ;;(setq lsp-ui-sideline-show-code-actions t)
  ;;(setq lsp-ui-sideline-diagnostic-max-lines 1000)
  (setq lsp-ui-doc-position 'bottom)
  (setq lsp-ui-doc-show-with-cursor t)
  (setq lsp-ui-doc-text-scale-level -4)
  (setq lsp-ui-doc-include-signature t)
  (setq lsp-ui-doc-max-height 10)
  (setq lsp-ui-doc-border "black") ;; NOTE doesn't work
  (setq lsp-ui-doc-header t)
  (setq lsp-ui-doc-frame-parameters
        '((left                     . -1)
          (no-focus-on-map          . t)
          (min-width                . 0)
          (width                    . 0)
          (min-height               . 0)
          (height                   . 0)
          (internal-border-width    . 1)
          (vertical-scroll-bars     . nil)
          (horizontal-scroll-bars   . nil)
          (right-fringe             . 0)
          (menu-bar-lines           . 0)
          (tool-bar-lines           . 0)
          (tab-bar-lines            . 0)
          (tab-bar-lines-keep-state . 0)
          (line-spacing             . 0)
          (unsplittable             . t)
          (undecorated              . t)
          (top                      . -1)
          (visibility               . nil)
          (mouse-wheel-frame        . nil)
          (no-other-frame           . t)
          (inhibit-double-buffering . t)
          (drag-internal-border     . t)
          (no-special-glyphs        . t)
          (desktop-dont-save        . t)
          (alpha . 75)
          (internal-border-width . 2)
          )
        )
  ;; NOTE not rescaling sideline size because it messes with alignment
  ;;(defun lsp-ui-sideline--compute-height ()
  ;;"Return a fixed size for text in sideline."
  ;;'(height 0.5))
  (setq lsp-ui-sideline-actions-icon lsp-ui-sideline-actions-icon-default)
  ;;(set-face-attribute 'lsp-ui-sideline-global nil )

  (add-to-list 'brushup-styles
               '(progn
                  (set-face-attribute 'lsp-ui-sideline-global nil :background brushup-bg :foreground brushup-bg-4)
                  (set-face-attribute 'lsp-ui-sideline-symbol nil :background brushup-bg :foreground brushup-bg-4)
                  (set-face-attribute 'lsp-ui-sideline-symbol-info nil :background brushup-bg :foreground brushup-bg-4)
                  (set-face-attribute 'lsp-ui-sideline-code-action nil :background brushup-bg :foreground brushup-bg-4)
                  (set-face-attribute 'lsp-ui-sideline-current-symbol nil :background brushup-bg :foreground brushup-bg-4)
                  (set-face-attribute 'lsp-ui-doc-header nil :background brushup-bg-2 :foreground brushup-fg)
                  (set-face-attribute 'lsp-ui-doc-background nil :background brushup-bg-1 :foreground brushup-fg)
                  (set-face-attribute 'lsp-signature-posframe nil :background brushup-bg-5 :foreground brushup-fg)
                  )
               )

  :hook
  (
   ;; NOTE imenu mode doesn't work in python, not sure why, but you
   ;;can run lsp-ui-imenu to get a sideline... bizarre, maybe the
   ;;command is falling back to builtin imenu ((python-ts-mode)
   ;;. lsp-ui-imenu-mode)
   ((python-ts-mode) . lsp-ui-peek-mode)
   ((python-ts-mode) . lsp-ui-doc-mode)
   ((after-save-hook) . (lambda ()
                          ;; if buffer *lsp-ui-imenu* is displaying, then run lsp-imenu
                          (when (buffer-live-p (get-buffer "*lsp-ui-imenu*"))
                            (lsp-ui-imenu--refresh)
                            )
                          ))
   ))

(use-package lsp-treemacs
  :after (treemacs)
  :config
  (setq lsp-treemacs-theme "Default")
  (setq lsp-treemacs-error-list-expand-depth 10)
  )

(use-package lsp-pylsp
  :ensure nil
  :after lsp-mode
  :custom
  (lsp-pylsp-plugins-flake8-enabled nil))

(use-package lsp-pyright
  :after lsp-mode
  :custom (lsp-pyright-langserver-command "basedpyright"))

;; NOTE don't use as not all lsps provide compatibility
;; (lsp-capability-not-supported "foldingRangeProvider") (use-package
;; lsp-focus)
;;; lsp.el ends here
