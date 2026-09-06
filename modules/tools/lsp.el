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
   ;; NOTE no `lsp-progress-spinner-type' value can work here:
   ;; ui/spinner.el replaces `spinner-types' wholesale with custom
   ;; animations, so stock type names resolve to zero frames and the
   ;; spinner timer arith-errors.  The workspace-startup spinner
   ;; (which bypasses via-spinner) is disabled outright in :config by
   ;; overriding `lsp--spinner-start'.
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
   ;; upstream lsp-ruff defaults lint-select to an EMPTY VECTOR and
   ;; always sends it in initializationOptions — ruff server reads
   ;; "select zero rules", overriding pyproject.toml, and publishes no
   ;; diagnostics while the ruff CLI happily reports them.  nil lets
   ;; the project config govern.
   lsp-ruff-lint-select nil
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

  ;; sqls (SQL language server) config lives in tools/sql.el;
  ;; lsp-sqls-connections entries come from ~/.private.el

  :config
  ;; Add ignored directories
  (add-to-list 'lsp-file-watch-ignored-directories "[/\\\\]\\.nx\\'")
  (add-to-list 'lsp-file-watch-ignored-directories "[/\\\\]\\.ruff_cache\\'")
  (add-to-list 'lsp-file-watch-ignored-directories "[/\\\\]\\.cache\\'")

  ;; see issue: https://github.com/tigersoldier/company-lsp/issues/145
  (defun lsp--sort-completions (completions)
    (lsp-completion--sort-completions completions))

  ;; no lsp spinners at all: the startup spinner bypasses
  ;; lsp-progress-via-spinner, and no valid type exists (see :init NOTE)
  (advice-add 'lsp--spinner-start :override #'ignore)

  ;; lsp installs the `lsp-passthrough' completion style for lsp-capf,
  ;; delegating ALL filtering to the server — which makes the corfu
  ;; popup static while typing (client-side re-filtering becomes a
  ;; no-op; elisp filters fine because its capf has no such style).
  ;; Use the regular styles; the lsp table still re-queries the server
  ;; when its cached prefix cannot answer (e.g. on backspace).
  (defun zetta-lsp-completion-setup ()
    ;; client-side styles instead of lsp-passthrough (see above)
    (setf (alist-get 'lsp-capf completion-category-defaults)
          '((styles prescient basic)))
    ;; and bust the capf cache when the input WIDENS: lsp's table
    ;; serves one server response per capf call and corfu keeps the
    ;; session's table, so a session started on a narrow prefix
    ;; ("DataFr") could never widen on backspace.  Typing forward
    ;; remains client-side filtered against the cached response.
    (setq-local completion-at-point-functions
                (cl-substitute
                 (cape-capf-buster #'lsp-completion-at-point
                                   #'string-prefix-p)
                 #'lsp-completion-at-point
                 completion-at-point-functions
                 :test #'eq)))
  (add-hook 'lsp-completion-mode-hook #'zetta-lsp-completion-setup)

  ;; upstream bug: `lsp-completion--get-documentation' prepends
  ;; `detail' to the docs only when detail is absent from the doc
  ;; text, but its cond has no else branch — when detail IS mentioned
  ;; (e.g. DataFrame's docs saying "pandas"), it falls through and
  ;; returns nil, discarding docs the server delivered.  Recover by
  ;; rendering the resolved docs unmodified.
  (define-advice lsp-completion--get-documentation
      (:around (fn item) zetta-fix-nil-doc)
    (or (funcall fn item)
        (when-let* ((resolved (lsp-completion--resolve item))
                    (lsp-item (get-text-property 0 'lsp-completion-item resolved))
                    (doc (lsp:completion-item-documentation? lsp-item))
                    (rendered (lsp--render-element doc)))
          (unless (string-empty-p rendered)
            (put-text-property 0 (length item)
                               'lsp-completion-item-doc rendered item)
            rendered))))

  ;; lsp-mode's capf provides no :company-location, so corfu's M-g
  ;; location view had nothing to ask ("No location available").
  ;; Supply it with the materialize-then-ask trick the IS peeks use:
  ;; put the candidate at point, request its definition, restore.
  (defun zetta-lsp--candidate-location (cand)
    "Return (FILE . LINE) of CAND's definition via lsp, or nil."
    (pcase completion-in-region--data
      (`(,beg ,end . ,_)
       (let* ((beg (if (markerp beg) (marker-position beg) beg))
              (end (if (markerp end) (marker-position end) end))
              (orig (buffer-substring beg end))
              (name (car (split-string (substring-no-properties cand) "("))))
         (goto-char beg)
         (delete-region beg end)
         (insert name)
         (unwind-protect
             (condition-case nil
                 (when-let* ((locs (lsp-request "textDocument/definition"
                                                (lsp--text-document-position-params)))
                             (loc (cond ((lsp-location? locs) locs)
                                        ((and (sequencep locs)
                                              (> (length locs) 0))
                                         (elt locs 0))))
                             (range (if (lsp-location-link? loc)
                                        (lsp:location-link-target-selection-range loc)
                                      (lsp:location-range loc)))
                             (uri (if (lsp-location-link? loc)
                                      (lsp:location-link-target-uri loc)
                                    (lsp:location-uri loc))))
                   (cons (lsp--uri-to-path uri)
                         (1+ (lsp:position-line (lsp:range-start range)))))
               (error nil))
           (delete-region beg (+ beg (length name)))
           (goto-char beg)
           (insert orig))))))

  (define-advice lsp-completion-at-point (:filter-return (res) zetta-add-location)
    (if res
        (append res (list :company-location #'zetta-lsp--candidate-location))
      res))

  ;; the modeline already shows server attachment; keep the echo area
  ;; quiet about routine connection status (errors still come through)
  (define-advice lsp--info (:around (fn fmt &rest args) zetta-quiet-connect)
    (unless (and (stringp fmt)
                 (or (string-prefix-p "Connected to" fmt)
                     (string-match-p "initialized successfully" fmt)))
      (apply fn fmt args)))

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
    "Jump to definition, showing the target in another regular window.
The selected window stays on the original buffer.  When no
definition is found (lsp already messaged), do nothing further;
same-buffer definitions are shown in the other window with point
restored here."
    (interactive)
    (let ((orig-buf (current-buffer))
          (orig-pt (point))
          ;; regular windows, not side windows: reuse one already
          ;; showing the buffer, else split; never the selected window
          (display-action '((display-buffer-reuse-window
                             display-buffer-pop-up-window)
                            (inhibit-same-window . t))))
      (lsp-find-definition)
      (let ((def-buf (current-buffer))
            (def-pt (point)))
        (cond
         ;; nothing moved: definition not found
         ((and (eq def-buf orig-buf) (= def-pt orig-pt)) nil)
         ;; landed in another buffer: put this window back, show def
         ((not (eq def-buf orig-buf))
          (bury-buffer)
          (when-let ((win (display-buffer def-buf display-action)))
            (set-window-point win def-pt)))
         ;; same-buffer definition: stay put, show the location
         (t
          (goto-char orig-pt)
          (when-let ((win (display-buffer def-buf display-action)))
            (set-window-point win def-pt)))))))

  (with-eval-after-load 'evil
    (defun evil-goto-definition-1 ()
      "Jump to definition, showing the target in another regular window."
      (interactive)
      (evil-goto-definition)
      (let ((buf (current-buffer)))
        (bury-buffer)
        (display-buffer buf '((display-buffer-reuse-window
                               display-buffer-pop-up-window)
                              (inhibit-same-window . t))))))

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
         (typescript-ts-mode . (lambda ()
                                 (lsp-deferred)))
         (tsx-ts-mode . (lambda ()
                          (lsp-deferred)))
         ;; ts-ls serves javascript too
         (js2-mode . (lambda ()
                       (lsp-deferred)))
         (rjsx-mode . (lambda ()
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

(defun zetta-doc-at-point ()
  "Show docs for the identifier at point in a help buffer.
Dispatches on major mode — helpful for lisps, lsp hover elsewhere —
rather than try-and-fallback like `zetta-jump-to-doc', so a python
`print' can never show elisp docs."
  (interactive)
  (if (derived-mode-p 'lisp-data-mode)
      (zetta-helpful-at-point)
    (lsp-describe-thing-at-point-1)))

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
                 (if (fboundp 'evil-goto-definition)
                     (evil-goto-definition)
                   (xref-find-definitions (thing-at-point 'symbol t)))))))

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
                     (if (fboundp 'evil-goto-definition)
                         (evil-goto-definition)
                       (xref-find-definitions (thing-at-point 'symbol t)))))
      (progn
        (split-window-below)
        (windmove-down)
        (switch-to-buffer buf)
        (if (fboundp 'evil-goto-definition)
            (evil-goto-definition)
          (xref-find-definitions (thing-at-point 'symbol t)))))))

(defun zetta-jump-to-def-vert-1 ()
  (interactive)
  (let ((buf (current-buffer)))
    (if (> (length (zetta-aw-window-list-nonside)) 1)
        (aw-select "select a window: "
                   (lambda (window)
                     (aw-switch-to-window window)
                     (split-window-below)
                     (switch-to-buffer buf)
                     (if (fboundp 'evil-goto-definition)
                         (evil-goto-definition)
                       (xref-find-definitions (thing-at-point 'symbol t)))))
      (progn
        (split-window-below)
        (switch-to-buffer buf)
        (if (fboundp 'evil-goto-definition)
            (evil-goto-definition)
          (xref-find-definitions (thing-at-point 'symbol t)))))))

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
                     (if (fboundp 'evil-goto-definition)
                         (evil-goto-definition)
                       (xref-find-definitions (thing-at-point 'symbol t)))))
      (progn
        (split-window-right)
        (windmove-right)
        (switch-to-buffer buf)
        (if (fboundp 'evil-goto-definition)
            (evil-goto-definition)
          (xref-find-definitions (thing-at-point 'symbol t)))))))

(defun zetta-jump-to-def-hor-1 ()
  (interactive)
  (let ((buf (current-buffer)))
    (if (> (length (zetta-aw-window-list-nonside)) 1)
        (aw-select "select a window: "
                   (lambda (window)
                     (aw-switch-to-window window)
                     (split-window-right)
                     (switch-to-buffer buf)
                     (if (fboundp 'evil-goto-definition)
                         (evil-goto-definition)
                       (xref-find-definitions (thing-at-point 'symbol t)))))
      (progn
        (split-window-right)
        (switch-to-buffer buf)
        (if (fboundp 'evil-goto-definition)
            (evil-goto-definition)
          (xref-find-definitions (thing-at-point 'symbol t)))))))

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
    (if (fboundp 'evil-goto-definition)
        (evil-goto-definition)
      (xref-find-definitions (thing-at-point 'symbol t)))))

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
   ;; NOTE do not hook lsp-ui-peek-mode here: it is per-session
   ;; machinery (its enable calls set-transient-map with an abort
   ;; callback), turned on by the lsp-ui-peek-find-* commands
   ;; themselves.  Hooking it per-buffer stacked orphaned transient
   ;; keymaps, which made lsp-ui-peek--abort take several tries.
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
  (lsp-pylsp-plugins-flake8-enabled nil)
  :config
  ;; keep the pyright client from outranking pylsp even if lsp-pyright
  ;; gets loaded again (its client priority beats pylsp's)
  (add-to-list 'lsp-disabled-clients 'pyright))

;; NOTE disabled in favor of pylsp installed per-project by
;; install_lsp_server (.files) — pyright/basedpyright kept getting
;; interrupted (Cancelling textDocument/diagnostic in
;; after-change-functions), and merely loading lsp-pyright makes it
;; win client selection over pylsp
;; (use-package lsp-pyright
;;   :after lsp-mode
;;   :custom (lsp-pyright-langserver-command "basedpyright"))

;; NOTE don't use as not all lsps provide compatibility
;; (lsp-capability-not-supported "foldingRangeProvider") (use-package
;; lsp-focus)
;;; lsp.el ends here
