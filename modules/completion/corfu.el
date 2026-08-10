;;; corfu.el --- Configure corfu -*- lexical-binding: t; -*-

(use-package corfu
  :hook (elpaca-after-init . global-corfu-mode)
  ;; Optional customizations
  :custom
  ;; (corfu-cycle t)                ;; Enable cycling for `corfu-next/previous'
  (corfu-auto t)                 ;; Enable auto completion
  ;; (corfu-separator ?\s)          ;; Orderless field separator
  ;; (corfu-quit-at-boundary nil)   ;; Never quit at completion boundary
  ;; (corfu-quit-no-match nil)      ;; Never quit, even if there is no match
  ;; (corfu-preview-current nil)    ;; Disable current candidate preview
  ;; (corfu-preselect 'prompt)      ;; Preselect the prompt
  ;; (corfu-on-exact-match nil)     ;; Configure handling of exact matches
  ;; (corfu-scroll-margin 5)        ;; Use scroll margin

  ;; Enable Corfu only for certain modes.
  ;; :hook ((prog-mode . corfu-mode)
  ;;        (shell-command-mode . corfu-mode)
  ;;        (eshell-mode . corfu-mode))

  ;; Recommended: Enable Corfu globally.  This is recommended since Dabbrev can
  ;; be used globally (M-/).  See also the customization variable
  ;; `global-corfu-modes' to exclude certain modes.
  :config
  (defun corfu-move-to-minibuffer ()
    (interactive)
    (pcase completion-in-region--data
      (`(,beg ,end ,table ,pred ,extras)
       (let ((completion-extra-properties extras)
             completion-cycle-threshold completion-cycling)
         (consult-completion-in-region beg end table pred)))))
  (keymap-set corfu-map "M-m" #'corfu-move-to-minibuffer)
  (add-to-list 'corfu-continue-commands #'corfu-move-to-minibuffer)

  (defun corfu-enable-in-minibuffer ()
    "Enable Corfu in the minibuffer."
    (when (local-variable-p 'completion-at-point-functions)
      ;; (setq-local corfu-auto nil) ;; Enable/disable auto completion
      (setq-local corfu-echo-delay nil ;; Disable automatic echo and popup
                  corfu-popupinfo-delay nil)
      (corfu-mode 1)))
  (add-hook 'minibuffer-setup-hook #'corfu-enable-in-minibuffer)

  (corfu-echo-mode -1)
  (corfu-indexed-mode 1)
  (corfu-popupinfo-mode 1)

  ;; no automatic info panel — summon it with M-h
  ;; (zetta-corfu-popupinfo-toggle), which enables candidate-following
  ;; at 0.25s until toggled off again
  (setq corfu-popupinfo-delay nil)

  ;; shared three-state cycle for both panel views (M-h docs, M-g
  ;; location): hidden -> show this view for the CURRENT candidate;
  ;; visible in the OTHER view -> switch to this view; visible in
  ;; THIS view -> hide.  The panel is strictly manual: automatic
  ;; display stays off (corfu-popupinfo-delay is nil above) and these
  ;; commands never touch it.
  (defun zetta-corfu--popupinfo-cycle (getter show-fn)
    (if (and (corfu-popupinfo--visible-p)
             (eq corfu-popupinfo--function getter))
        (corfu-popupinfo--hide)
      (funcall show-fn)))

  (defun zetta-corfu-popupinfo-toggle ()
    "Summon, switch to, or dismiss the documentation panel view."
    (interactive)
    (zetta-corfu--popupinfo-cycle #'corfu-popupinfo--get-documentation
                                  #'corfu-popupinfo-documentation))

  (defun zetta-corfu-popupinfo-location-toggle ()
    "Summon, switch to, or dismiss the source-location panel view."
    (interactive)
    (zetta-corfu--popupinfo-cycle #'corfu-popupinfo--get-location
                                  #'corfu-popupinfo-location))

  ;; add frame alpha to corfu--frame-parameters
  (add-to-list 'corfu--frame-parameters '(alpha . (75 . 75)))

  ;; IS (intellisense) actions on the highlighted candidate — docs and
  ;; definition WITHOUT closing the popup: the candidate is
  ;; materialized over the completion region just long enough for the
  ;; position-based lookup, then restored.  Net buffer text and window
  ;; selection are unchanged by the command, and the commands are
  ;; registered in `corfu-continue-commands', so corfu keeps the
  ;; session open.
  (defun zetta-corfu--IS-peek (action)
    "Run ACTION with the highlighted candidate materialized; keep the popup."
    (let ((cand (and corfu--candidates
                     (nth (max corfu--index 0) corfu--candidates))))
      (pcase completion-in-region--data
        ((and `(,beg ,end . ,_) (guard cand))
         (let* ((beg (if (markerp beg) (marker-position beg) beg))
                (end (if (markerp end) (marker-position end) end))
                (orig (buffer-substring beg end))
                ;; LSP labels may carry the full signature
                ;; ("foo(a, b)"); materialize only the name so the
                ;; lookup position lands on a real symbol
                (cand (car (split-string (substring-no-properties cand)
                                         "(")))
                (pt (point)))
           (goto-char beg)
           (delete-region beg end)
           (insert cand)
           (unwind-protect
               (save-selected-window (funcall action))
             (delete-region beg (+ beg (length cand)))
             (goto-char beg)
             (insert orig)
             (goto-char pt))))
        (_ (message "No corfu candidate to inspect")))))

  (defun zetta-corfu-IS-help ()
    "Show docs for the highlighted corfu candidate; the popup stays open."
    (interactive)
    (zetta-corfu--IS-peek
     (lambda ()
       ;; lisp-data-mode is the ancestor of all the lisp modes
       (if (derived-mode-p 'lisp-data-mode)
           (zetta-helpful-at-point)
         (lsp-describe-thing-at-point-1)))))

  (defun zetta-corfu-IS-find ()
    "Show the highlighted candidate's definition; the popup stays open."
    (interactive)
    (zetta-corfu--IS-peek
     (lambda ()
       (if (derived-mode-p 'lisp-data-mode)
           (if (fboundp 'evil-goto-definition-1)
               (evil-goto-definition-1)
             (xref-find-definitions (thing-at-point 'symbol t)))
         (lsp-find-definition-1)))))

  (dolist (cmd '(zetta-corfu-IS-help zetta-corfu-IS-find))
    (add-to-list 'corfu-continue-commands cmd))

  ;; corfu-popupinfo--get-location wraps the :company-location call in
  ;; save-excursion, whose point MARKER collapses to the completion
  ;; region start when zetta-lsp--candidate-location (lsp.el)
  ;; temporarily rewrites that region — markers in deleted text drift.
  ;; An integer position survives the net-zero edit; re-assert it.
  (define-advice corfu-popupinfo--get-location
      (:around (fn cand) zetta-keep-point)
    (let ((pt (point)))
      (prog1 (funcall fn cand)
        (goto-char pt))))

  :brushup

  (add-to-list 'brushup-styles
               '(set-face-attribute 'corfu-default nil
                                    :foreground brushup-fg
                                    :background brushup-bg))

  (add-to-list 'brushup-styles
               '(set-face-attribute 'corfu-current nil
                                    :foreground brushup-fg
                                    :background brushup-bg
                                    ;; NOTE makes this work will across themes
                                    :underline t))

  :general
  (
   :keymaps 'corfu-map
   "M-F" 'corfu-expand
   ;;"M-f" 'corfu-complete
   "C-'" 'corfu-quick-complete
   "RET" 'corfu-complete
   ;; seems counterintuitive, based on the function names, but I like
   ;; this behavior
   "C-S-j" 'corfu-popupinfo-scroll-up
   "C-S-k" 'corfu-popupinfo-scroll-down
   ;; hide/show the info panel views, persistently and symmetrically
   ;; (see zetta-corfu--popupinfo-cycle)
   "M-h" 'zetta-corfu-popupinfo-toggle
   "M-g" 'zetta-corfu-popupinfo-location-toggle
   ;; intellisense on the highlighted candidate (mirrors vertico-map);
   ;; f for "find" — C-S-d belongs to windmove in the override map
   "C-S-h" 'zetta-corfu-IS-help
   "C-S-f" 'zetta-corfu-IS-find))

(defcustom zetta-corfu-icon-height 0.8
  "Relative height for `nerd-icons-corfu' completion icons.
Nerd-icons glyphs rasterize about 1.2x taller than the completion text.
Corfu sizes every candidate row by `default-line-height', so the taller
icon rows overflow and the lower rows are clipped -- barely noticeable at
the normal size, badly at large text scales.  Capping each icon to this
fraction of the text height keeps every row at the line height, so no
candidate is vertically truncated.  Set to nil to disable the cap."
  :type '(choice (const :tag "No cap" nil) number)
  :group 'corfu)

(use-package nerd-icons-corfu
  :after corfu
  :config
  (defun zetta-corfu-cap-icon-height (icon)
    "Cap ICON to `zetta-corfu-icon-height' of the completion text height.
`:filter-return' advice for `nerd-icons-corfu--get-by-kind'.  Returns a copy
of the icon glyph scaled down so Corfu -- which budgets each row at
`default-line-height' -- never clips the lower rows (worst at large text
scales).  Copies the string first so the shared nerd-icons glyph cache is
left untouched; a nil `zetta-corfu-icon-height' leaves the icon unchanged."
    (if (and (stringp icon) (> (length icon) 0) (numberp zetta-corfu-icon-height))
        (let ((s (copy-sequence icon)))
          (add-face-text-property 0 (length s)
                                  (list :height zetta-corfu-icon-height) nil s)
          s)
      icon))
  (advice-add 'nerd-icons-corfu--get-by-kind :filter-return
              #'zetta-corfu-cap-icon-height)

  (add-to-list 'corfu-margin-formatters #'nerd-icons-corfu-formatter))


;;; corfu.el ends here
