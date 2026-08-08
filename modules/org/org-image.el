;;; org-image.el --- Pop out and cap org inline images -*- lexical-binding: t; -*-

;; Mirrors the markdown image workflow for org documents:
;; - C-c v pops the image link at point into another window, fit to
;;   the window (C-u: fit to width; t in the image buffer toggles the
;;   fit axis).  Handles file:, attachment: and http(s) links.
;; - Inline previews (org-link-preview, C-c C-x C-v) are capped to
;;   `zetta-image-inline-height-fraction' of the frame height.
;; (C-c C-x v stays org-copy-visible; markdown-mode binds C-c v too.)

(declare-function org-element-context "org-element")
(declare-function org-attach-expand "org-attach")
(declare-function zetta-image--remote-file "image")
(declare-function zetta-image-pop-out-file "image")
(defvar zetta-image-inline-height-fraction)

(defun zetta-org--image-file-at-point ()
  "Return a local image file for the org link at point, or nil.
Remote images are downloaded into `zetta-image--remote-cache'."
  (let ((ctx (org-element-context)))
    (when (eq (org-element-type ctx) 'link)
      (let ((type (org-element-property :type ctx))
            (path (org-element-property :path ctx)))
        (cond
         ((equal type "file")
          (let ((f (expand-file-name path)))
            (and (file-exists-p f) f)))
         ((equal type "attachment")
          (require 'org-attach)
          (let ((f (ignore-errors (org-attach-expand path))))
            (and f (file-exists-p f) f)))
         ((member type '("http" "https"))
          (zetta-image--remote-file (concat type ":" path))))))))

(defun zetta-org-pop-out-image (&optional fit-width)
  "Display the org image link at point in another window.
See `zetta-image-pop-out-file' for the fit behavior; with prefix
argument FIT-WIDTH, fit to the window width."
  (interactive "P")
  (let ((file (zetta-org--image-file-at-point)))
    (unless file
      (user-error "No image link at point"))
    (zetta-image-pop-out-file file fit-width)))

(defun zetta-org--cap-inline-image (image)
  "Cap inline preview IMAGE to a fraction of the frame size.
Filter-return advice for `org--create-inline-image'; only adds the
max constraints when the spec doesn't set them itself."
  (when (and (consp image) (eq (car image) 'image))
    (let ((props (cdr image)))
      (unless (plist-member props :max-height)
        (nconc image (list :max-height
                           (truncate (* zetta-image-inline-height-fraction
                                        (frame-pixel-height))))))
      (unless (plist-member props :max-width)
        (nconc image (list :max-width (frame-pixel-width))))))
  image)

(with-eval-after-load 'org
  (advice-add 'org--create-inline-image :filter-return
              #'zetta-org--cap-inline-image)
  (general-define-key
   :keymaps 'org-mode-map
   "C-c v" #'zetta-org-pop-out-image))
;;; org-image.el ends here
