;;; markdown.el --- Configure markdown-mode -*- lexical-binding: t; -*-

;; Inline image handling for markdown buffers:
;; - Inline images (C-c C-x C-i) are capped to a fraction of the frame
;;   height so large diagrams never dominate the buffer.
;; - C-c C-x v pops the image link at point into another window fit to
;;   the window height; with a prefix arg (C-u) it fits to width.
;;   Inside the image buffer, evil-collection's H / W switch between
;;   fit-height / fit-width, and q quits.

(declare-function markdown-link-url "markdown-mode")
(declare-function markdown--get-remote-image "markdown-mode")
(declare-function url-type "url-parse")
(declare-function url-generic-parse-url "url-parse")
(declare-function zetta-image-pop-out-file "image")
(defvar markdown-max-image-size)
(defvar markdown-translate-filename-function)
(defvar markdown-remote-image-protocols)
(defvar zetta-image-inline-height-fraction)

(defun zetta-markdown--cap-inline-image-size (&rest _)
  "Recompute `markdown-max-image-size' from the selected frame's size.
Height is capped at `zetta-image-inline-height-fraction' of the
frame height, width at the full frame width."
  (setq markdown-max-image-size
        (cons (frame-pixel-width)
              (truncate (* zetta-image-inline-height-fraction
                           (frame-pixel-height))))))

(defun zetta-markdown--html-img-src ()
  "Return the src of an HTML <img> tag on the current line, or nil.
Documents like the system-design-primer README embed images as raw
HTML blocks, which `markdown-link-url' does not parse."
  (save-excursion
    (goto-char (line-beginning-position))
    (when (re-search-forward
           "<img[^>]*?[ \t]src=[\"']?\\([^\"' >]+\\)"
           (line-end-position) t)
      (match-string-no-properties 1))))

(defun zetta-markdown--image-file-at-point ()
  "Return a local file for the image link at point, or nil.
Remote images are downloaded into markdown-mode's image cache.
Mirrors the path resolution in `markdown-display-inline-images'.
Recognizes both markdown image links and raw HTML <img> tags."
  (let ((url (or (markdown-link-url) (zetta-markdown--html-img-src))))
    (when url
      (if (file-exists-p url)
          (expand-file-name url)
        (let* ((translated (funcall markdown-translate-filename-function url))
               (scheme (ignore-errors
                         (downcase (url-type (url-generic-parse-url
                                              translated)))))
               ;; Count plain http as remote too (the primer's solution
               ;; docs use http://i.imgur.com links); fetch via https.
               (remotep (member scheme
                                (cons "http" markdown-remote-image-protocols))))
          (if remotep
              (markdown--get-remote-image
               (if (equal scheme "http")
                   (concat "https" (substring translated (length "http")))
                 translated))
            (let ((file (replace-regexp-in-string "?.+\\'" "" url)))
              (unless (file-exists-p file)
                (setq file (url-unhex-string file)))
              (when (file-exists-p file)
                (expand-file-name file)))))))))

(defun zetta-markdown-pop-out-image (&optional fit-width)
  "Display the image link at point in another window.
See `zetta-image-pop-out-file' for the fit behavior; with prefix
argument FIT-WIDTH, fit to the window width."
  (interactive "P")
  (let ((file (zetta-markdown--image-file-at-point)))
    (unless file
      (user-error "No image link at point"))
    (zetta-image-pop-out-file file fit-width)))

;; Wrap long lines instead of clipping them, mirroring the org-mode
;; hook's (toggle-truncate-lines -1).  Covers gfm-mode too (derived).
(defun zetta-markdown--no-truncate ()
  (toggle-truncate-lines -1))
(add-hook 'markdown-mode-hook #'zetta-markdown--no-truncate)

;; Follow GitHub-style intra-document anchor links ([text](#anchor)).
;; For a bare "#fragment" URL, url-path-and-query returns an empty
;; path, so markdown--browse-url's (> (length file) 0) check silently
;; does nothing.  Jump to the heading whose GFM slug matches instead.
(defun zetta-markdown--gfm-slug (text)
  "GitHub-style anchor slug for heading TEXT.
Downcase, strip everything but alphanumerics/spaces/hyphens,
spaces become hyphens."
  (let* ((s (downcase (string-trim text)))
         (s (replace-regexp-in-string "[^[:alnum:][:space:]-]" "" s))
         (s (replace-regexp-in-string "[[:space:]]+" "-" s)))
    s))

(defun zetta-markdown-goto-anchor (anchor)
  "Jump to the heading matching ANCHOR (leading # optional).
Pushes the mark so jumping back works."
  (let ((target (if (string-prefix-p "#" anchor) (substring anchor 1) anchor))
        (found nil))
    (save-excursion
      (goto-char (point-min))
      (while (and (not found)
                  (re-search-forward "^#+[ \t]+\\(.*\\)" nil t))
        (when (string= target
                       (zetta-markdown--gfm-slug (match-string-no-properties 1)))
          (setq found (match-beginning 0)))))
    (unless found (user-error "No heading matches anchor #%s" target))
    (push-mark)
    (goto-char found)))

(defun zetta-markdown--browse-url-anchors (orig url)
  "Handle in-document #fragment URLs before ORIG sees them."
  (if (string-prefix-p "#" url)
      (zetta-markdown-goto-anchor url)
    (funcall orig url)))

;; markdown-mode is installed by elpaca as a dependency of markdown-toc;
;; configure it once it loads rather than queueing a duplicate order.
(with-eval-after-load 'markdown-mode
  (advice-add 'markdown-display-inline-images :before
              #'zetta-markdown--cap-inline-image-size)
  (advice-add 'markdown--browse-url :around
              #'zetta-markdown--browse-url-anchors)
  (general-define-key
   :keymaps 'markdown-mode-map
   "C-c v" #'zetta-markdown-pop-out-image
   "C-c C-x v" #'zetta-markdown-pop-out-image))
;;; markdown.el ends here
