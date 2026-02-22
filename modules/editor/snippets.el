;;; snippets.el --- Configure yasnippet -*- lexical-binding: t; -*-

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                  yasnippet                                 ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(use-package yasnippet
  :hook (elpaca-after-init . yas-global-mode)

  :init
  ;; Ensure snippet directories exist on first run
  (make-directory (format "%ssource/snippets/snippets/test" user-emacs-directory) t)
  (make-directory (format "%ssource/snippets/snippets/personal" user-emacs-directory) t)

  (setq yas-triggers-in-field t
        yas-indent-line 'fixed
        yas-wrap-around-region 'nil
        yas-snippet-dirs
        `(
          ,(format "%ssource/snippets/snippets/test" user-emacs-directory)
          ,(format "%ssource/snippets/snippets/personal" user-emacs-directory)
          )
        )



  (defun zetta-snippet-file-displayed-p ()
    (interactive)
    (let* ((buffers-being-displayed (-filter
                                     (lambda (x) (zetta-soda-buffer-displayed-p x))
                                     (buffer-list)))
           (names-of-buffers-being-displayed (-map
                                              (lambda (x) (buffer-name x))
                                              buffers-being-displayed)))
      (if (member ".snippets.org" names-of-buffers-being-displayed)
          t
        nil
        )
      )
    )

  (defun zetta-snip-view-snippet-file ()
    (interactive)
    (let ((dir user-emacs-directory))
      (select-window
       (display-buffer
        (find-file-noselect (format "%ssource/snippets/.snippets.org" dir))))
      )
    )

  (defun zetta-snip-search-snippets ()
    (interactive)
    (let ((mode (symbol-name major-mode))
          (win (selected-window))
          (selectrum-display-style '(vertical))
          (inhibit-quit t)
          )
      (unless (with-local-quit
                (zetta-snip-view-snippet-file)
                (consult-line (concat mode " "))
                t)
        (progn
          (select-window win)
          (setq quit-flag nil)
          )
        )
      )
    )

  ;; got from
  ;; https://emacs.stackexchange.com/questions/61108/make-tangle-dont-add-a-newline-at-the-end-of-the-file
  (defun zetta-zap-newline-at-eob ()
    (let ((make-backup-files nil)) 
      (message "running zetta-zap-newline-at-eob")
      (goto-char (point-max))
      (when (equal (char-before) ?\n)
        (delete-char -1)
        (save-buffer))))

  (defun zetta-snip-tangle-and-load (&optional file)
    (interactive)
    (add-hook 'org-babel-post-tangle-hook #'zetta-zap-newline-at-eob)
    (if file
        (org-babel-tangle-file file)
      (org-babel-tangle)
      )
    (yas-reload-all)
    (remove-hook 'org-babel-post-tangle-hook #'zetta-zap-newline-at-eob)
    )

  (defun zetta-snip-new-snippet ()
    (interactive)
    (let ((mode (symbol-name major-mode))
          (win (selected-window))
          (selectrum-display-style '(vertical))
          (inhibit-quit t)
          )
      (if (with-local-quit
            (zetta-snip-view-snippet-file)
            (consult-line (concat mode " ") 1)
            (org-end-of-subtree)
            t)
          (progn
            (insert "\nzsnip")
            (call-interactively 'evil-insert)
            (yas-expand)
            )
        (progn
          (select-window win)
          (setq quit-flag nil)
          )
        )
      ) 
    )

  :config
  (zetta-snip-tangle-and-load (format "%ssource/snippets/.snippets.org" user-emacs-directory))

  :display
  ;;(zetta-side "snippet-mode" 'right 1)

  :general
  (
   :keymaps 'yas-keymap
   "C-;" 'zetta-completion-at-point
   "<tab>" 'yas-next-field
   "<S-tab>" 'yas-prev-field
   )
  (
   :keymaps 'launch-map
   "y" 'hydra-yas/body
   )

  :hook (snippet-mode . (lambda () (text-scale-set -2))))


(use-package yasnippet-snippets)

;; not useful
;;(use-package py-snippets
  ;;:after yasnippet
  ;;:config
  ;;(py-snippets-initialize))

;; numpydoc configured in python.el


;; excellent for discoverability.  like autocompletion, but at the top
;; level for all snippets a really great demo workflow is to open up a
;; buffer in an unfamiliar proigramming language and ismply search for
;; 'function', which will give you the syntax for a function.
(use-package consult-yasnippet)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                   Tempel                                   ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Configure Tempel
(use-package tempel
  ;; Require trigger prefix before template name when completing.
  ;; :custom
  ;; (tempel-trigger-prefix "<")

  :bind (("M-+" . tempel-complete) ;; Alternative tempel-expand
         ("M-*" . tempel-insert))

  :init
  ;; Default tempel-path resolves to <user-emacs-directory>/templates which
  ;; clashes with the existing templates/ directory (holds zetta.example.el).
  ;; Point to a dedicated tempel templates file instead.
  (setq tempel-path (expand-file-name "tempel-templates.eld" user-emacs-directory))

  ;; Setup completion at point
  (defun tempel-setup-capf ()
    ;; Add the Tempel Capf to `completion-at-point-functions'.
    ;; `tempel-expand' only triggers on exact matches. Alternatively use
    ;; `tempel-complete' if you want to see all matches, but then you
    ;; should also configure `tempel-trigger-prefix', such that Tempel
    ;; does not trigger too often when you don't expect it. NOTE: We add
    ;; `tempel-expand' *before* the main programming mode Capf, such
    ;; that it will be tried first.
    (setq-local completion-at-point-functions
                (cons #'tempel-expand
                      completion-at-point-functions)))

  (add-hook 'conf-mode-hook 'tempel-setup-capf)
  (add-hook 'prog-mode-hook 'tempel-setup-capf)
  (add-hook 'text-mode-hook 'tempel-setup-capf)

  ;; Optionally make the Tempel templates available to Abbrev,
  ;; either locally or globally. `expand-abbrev' is bound to C-x '.
  ;; (add-hook 'prog-mode-hook #'tempel-abbrev-mode)
  ;; (global-tempel-abbrev-mode)
)

;; Optional: Add tempel-collection.
;; The package is young and doesn't have comprehensive coverage.
(use-package tempel-collection)
;;; snippets.el ends here
