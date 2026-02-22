;;; pdf-tools.el --- Configure pdf-tools -*- lexical-binding: t; -*-

;; org-pdftools and org-noter-pdftools are too buggy - they interfere
;; with org noter, prevents from being a able to create a skeleton.
;; also requires lots of patching to simply make annotations
;; work. although org-noter-pdf tools offers a buffer->pdf sync
;; option, it is buggy and also append only, so creates redundant
;; garbage in the PDF's native annotations.

;; key understanding is that annotations should be PDF native as so
;; they can be rendered on an iPad (which is where I do most of my
;; annotating), one-way sync from PDF to notes buffer should be supported

;; org-noter has a create skeleton function, but it doesn't replace
;; the old skeleton, and is difficult to use in bulk.

(use-package pdf-tools
  :init
  (pdf-loader-install :no-query)
  :config
  (add-hook 'pdf-view-mode-hook 'pdf-view-fit-height-to-window)

  :general
  (
   :keymaps '(pdf-view-mode-map)
   "C-S-j" 'pdf-view-next-page
   "C-S-k" 'pdf-view-previous-page))

(use-package org-noter
  :config
  (setq org-noter-always-create-frame nil)
  (setq org-noter-kill-frame-at-session-end nil)
  (setq org-noter-highlight-selected-text t)
  (setq org-noter-notes-search-path '("~/pdfnotes")))
;;; pdf-tools.el ends here
