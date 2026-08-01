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
