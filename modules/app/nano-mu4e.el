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

  ;; Keep conversation forks visible.  Upstream's nano-mu4e-thread-prefix
  ;; blanks every tree glyph except the connection bar, flattening a
  ;; thread to a plain sequence (depth-first order still groups each
  ;; branch, but siblings are indistinguishable).  Restore minimal
  ;; child/last-child glyphs; plain box-drawing only — Terminus has no
  ;; arc glyphs.  Both cons cells identical so fancy-chars is moot.
  (defun zetta-nano-mu4e-thread-prefix (msg)
    "Thread prefix with fork structure (├/└) kept visible."
    (let* ((meta (plist-get msg :meta))
           (mu4e-headers-thread-root-prefix          '(""   . ""))
           (mu4e-headers-thread-first-child-prefix   '(" ├" . " ├"))
           (mu4e-headers-thread-child-prefix         '(" ├" . " ├"))
           (mu4e-headers-thread-last-child-prefix    '(" └" . " └"))
           (mu4e-headers-thread-connection-prefix    '(" │" . " │"))
           (mu4e-headers-thread-blank-prefix         '("  " . "  "))
           (mu4e-headers-thread-orphan-prefix        '(""   . ""))
           (mu4e-headers-thread-single-orphan-prefix '(""   . ""))
           (mu4e-headers-thread-duplicate-prefix     '(""   . "")))
      (mu4e~headers-thread-prefix meta)))
  (advice-add 'nano-mu4e-thread-prefix :override #'zetta-nano-mu4e-thread-prefix)

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

  ;; Tags feature deliberately disabled: mu4e tags are local-only,
  ;; upstream's tag mark is broken without private config (missing
  ;; mu4e-marks entry), and the async retag/refresh dance flashes the
  ;; buffer.  Mail todos go through org-capture ("m" template) instead.
  ;; Unbind nano's tag keys so they can't hit the broken path.
  (define-key nano-mu4e-mode-map (kbd "t") nil)
  (define-key nano-mu4e-mode-map (kbd "T") nil)

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
  ;; g prefix.
  (define-key nano-mu4e-mode-map (kbd ":") nil)
  (define-key nano-mu4e-mode-map (kbd "G") nil)
  (define-key nano-mu4e-mode-map (kbd "g g") #'beginning-of-buffer)
  ;; "r" marks for read.  mu4e's stock r (refile) is already eaten by
  ;; evil normal here, and nano-mu4e leaves r unbound, so nothing
  ;; useful is displaced; "!" still works too.
  (define-key nano-mu4e-mode-map (kbd "r") #'mu4e-headers-mark-for-read)
  ;; RET opens the message.  Without this, RET reaches evil's evil-ret,
  ;; which activates the button under point — usually the sender name,
  ;; whose action is a from:<sender> search.  Mouse still clicks buttons.
  (define-key nano-mu4e-mode-map (kbd "RET") #'mu4e-headers-view-message)

  ;; Region marking: mu4e-mark-set's own region loop advances with
  ;; mu4e-headers-next, which cannot step across nano-mu4e's
  ;; multi-line boxes (it immediately reports no-more-messages), so it
  ;; would only mark the first message.  Walk the msg text-property
  ;; blocks instead — one contiguous block per message.
  (defun zetta-nano-mu4e-visual-mark-read (beg end)
    "Mark every message touched by the region BEG..END for read.
Exits evil visual state afterwards so the marks are visible."
    (interactive "r")
    (deactivate-mark)
    (save-excursion
      (let ((pos beg))
        (while (and pos (< pos end))
          (when (get-text-property pos 'msg)
            (goto-char pos)
            (mu4e-mark-set 'read))
          (setq pos (next-single-property-change pos 'msg nil end)))))
    (when (and (fboundp 'evil-visual-state-p) (evil-visual-state-p))
      (evil-exit-visual-state)))

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
  ;; Article view: same arrangement as headers — evil normal with the
  ;; view map overriding.  Free evil's essentials first: "," is the
  ;; launch leader (was mu4e-sexp-at-point, a debug helper), k is
  ;; line-up (save-url moves to g U), g becomes a prefix (go-to-url on
  ;; g u, gg restored).
  (define-key mu4e-view-mode-map (kbd ",") nil)
  (define-key mu4e-view-mode-map (kbd "k") nil)
  (define-key mu4e-view-mode-map (kbd "g") nil)
  (define-key mu4e-view-mode-map (kbd "g g") #'beginning-of-buffer)
  (define-key mu4e-view-mode-map (kbd "g u") #'mu4e-view-go-to-url)
  (define-key mu4e-view-mode-map (kbd "g U") #'mu4e-view-save-url)
  ;; "r" replies, matching r = mark-read in headers as the "obvious"
  ;; key.  Displaces the stock mu4e-view-mark-for-refile; refiling
  ;; still works from the headers view.
  (define-key mu4e-view-mode-map (kbd "r") #'mu4e-compose-reply)
  ;; "e" always prompts for the save directory (stock needs C-u e;
  ;; plain e dumps into mu4e-attachment-dir, which .private.el points
  ;; at ~/Desktop — that stays the prompt's starting suggestion).
  (defun zetta-mu4e-save-attachments-ask ()
    "Save attachment(s), prompting for the target directory."
    (interactive)
    (mu4e-view-save-attachments t))
  (define-key mu4e-view-mode-map (kbd "e") #'zetta-mu4e-save-attachments-ask)

  (with-eval-after-load 'evil
    (evil-set-initial-state 'mu4e-headers-mode 'normal)
    (evil-make-overriding-map nano-mu4e-mode-map 'normal)
    ;; The overriding map only covers normal state; in visual state r
    ;; would fall back to evil-replace, so bind it there explicitly.
    (evil-define-key 'visual nano-mu4e-mode-map
      (kbd "r") #'zetta-nano-mu4e-visual-mark-read)
    (add-hook 'nano-mu4e-mode-hook #'evil-normalize-keymaps)
    (evil-set-initial-state 'mu4e-view-mode 'normal)
    (evil-make-overriding-map mu4e-view-mode-map 'normal)
    (add-hook 'mu4e-view-mode-hook #'evil-normalize-keymaps)
    (evil-set-initial-state 'mu4e-main-mode 'emacs))

  ;; Upstream bug: `nano-mu4e-msg-preview' binds charset inside its
  ;; when-let*, so a MIME part with no explicit charset= parameter
  ;; (RFC-legal, defaults to us-ascii) nils the chain and the preview
  ;; silently disappears.  Corrected copy; drop when fixed upstream.
  ;; Previews are recomputed synchronously on EVERY render upstream —
  ;; measured 29s of a 29.3s render for the 16k-unread inbox (~1500
  ;; lines with include-related, all "new" so all previewed, digests
  ;; through shr).  Bodies are immutable, so cache them — keyed by
  ;; message-id, which survives reindexing (docids renumber) — and
  ;; persist the cache across sessions so only genuinely new mail
  ;; pays the extraction cost.
  (require 'dom)

  (defvar zetta-nano-mu4e--preview-cache (make-hash-table :test 'equal)
    "Message-id → preview string.")

  (defvar zetta-nano-mu4e--preview-cache-file
    (expand-file-name "nano-mu4e-preview-cache.eld" user-emacs-directory)
    "Persisted preview cache (gitignored).")

  (defvar zetta-nano-mu4e--preview-cache-dirty nil)

  (defun zetta-nano-mu4e--preview-cache-load ()
    "Merge the persisted preview cache into the in-memory table."
    (when (file-readable-p zetta-nano-mu4e--preview-cache-file)
      (ignore-errors
        (with-temp-buffer
          (insert-file-contents zetta-nano-mu4e--preview-cache-file)
          (dolist (pair (read (current-buffer)))
            (puthash (car pair) (cdr pair) zetta-nano-mu4e--preview-cache))))))

  (defun zetta-nano-mu4e--preview-cache-save ()
    "Write the preview cache to disk when it has new entries."
    (when zetta-nano-mu4e--preview-cache-dirty
      (setq zetta-nano-mu4e--preview-cache-dirty nil)
      (ignore-errors
        (with-temp-file zetta-nano-mu4e--preview-cache-file
          (let ((print-length nil) (print-level nil) (pairs nil))
            (maphash (lambda (k v) (push (cons k v) pairs))
                     zetta-nano-mu4e--preview-cache)
            (prin1 pairs (current-buffer)))))))

  (zetta-nano-mu4e--preview-cache-load)
  (add-hook 'kill-emacs-hook #'zetta-nano-mu4e--preview-cache-save)
  (run-with-idle-timer 120 t #'zetta-nano-mu4e--preview-cache-save)

  (defun zetta-nano-mu4e--dom-text (node)
    "Text content of NODE, skipping style/script/head/title subtrees.
`dom-texts' would include CSS from marketing mail's <style> blocks."
    (cond
     ((stringp node) node)
     ((memq (dom-tag node) '(style script head title comment)) "")
     (t (mapconcat #'zetta-nano-mu4e--dom-text (dom-children node) " "))))

  (defun zetta-nano-mu4e--msg-preview (&optional msg size)
    "Extract a short preview from MSG, limiting it to SIZE characters.
Returns nil when MSG's file is not readable: executing marks renames
maildir files (read = new/ → cur/ + S flag) and nano-mu4e's delayed
refresh re-renders from cached paths, so a signaling
`mu4e-message-readable-path' would abort the refresh mid-render and
leave the headers buffer half-drawn."
    (let* ((msg (or msg (mu4e-message-at-point)))
           (msgid (and msg (plist-get msg :message-id))))
      (or (and msgid (gethash msgid zetta-nano-mu4e--preview-cache))
          (when-let* ((msg msg)
                      (size (or size 256))
                      (filename (ignore-errors (mu4e-message-readable-path msg))))
            (when (> (hash-table-count zetta-nano-mu4e--preview-cache) 5000)
              (clrhash zetta-nano-mu4e--preview-cache))
            (let ((preview
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
                             ;; utf-8, not the RFC 2046 default us-ascii:
                             ;; ASCII is a subset of UTF-8 so conforming
                             ;; parts decode the same, and undeclared-UTF-8
                             ;; senders render correctly (matches the
                             ;; upstream PR after Rougier's review).
                             (let ((charset (or (mail-content-type-get (mm-handle-type handle) 'charset)
                                                'utf-8)))
                               (cond ((string= media-type "text/plain")
                                      (with-temp-buffer
                                        (insert (mm-decode-string content charset))
                                        (nano-mu4e-preview--process size)))
                                     ((string= media-type "text/html")
                                      (with-temp-buffer
                                        (insert (mm-decode-string content charset))
                                        ;; libxml (native C) + text walk beats
                                        ;; shr's full layout pass by ~an order
                                        ;; of magnitude; a 256-char excerpt
                                        ;; doesn't need layout.
                                        (if (fboundp 'libxml-parse-html-region)
                                            (let ((dom (libxml-parse-html-region
                                                        (point-min) (point-max))))
                                              (erase-buffer)
                                              (when dom
                                                (insert (zetta-nano-mu4e--dom-text dom))))
                                          (let ((shr-inhibit-images t))
                                            (shr-render-region (point-min) (point-max))))
                                        (nano-mu4e-preview--process size)))
                                     (t "No message body found"))))
                         (mm-destroy-parts handles))))))
              (when (and msgid preview)
                (puthash msgid preview zetta-nano-mu4e--preview-cache)
                (setq zetta-nano-mu4e--preview-cache-dirty t))
              preview)))))
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
  ;; Re-apply NOW: the :brushup keyword is appended at the END of
  ;; use-package-keywords, so this section runs after :config — a
  ;; re-apply there fires before the form above is registered, and the
  ;; faces (created by nano-mu4e loading, long after the theme was
  ;; applied) stay at upstream defaults until the first theme toggle.
  (when (fboundp 'brushup) (brushup))
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
