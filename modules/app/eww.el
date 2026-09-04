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
  ;; Inherit `variable-pitch' rather than pinning Terminus.  fontaine sets
  ;; that face per preset, so a hard family here meant web pages stayed
  ;; Terminus no matter which preset was active.
  (set-face-attribute 'shr-text nil :family 'unspecified :inherit 'variable-pitch)

  (setopt eww-search-prefix "https://lite.duckduckgo.com/lite/?q=")

  ;; Per-URL image control
  (defun my-eww-inhibit-images-advice (orig-fun url &rest args)
    "Set shr-inhibit-images based on URL before calling eww."
    (setq shr-inhibit-images
          (not (string-match-p
                "reddit\\.com\\|twitter\\.com\\|xkcd\\.com\\|github\\.com\\|wikipedia\\.org\\|wikipedia\\.org\\|old\\.reddit\\.com"
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
  (defvar zetta-kb-pdf-directory (expand-file-name "~/kb/pdf/")
    "Root for PDFs saved into the synced kb tree (existing kb layout).")

  ;; eww renders PDFs into a separate "*eww pdf*" pdf-view buffer that is
  ;; not eww-mode and knows nothing of its URL.  Stash the URL on the way
  ;; through: when `eww-display-pdf' is called, the current buffer is the
  ;; url retrieval buffer, which carries `url-current-object'.
  (defvar zetta-eww--pdf-url nil
    "URL of the PDF most recently displayed by eww.")

  (defun zetta-eww--remember-pdf-url (orig &rest args)
    "Record the PDF's URL before eww hands it to pdf-view."
    (when (bound-and-true-p url-current-object)
      (setq zetta-eww--pdf-url (url-recreate-url url-current-object)))
    (apply orig args))
  (advice-add 'eww-display-pdf :around #'zetta-eww--remember-pdf-url)

  (defun zetta-eww--link-text-at-point ()
    "Text of the shr link at point, when it looks like a real title."
    (when (get-text-property (point) 'shr-url)
      (let* ((start (or (previous-single-property-change (1+ (point)) 'shr-url)
                        (point-min)))
             (end (or (next-single-property-change (point) 'shr-url)
                      (point-max)))
             (text (string-trim (buffer-substring-no-properties start end))))
        ;; skip generic link labels like "PDF", "[pdf]", "Download"
        (when (and (> (length text) 7)
                   (not (string-match-p "\\`\\[?\\(pdf\\|download\\|link\\|here\\)"
                                        (downcase text))))
          text))))

  (defun zetta-kb--pdf-title (file)
    "FILE's PDF metadata title, when present and plausible."
    (when (fboundp 'pdf-info-metadata)
      (let ((title (ignore-errors (cdr (assq 'title (pdf-info-metadata file))))))
        (when (and title
                   (> (length title) 3)
                   (not (string-match-p "\\`[0-9v. -]+\\'" title)))
          title))))

  (defun zetta-kb--sanitize-file-name (name)
    "Collapse whitespace and strip filesystem-hostile chars from NAME.
Quotes vanish; path separators and friends become dashes; no leading
or trailing dash debris."
    (string-trim
     (replace-regexp-in-string
      "\\` *- *\\| *- *\\'" ""
      (replace-regexp-in-string
       "[/\\:*?<>|]+" "-"
       (replace-regexp-in-string
        "[\"']+" ""
        (replace-regexp-in-string "[ \t\n]+" " " name))))))

  (defun zetta-eww-save-pdf-to-kb (&optional url)
    "Download the PDF at point or URL into `zetta-kb-pdf-directory'.
Grabs the link at point, else the current page's URL, else the URL of
the PDF shown in the *eww pdf* buffer, else prompts.  The filename is
imputed from the PDF's metadata title when present, else the link text
at point, else the URL basename — always confirmed via minibuffer, so
RET accepts and editing fixes garbage metadata.  Files land in
~/kb/pdf/<domain>/."
    (interactive)
    (let* ((link-text (zetta-eww--link-text-at-point))
           (url (or url
                    (get-text-property (point) 'shr-url)
                    (and (derived-mode-p 'eww-mode) (eww-current-url))
                    (and (derived-mode-p 'pdf-view-mode 'doc-view-mode)
                         zetta-eww--pdf-url)
                    (read-string "PDF URL: ")))
           (parsed (url-generic-parse-url url))
           (host (or (url-host parsed) "unknown"))
           (base (url-unhex-string (file-name-nondirectory
                                    (directory-file-name
                                     (or (car (url-path-and-query parsed)) "")))))
           (base (file-name-sans-extension
                  (if (string-empty-p base) "document" base)))
           (tmp (make-temp-file "kb-pdf-" nil ".pdf")))
      (url-copy-file url tmp t)
      (let* ((title (or (zetta-kb--pdf-title tmp) link-text base))
             (name (read-string "kb pdf name: "
                                (concat (zetta-kb--sanitize-file-name title)
                                        ".pdf")))
             (dir (file-name-as-directory
                   (expand-file-name host zetta-kb-pdf-directory)))
             (target (expand-file-name name dir)))
        (make-directory dir t)
        (rename-file tmp target t)
        (message "kb pdf: %s" (abbreviate-file-name target))
        target)))

  ;; Images: same idea as PDFs — point at it, one key, lands in kb.
  (defvar zetta-kb-image-directory (expand-file-name "~/kb/images/")
    "Root for images saved into the synced kb tree.")

  (defun zetta-eww--wikimedia-fullsize (url)
    "Upgrade a wikimedia thumbnail URL to its full-size original."
    (if (and (string-match-p "upload\\.wikimedia\\.org" url)
             (string-match "\\`\\(.*\\)/thumb/\\(.*\\)/[0-9]+px-[^/]*\\'" url))
        (concat (match-string 1 url) "/" (match-string 2 url))
      url))

  (defun zetta-eww-save-image-to-kb ()
    "Save the image at point into `zetta-kb-image-directory'.
Files land in images/<page-domain>/ (the page you are reading, not the
CDN host serving the image); wikimedia thumbnails are upgraded to the
full-size original.  The name is confirmed via minibuffer."
    (interactive)
    (let* ((img-url (or (get-text-property (point) 'image-url)
                        (user-error "No image at point")))
           (img-url (zetta-eww--wikimedia-fullsize img-url))
           (page-host (or (and (derived-mode-p 'eww-mode)
                               (url-host (url-generic-parse-url
                                          (eww-current-url))))
                          (url-host (url-generic-parse-url img-url))
                          "unknown"))
           (base (url-unhex-string
                  (file-name-nondirectory
                   (or (car (url-path-and-query
                             (url-generic-parse-url img-url)))
                       ""))))
           (base (if (string-empty-p base) "image" base))
           (name (read-string "kb image name: "
                              (zetta-kb--sanitize-file-name base)))
           (dir (file-name-as-directory
                 (expand-file-name page-host zetta-kb-image-directory)))
           (target (expand-file-name name dir)))
      (make-directory dir t)
      (url-copy-file img-url target t)
      (message "kb image: %s" (abbreviate-file-name target))
      target))

  ;; Images carry shr-image-map as a text property, which outranks evil
  ;; state maps — bind there too so I works with point ON the image.
  (with-eval-after-load 'shr
    (define-key shr-image-map "I" 'zetta-eww-save-image-to-kb))

  :general
  (
   :keymaps '(eww-mode-map)
   :states '(normal)
   "C-&" 'zetta-eww-switch-to-eaf
   "<return>" 'zetta-eww-follow-link
   "D" 'zetta-eww-save-pdf-to-kb
   "I" 'zetta-eww-save-image-to-kb
   "x" '(lambda () (interactive) (kill-buffer (current-buffer)))
   "s-i" 'eww-toggle-images
   "s-j" 'treesit-tap-next
   "s-k" 'treesit-tap-prev
   )
  (
   :keymaps 'pdf-view-mode-map
   :states '(normal)
   "D" 'zetta-eww-save-pdf-to-kb
   )
  (
   :keymaps 'menu-lookup-map
   "e" 'eww
   ))
;;; eww.el ends here
