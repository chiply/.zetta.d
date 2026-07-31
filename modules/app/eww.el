;;; eww.el --- Configure eww -*- lexical-binding: t; -*-

(use-package eww
  :ensure nil
  :commands (eww eww-browse-url)
  :config
  (setq eww-auto-rename-buffer 'title)
  (setq eww-bookmarks-directory (expand-file-name "data/eww" user-emacs-directory))
  ;; eww-default-download-directory set in ~/.private.el

  ;; Rendering settings
  (setq shr-max-image-proportion 0.7)
  (setq shr-inhibit-images nil)
  (setq shr-use-fonts t)
  (setq shr-max-width nil)
  (setq shr-width 0)
  (setq shr-discard-aria-hidden t)
  (setq shr-cookie-policy nil)
  (set-face-attribute 'shr-text nil :family "Terminus (TTF)")

  (setopt eww-search-prefix "https://lite.duckduckgo.com/lite/?q=")

  ;; Per-URL image control
  (defun my-eww-inhibit-images-advice (orig-fun url &rest args)
    "Set shr-inhibit-images based on URL before calling eww."
    (setq shr-inhibit-images
          (not (string-match-p
                "reddit\\.com\\|twitter\\.com\\|xkcd\\.com\\|github\\.com\\|wikipedia\\.org\\|wikipedia\\.org"
                url)))
    (apply orig-fun url args))
  (advice-add 'eww :around #'my-eww-inhibit-images-advice)

  ;; Per-URL readable mode
  (defun zetta-eww-after-render-functions ()
    (unless (string-match-p
             "reddit\\|xkcd\\|orgmode\\.org\\|sachachua\\.com"
             (eww-current-url))
      (eww-readable))
    (setq-local truncate-lines nil)
    ;; Single-space sentence endings -- same reasoning as in
    ;; `zetta-eww-mode-functions'. Set here too so it survives
    ;; `eww-readable' and applies on every render, not just mode init.
    (setq-local sentence-end-double-space nil))

  (defun zetta-eww-mode-functions ()
    (setq-local truncate-lines nil)
    ;; Rendered HTML uses single-space sentence endings (modern
    ;; convention); the default `sentence-end-double-space = t' then
    ;; treats whole paragraphs as one sentence, which breaks
    ;; `forward-sentence', `bounds-of-thing-at-point 'sentence', and
    ;; the embark `sentence' target finder.
    (setq-local sentence-end-double-space nil)
    (olivetti-mode -1))

  (add-hook 'eww-after-render-hook 'zetta-eww-after-render-functions)
  (add-hook 'eww-mode-hook 'zetta-eww-mode-functions)

  (defun zetta-eww-switch-to-eaf ()
    (interactive)
    (eaf-open-browser (eww-current-url)))

  (defun zetta-eww-follow-link ()
    (interactive)
    (browse-url (thing-at-point 'url)))

  ;; PDFs land in the synced kb tree, per-domain like org-remark notes;
  ;; they sync everywhere and are annotatable on iOS in Preview via
  ;; Files -> Synctrain.
  (defvar zetta-kb-pdf-directory (expand-file-name "~/kb/pdfs/")
    "Root for PDFs saved into the synced kb tree.")

  (defun zetta-eww-save-pdf-to-kb (&optional url)
    "Download the PDF at point or URL into `zetta-kb-pdf-directory'.
Uses the link at point, else the current page's URL, else prompts.
Files land in ~/kb/pdfs/<domain>/<name>.pdf; a missing .pdf suffix is
added (arxiv-style URLs), and an existing file is overwritten so
re-downloading the same URL is idempotent."
    (interactive)
    (let* ((url (or url
                    (get-text-property (point) 'shr-url)
                    (and (derived-mode-p 'eww-mode) (eww-current-url))
                    (read-string "PDF URL: ")))
           (parsed (url-generic-parse-url url))
           (host (or (url-host parsed) "unknown"))
           (path (car (url-path-and-query parsed)))
           (name (url-unhex-string (file-name-nondirectory
                                    (directory-file-name (or path "")))))
           (name (if (string-empty-p name) "document" name))
           (name (if (string-suffix-p ".pdf" (downcase name))
                     name
                   (concat name ".pdf")))
           (dir (file-name-as-directory
                 (expand-file-name host zetta-kb-pdf-directory)))
           (target (expand-file-name name dir)))
      (make-directory dir t)
      (url-copy-file url target t)
      (message "kb pdf: %s" (abbreviate-file-name target))
      target))

  :general
  (
   :keymaps '(eww-mode-map)
   :states '(normal)
   "C-&" 'zetta-eww-switch-to-eaf
   "<return>" 'zetta-eww-follow-link
   "D" 'zetta-eww-save-pdf-to-kb
   "x" '(lambda () (interactive) (kill-buffer (current-buffer)))
   "s-i" 'eww-toggle-images
   "s-j" 'treesit-tap-next
   "s-k" 'treesit-tap-prev
   )
  (
   :keymaps 'menu-lookup-map
   "e" 'eww
   ))
;;; eww.el ends here
