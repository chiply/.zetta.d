;;; consult.el --- Configure consult -*- lexical-binding: t; -*-

;; NOTE tried implementing a function that lifts the preview keys to
;; temporarily get on the fly previews, but doesn't work as it doesn't
;; apply the completion

(use-package consult
  ;;:ensure (consult :type git :host github :repo "minad/consult" :tag "1.9")
  :after (savehist xref)
  :config

  (recentf-mode t)

  (setq recentf-max-saved-items 500)
  (setq recentf-max-menu-items 50)

  ;; NOTE without this, we don't have a completing read or vomec style
  ;; interface to finding references.  while xref,
  ;; consult-find-references, and consult-ui-peek-references provide
  ;; something like this.  Note this overrides the default of having
  ;; xrefs appear in a serpate buffer, but that's fine since we can
  ;; export references using embark.  in practice, I'll alternate
  ;; between using the consult approach most of the time and lsp-ui
  ;; find references for something more transient (although it doesn't
  ;; really provide additional features, the ui peak just looks cool)
  (setq xref-show-xrefs-function #'consult-xref)

  ;;(setq recentf-save-file (expand-file-name ".data/recentf/recentf" user-emacs-directory))
  (setq consult-preview-key 'any)
  (setq consult-project-root-function #'(project-root (project-current nil default-directory))
        ;; IMPORTANT!  otherwise completion-at-point doesn't use vertico!
        completion-in-region-function 'consult-completion-in-region)

  (setq
   consult-ripgrep-args
   "rg --hidden --glob \"!.git\" --null --line-buffered --color=never --max-columns=1000 --path-separator / --smart-case --no-heading --line-number")

  ;; NOTE because this uses this-command to figure out what to do, it
  ;; doesn't work when calling one of these from
  ;; project-switch-commands or project-prefix-map
  ;; Also doesn't seem to work when calling one consult via another
  (consult-customize
   consult-ripgrep
   consult-buffer
   consult-bookmark
   consult-project-buffer
   consult-theme
   :preview-key "C-=")

  ;;;; Keep the tab-line steady during buffer preview
  ;; `consult--buffer-preview' (consult-buffer, consult-project-buffer AND
  ;; `zetta-consult-elfeed', which reuses it) swaps buffers in and out of the
  ;; window as you move candidates.  Left alone the tab-line flickers in and
  ;; out -- a distracting vertical pop -- because some candidates (special
  ;; buffers) carry no tab-line, so it disappears for those and reappears for
  ;; the next normal buffer.  The other preview family (`consult--jump-preview':
  ;; ripgrep, grep, line, imenu, ...) doesn't need this -- it switches to the
  ;; target's NATURAL tab-line and never hides it.
  ;;
  ;; We want the tab-line PRESENT and steady for the whole preview rather than
  ;; popping, so force uniform presence: on every previewed buffer that lacks a
  ;; tab-line, give it the standard one for the duration; restore on exit.  The
  ;; height never changes, so no vertical pop -- only the (meaningful) tab
  ;; content reflects the buffer under preview.  Set
  ;; `zetta-consult-preview-keep-tab-line' to nil to hide it instead (force it
  ;; absent), which is also steady but blank.
  ;;
  ;; NB: re-evaluate the target on EVERY preview, not just the first time a
  ;; buffer is seen -- `zetta-consult-elfeed' rendered into a buffer whose
  ;; `tab-line-format' could be clobbered between previews (see
  ;; `zetta-consult-elfeed--show'); only act when the value actually needs to
  ;; change, and record the ORIGINAL once so restore is exact.
  ;; NB2: split into a wrapper-maker + a plain helper, joined with
  ;; `apply-partially', rather than returning a lambda that closes over
  ;; STATE-FN.  A closure would need this file to be loaded lexically; if
  ;; anything ever (re)defines this in a dynamic-binding context, that
  ;; closure's STATE-FN is void and consult's state call -- which fires on
  ;; `setup' the instant the picker opens -- errors ("void-variable
  ;; state-fn") and hangs.  `apply-partially' is defined lexically in
  ;; subr.el, so the partial it returns captures STATE-FN/SAVED correctly
  ;; no matter how THIS file was loaded.
  (defcustom zetta-consult-preview-keep-tab-line t
    "How `consult--buffer-preview' treats the tab-line while previewing.
When non-nil, keep the tab-line PRESENT and steady on every previewed
buffer (giving a standard tab-line to candidates that lack one) so it
never pops in and out as preview swaps buffers.  When nil, hide it for
the whole preview instead (steady but blank).  Restored on exit either
way."
    :type 'boolean :group 'zetta)
  (defun zetta--consult-preview-tabline-1 (state-fn saved action cand)
    "Run consult STATE-FN, keeping/hiding previewed buffers' tab-line steady.
Per `zetta-consult-preview-keep-tab-line'.  SAVED is a hash table tracking
touched buffers' prior `tab-line-format' so it can be restored on exit."
    (prog1 (funcall state-fn action cand)
      (pcase action
        ('preview
         (when-let* ((buf (and cand (get-buffer cand)))
                     ((buffer-live-p buf)))
           (with-current-buffer buf
             ;; keep => ensure a tab-line is present (give one if missing);
             ;; hide => force it absent.
             (let ((target (if zetta-consult-preview-keep-tab-line
                               (or tab-line-format '(:eval (tab-line-format)))
                             nil)))
               (unless (equal tab-line-format target)
                 ;; Record the original ONCE before first changing it:
                 ;; `t'-tagged cons = had a buffer-local value to restore;
                 ;; `global' = was not buffer-local (kill on restore).
                 (unless (gethash buf saved)
                   (puthash buf (if (local-variable-p 'tab-line-format)
                                    (cons t tab-line-format)
                                  'global)
                            saved))
                 (setq-local tab-line-format target))))))
        ((or 'exit 'return)
         (maphash (lambda (buf orig)
                    (when (buffer-live-p buf)
                      (with-current-buffer buf
                        (if (eq orig 'global)
                            (kill-local-variable 'tab-line-format)
                          (setq-local tab-line-format (cdr orig))))))
                  saved)
         (clrhash saved)))))
  (defun zetta--consult-preview-tabline (state-fn)
    "Wrap consult buffer-preview STATE-FN to keep previewed buffers' tab-line steady."
    (apply-partially #'zetta--consult-preview-tabline-1
                     state-fn (make-hash-table :test 'eq)))
  (advice-add 'consult--buffer-preview :filter-return
              #'zetta--consult-preview-tabline)

  (setq consult-async-split-style 'comma)
  ;; NOTE consult-omni--get-split-style-character fix moved to consult-omni.el
  ;; (must be defined after consult-omni loads or it gets overwritten)

  (defvar consult--yank-pop-history nil)
  (consult-customize consult-yank-pop :history 'consult--yank-pop-history)

  ;;;; WIKI
  ;; NOTE doesn't work
  ;;(defvar-local consult-toggle-preview-orig nil)

  ;;(defun consult-toggle-preview ()
  ;;"Command to enable/disable preview."
  ;;(interactive)
  ;;(if consult-toggle-preview-orig
  ;;(setq consult--preview-function consult-toggle-preview-orig
  ;;consult-toggle-preview-orig nil)
  ;;(setq consult-toggle-preview-orig consult--preview-function
  ;;consult--preview-function #'ignore)))

  ;;(define-key vertico-map (kbd "C-+") #'consult-toggle-preview)

  ;; project.el
  ;; TODO don't like how verbose and multi-step this is.
  (keymap-substitute project-prefix-map #'project-find-regexp #'consult-ripgrep)
  (cl-nsubstitute-if
   '(consult-ripgrep "Find regexp")
   (pcase-lambda (`(,cmd _)) (eq cmd #'project-find-regexp))
   project-switch-commands)

  ;; you press this, then a key to narrow to a section, but i prefer
  ;; to type the narrow key in and hit space as its easier
  (setq consult-narrow-key "<")

  (general-define-key
   :keymaps 'launch-map
   "b" 'consult-buffer
   "B" 'consult-buffer
   "f" 'consult-project-extra-find)

  (with-eval-after-load 'vertico
    (general-define-key :keymaps 'vertico-map "C-d" 'consult-dir))

  (general-define-key :keymaps 'minibuffer-local-map
    "C-r" 'consult-history)

  :general
  (
   :keymaps 'override
   "M-y" 'consult-yank-pop
   )
  (
   :keymaps 'menu-window-map
   "s" (** consult-ripgrep)
   "S" (** consult-line)
   )
  (
   :keymaps 'launch-map
   "v" 'consult-yank-from-kill-ring
   "s" 'consult-ripgrep
   "S" 'consult-line
   )
  )

(use-package consult-project-extra
  :after consult
  :config
  ;; TODO no sorting by recency in files?
  ;; suddenly started working though...
  (consult-customize
   consult-project-extra-find
   :preview-key "C-="))

(use-package consult-dir)
;;; consult.el ends here
