;;; line.el --- Configure mode-line -*- lexical-binding: t; -*-

(setq default-line-align-left-devel-1
      '(
        ;; leaving this out for now as its easy to see what it is with a command
        ;;(:eval (when (string= major-mode "python-ts-mode")
        ;;(concat "[" pyvenv-virtual-env-name "] ")))
        (:eval (when (or
                      (eq major-mode 'docker-image-mode)
                      (eq major-mode 'docker-container-mode)
                      (eq major-mode 'docker-volume-mode)
                      (eq major-mode 'embark-collect-mode))
                 (propertize
                  (window-parameter (selected-window) 'ace-window-path)
                  'face 'focus-focused)))
        " "
        ;;(:eval (if (string= (symbol-name major-mode) "magit-status-mode") (parrot-create)))
        (:eval (when (fboundp 'spinner-print) (spinner-print spinner-current)))
        " "
        (:eval
         (let ((path (abbreviate-file-name default-directory)))
           (if (> (length path) 30) (zetta-minify-path default-directory) path)))
        " "
        "%c|%l(%p)"
        ))

(setq default-line-align-left-devel-2
      '(
        (:eval
         (cond
          ;; use lsp breadcrumbs if lsp-mode is active
          ((and (boundp 'lsp-mode) lsp-mode)
           (window-parameter nil 'lsp-headerline--string))
          ;; use org breadcrumbs if in org-mode
          ((string= major-mode "org-mode")
           (propertize
            (or (ignore-errors (org-display-outline-path nil t "/" t)) "/")
            ;; to avoid growing headerline when
            ;; using native headerline
            'face '(:height 0.8)))
          ((or (equal major-mode 'jsonian-mode))
           (concat (jsonian--display-path (jsonian-path))))
          ((or (equal major-mode 'docker-compose-mode)
               (equal major-mode 'yaml-mode))
           (concat (jpt-yaml-path-to-point)))
          ;; fallback to imenu breadcrumbs
          (t (when (fboundp 'breadcrumb-imenu-crumbs) (breadcrumb-imenu-crumbs)))
          ))))

;; explain the syntax, why is (:eval) being used
(setq default-line-align-left
      '(
        (:eval (propertize
                (window-parameter (selected-window) 'ace-window-path)
                'face 'ef-themes-heading-0))
        " "
        ;; NOTE can't get the colours working as some have white
        ;; background and I'm unsure how to unset that.  besides, the
        ;; monochrome (light or dark) abstracts better to a wider
        ;; variety of themes.  for some faces i set a face basically
        ;; sacraficing the default colors.
        (:eval (let ((fname (buffer-file-name)))
                 (if fname
                     (all-the-icons-icon-for-file fname)
                   (all-the-icons-icon-for-mode major-mode))))

        ;; these are examples of icons that don't work, when placed in
        ;; the modeline they scale and there's no way to override this
        ;; also don't get it because the SVG looks identical to the
        ;; ones that don't scale...
        ;; nerd icons work for scaling, but they don't look good next
        ;; to the all-the-icons.  also don't look good when placing
        ;; multiple nerd-icons next to one anothejjjr
        (:eval (when (and (boundp 'lsp-mode) lsp-mode)
                 (all-the-icons-icon-for-mode 'lsp-mode)))
        (:eval (when (and (boundp 'copilot-mode) copilot-mode)
                 (all-the-icons-icon-for-mode 'copilot-mode)))
        (:eval (when (zetta-side-window-p (selected-window)) " {S} "))
        " "

        (:eval (let ((result (shell-command-to-string
                              "git rev-parse --is-inside-work-tree")))
                 (when (and result (string= result "true\n"))
                   ;; HACKY: note that some icons still come through
                   ;; with the blank background and get resized whenever
                   ;; i change the fontsize in the buffer.
                   ;; icon-for-mode and icon-for-file seems to work well
                   ;; for this, but only when the relevant entry in
                   ;; `all-the-icons-mode-icon-alist` or `...` has a
                   ;; face set (and this face does not inherit the
                   ;; default font.).  Desired setup up is to be able to
                   ;; directly reference any icon and insert here, but
                   ;; I'm having to use the *-for-* functions in order
                   ;; to get an icon that is fixed height in the
                   ;; modeline
                   (concat " {"
                           (all-the-icons-icon-for-mode 'magit-status-mode)
                           (nth 0 (zetta-get-repo-name))
                           " "
                           (vc-git--symbolic-ref (or (buffer-file-name) default-directory))
                           (all-the-icons-icon-for-mode 'magit-refs-mode)
                           "} ")
                   )))
        (:eval (when (fboundp 'flycheck-indicator--mode-line)
                 (let ((text (flycheck-indicator--mode-line)))
                   (if (string= " not-checked" text) "" text))))
        (:eval (concat (or (if (boundp 'latest-transient) latest-transient) (if (boundp 'local-transient) local-transient)) " "))
        (:eval (when (or
                      (zetta-line-tramp-icon)
                      (zetta-line-docker-icon)
                      (zetta-line-narrowed-icon)
                      (zetta-line-iedit-icon)
                      (zetta-line-hydra-indicator-icon)
                      )
                 " "
                 ))
        ;; note making letters now as there are still issues with
        ;; faces for SVG branch of all-the-icons
        ;; Not sure if actually the ones that change size are the
        ;; intende behavior.  Either way, I tihk it has to do with
        ;; scale attribute of the SVG and there must be a way to
        ;; change this
        ;; Actaulyl the scale attribute is not the culprit here as the
        ;; icons that do have fixed fonts actually have scale 1 as
        ;; well.  Didn't see a difference in the attributes between
        ;; the working and not working icons... will just table this
        ;; for now as I can hack around this by using one of the
        ;; icon-for commands
        (:eval (let ((icon (zetta-line-tramp-icon))) (when icon "T")))
        (:eval (let ((icon (zetta-line-docker-icon))) (when icon "D")))
        (:eval (let ((icon (zetta-line-narrowed-icon))) (when icon "N")))
        ;;(:eval (let ((icon (zetta-line-iedit-icon))) (when icon "I")))
        (:eval (let ((icon (zetta-line-hydra-indicator-icon))) (when icon "H")))
        (:eval (anzu--update-mode-line))
        (:eval (let ((icon (zetta-line-iedit-icon))) (when icon iedit-mode-line)))
        (:eval repeat-echo-mode-line-string)
        (:eval (when (eq major-mode 'magit-status-mode) (nyan-create)))))

(setq default-line-align-middle '(""))
(setq default-line-align-right '(""))

(setq anzu-cons-mode-line-p nil)

;; for apps that strangely don't take the defaults
(add-hook 'treemacs-mode-hook
          '(lambda ()
             (setq mode-line-format
                   (list
                    '(:eval
                      (let ((path (abbreviate-file-name default-directory)))
                        (if (> (length path) 30)
                            (zetta-minify-path default-directory)
                          path)))))
             (setq header-line-format (list
                                       '(:eval (zetta-get-repo-name))
                                       ":"
                                       '(:eval (zetta-get-branch-name))
                                       ))))
;;; line.el ends here
