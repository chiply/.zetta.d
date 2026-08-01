;;; nano-mu4e.el --- Configure nano-mu4e -*- lexical-binding: t; -*-

;; mu4e is set up in ~/.private.el (loaded eagerly before modules), so
;; :after mu4e fires here without needing further deferral.
;;
;; nano-mu4e is Rougier's boxed headers view for mu4e.  Its glyphs are
;; NERD-font codepoints in the private-use planes with no ASCII
;; fallback (`nano-mu4e-symbol' always returns the NERD variant), and
;; Terminus has no private-use coverage, so those ranges are routed to
;; the NERD-patched Terminess installed system-wide.
;;
;; Threading is off by default here (~/.private.el sets
;; `mu4e-headers-show-threads' nil); nano-mu4e handles both, but its
;; thread boxes/folding only show up when threading is on — toggle
;; per-search with "P" (`mu4e-search-toggle-property') in headers view.

;; nano-mu4e's Package-Requires lists mu4e, but mu4e is provided by the
;; homebrew mu install (site-lisp), not by any elpaca menu — without
;; this the order fails at the dependency-queue step.
(add-to-list 'elpaca-ignored-dependencies 'mu4e)

(use-package nano-mu4e
  :if (executable-find "mu")
  :ensure (nano-mu4e :host github :repo "rougier/nano-mu4e")
  :after mu4e
  :hook (mu4e-headers-mode . nano-mu4e-mode)
  :config
  ;; Body excerpts under messages in the headers view, for ALL new
  ;; messages (the stock predicate `nano-mu4e-msg-preview-p' would
  ;; exclude github notifications and list mail).
  (setq nano-mu4e-msg-preview t
        nano-mu4e-msg-preview-func #'nano-mu4e-msg-is-new)

  ;; Threads start folded after every search, like upstream's
  ;; screenshots: read messages collapse into the "N hidden messages"
  ;; line, unread stay visible.  TAB unfolds a thread (remembered per
  ;; thread), S-TAB flips all.  nano-mu4e's found-handler bypasses the
  ;; stock handler that would normally arrange folding, hence the
  ;; advice; `mu4e-thread--fold-status' is mu4e's global default state.
  (defun zetta-nano-mu4e--fold-all (&rest _)
    (when (buffer-live-p (mu4e-get-headers-buffer))
      (with-current-buffer (mu4e-get-headers-buffer)
        (ignore-errors (mu4e-thread-fold-apply-all)))))
  (setq mu4e-thread--fold-status t)
  (advice-add 'nano-mu4e-found-handler :after #'zetta-nano-mu4e--fold-all)

  (defun zetta-nano-mu4e-toggle ()
    "Toggle between the nano-mu4e and stock mu4e headers display."
    (interactive)
    (let ((enable (not (memq 'nano-mu4e-mode mu4e-headers-mode-hook))))
      (if enable
          (add-hook 'mu4e-headers-mode-hook 'nano-mu4e-mode)
        (remove-hook 'mu4e-headers-mode-hook 'nano-mu4e-mode))
      (when (derived-mode-p 'mu4e-headers-mode)
        (nano-mu4e-mode (if enable 1 -1))
        (mu4e-search-rerun))
      (message "nano-mu4e display %s" (if enable "enabled" "disabled"))))

  ;; Upstream bug: nano-mu4e sets/executes a `tag' mark, but stock
  ;; mu4e-marks has no such entry — nano's mode-on styling creates a
  ;; :char-only stub whose nil :action/:show-target crash execution
  ;; ("void function nil").  Define a real mark.  nano passes the
  ;; complete final tag list; mu4e-action-retag-message wants +/-
  ;; deltas, so diff against the message's current tags.
  (defun zetta-nano-mu4e--retag-absolute (_docid msg target)
    "Set MSG's tags to exactly TARGET, a comma-separated list."
    (let* ((want (split-string (or target "") "," t "[ \t]+"))
           (have (mu4e-message-field msg :tags))
           (delta (append
                   (mapcar (lambda (tag) (concat "+" tag))
                           (cl-set-difference want have :test #'string=))
                   (mapcar (lambda (tag) (concat "-" tag))
                           (cl-set-difference have want :test #'string=)))))
      (when delta
        (mu4e-action-retag-message msg (mapconcat #'identity delta ",")))))
  (setf (alist-get 'tag mu4e-marks)
        (list :char '("(T)" . " ")
              :prompt "tag"
              :ask-target (lambda () (read-string "Tags (comma separated): "))
              :show-target (lambda (target) target)
              :action #'zetta-nano-mu4e--retag-absolute))

  ;; Retagging edits the message file and reindexes asynchronously,
  ;; but nano's immediate refresh re-renders from cached message
  ;; plists, so the new tag never shows (and the stock per-message
  ;; update handler jitters the custom layout).  Re-query the server
  ;; shortly after any tag operation instead.
  (defun zetta-nano-mu4e--rerun-after-tag (&rest _)
    (run-at-time 0.4 nil
                 (lambda ()
                   (when-let* ((buf (mu4e-get-headers-buffer)))
                     (when (buffer-live-p buf)
                       (with-current-buffer buf
                         (ignore-errors (nano-mu4e-rerun))))))))
  (advice-add 'nano-mu4e-toggle-todo :after #'zetta-nano-mu4e--rerun-after-tag)
  (advice-add 'nano-mu4e-edit-tags :after #'zetta-nano-mu4e--rerun-after-tag)
  (advice-add 'nano-mu4e-edit-tags-root :after #'zetta-nano-mu4e--rerun-after-tag)

  ;; Keys: C-j/C-k for message motion; C-l unbound so it falls through
  ;; to the global recenter-top-bottom; vim-style "g r" reruns the
  ;; search (making g a prefix displaces the map's g =
  ;; nano-mu4e-edit-tags-root; G still edits tags at point).
  (define-key nano-mu4e-mode-map (kbd "C-j") #'nano-mu4e-next-msg)
  (define-key nano-mu4e-mode-map (kbd "C-k") #'nano-mu4e-prev-msg)
  (define-key nano-mu4e-mode-map (kbd "C-l") nil)
  (define-key nano-mu4e-mode-map (kbd "g") nil)
  (define-key nano-mu4e-mode-map (kbd "g r") #'nano-mu4e-rerun)
  ;; Leave ":" (ex) and "G" (bottom) to evil; gg is restored inside the
  ;; g prefix.  Tag editing lives on g a / g A ("annotate") — g t
  ;; belongs to spacetree, g l to mu4e-show-log.
  (define-key nano-mu4e-mode-map (kbd ":") nil)
  (define-key nano-mu4e-mode-map (kbd "G") nil)
  (define-key nano-mu4e-mode-map (kbd "g g") #'beginning-of-buffer)
  (define-key nano-mu4e-mode-map (kbd "g a") #'nano-mu4e-edit-tags-root)
  (define-key nano-mu4e-mode-map (kbd "g A") #'nano-mu4e-edit-tags)

  ;; Let mu4e's and nano-mu4e's own keys through the modal layers.
  ;; Both meow-normal and evil-normal sit in emulation-mode-map-alists
  ;; above nano-mu4e's minor-mode map: meow suppresses unbound
  ;; printables (P/U/g...) and evil normal binds TAB (evil-jump-forward)
  ;; among others.  meow motion reserves only j/k/SPC; evil emacs state
  ;; reserves nothing.  The "," launch-map is bound in motion state.
  (with-eval-after-load 'meow
    (dolist (mode '(mu4e-main-mode mu4e-headers-mode mu4e-view-mode))
      (add-to-list 'meow-mode-state-list (cons mode 'motion))))
  ;; Headers: evil NORMAL state with nano-mu4e's map overriding it
  ;; (evil-collection-style) — nano keys (TAB, g r, n/p, x, t...) win,
  ;; everything else stays evil (j/k, "," leader, /-search, gg/G, :).
  ;; Main and view keep emacs state: they're menu/reading buffers whose
  ;; single-letter mu4e keys (s, r, f, q...) evil normal would eat.
  (with-eval-after-load 'evil
    (evil-set-initial-state 'mu4e-headers-mode 'normal)
    (evil-make-overriding-map nano-mu4e-mode-map 'normal)
    (add-hook 'nano-mu4e-mode-hook #'evil-normalize-keymaps)
    (dolist (mode '(mu4e-main-mode mu4e-view-mode))
      (evil-set-initial-state mode 'emacs)))

  ;; Re-apply brushup styles now that the faces below exist.
  (when (fboundp 'brushup) (brushup))

  ;; Upstream bug: `nano-mu4e-msg-preview' binds charset inside its
  ;; when-let*, so a MIME part with no explicit charset= parameter
  ;; (RFC-legal, defaults to us-ascii) nils the chain and the preview
  ;; silently disappears.  Corrected copy; drop when fixed upstream.
  (defun zetta-nano-mu4e--msg-preview (&optional msg size)
    "Extract a short preview from MSG, limiting it to SIZE characters."
    (let* ((msg (or msg (mu4e-message-at-point)))
           (size (or size 256))
           (filename (mu4e-message-readable-path msg)))
      (with-temp-buffer
        (insert-file-contents-literally filename)
        (let* ((handles (mm-dissect-buffer t)))
          (unwind-protect
              (when-let* ((handle (if (bufferp (car handles))
                                      handles
                                    (or (mm-find-part-by-type (cdr handles) "text/plain" nil t)
                                        (mm-find-part-by-type (cdr handles) "text/html" nil t))))
                          (media-type (mm-handle-media-type handle))
                          (content (mm-get-part handle)))
                (let ((charset (or (mail-content-type-get (mm-handle-type handle) 'charset)
                                   'us-ascii)))
                  (cond ((string= media-type "text/plain")
                         (with-temp-buffer
                           (insert (mm-decode-string content charset))
                           (nano-mu4e-preview--process size)))
                        ((string= media-type "text/html")
                         (with-temp-buffer
                           (insert (mm-decode-string content charset))
                           (shr-render-region (point-min) (point-max))
                           (nano-mu4e-preview--process size)))
                        (t "No message body found"))))
            (mm-destroy-parts handles))))))
  (advice-add 'nano-mu4e-msg-preview :override #'zetta-nano-mu4e--msg-preview)

  :brushup
  ;; Upstream faces inherit `link' (blue + underline) for new/unread
  ;; and `widget-field' (underlined here) for the gutter; previews
  ;; inherit `italic', which Terminus doesn't have.  Restyle: purple
  ;; drawn from the theme's keyword face for new/unread/flagged, shadow
  ;; (theme-adaptive gray) for previews, no underlines anywhere.
  (add-to-list 'brushup-styles
               '(when (facep 'nano-mu4e-new)
                  (let ((purple (or (face-foreground 'font-lock-keyword-face nil t)
                                    brushup-fg)))
                    (set-face-attribute 'nano-mu4e-new nil
                                        :inherit 'bold :foreground purple :underline nil)
                    (set-face-attribute 'nano-mu4e-unread nil
                                        :inherit nil :foreground purple :underline nil)
                    (set-face-attribute 'nano-mu4e-flagged nil
                                        :inherit nil :foreground purple :underline nil))
                  (set-face-attribute 'nano-mu4e-preview nil
                                      :inherit 'shadow :slant 'normal)
                  (set-face-attribute 'nano-mu4e-gutter-body nil :underline nil)
                  (set-face-attribute 'nano-mu4e-gutter-match nil :underline nil)))
  :init
  (defvar zetta-nano-mu4e--fontset-done nil)
  (defun zetta-nano-mu4e--fontset (&optional frame)
    "Route NERD private-use glyph ranges to Terminess on the first GUI FRAME."
    (when (and (not zetta-nano-mu4e--fontset-done)
               (display-graphic-p frame))
      (set-fontset-font t '(#xe000 . #xf8ff) "Terminess Nerd Font Mono" nil 'prepend)
      (set-fontset-font t '(#xf0000 . #xfffff) "Terminess Nerd Font Mono" nil 'prepend)
      (setq zetta-nano-mu4e--fontset-done t)))
  ;; The daemon has no GUI frame at init time, so also catch the first
  ;; frame created after startup.
  (add-hook 'after-make-frame-functions #'zetta-nano-mu4e--fontset)
  (zetta-nano-mu4e--fontset))

;;; nano-mu4e.el ends here
