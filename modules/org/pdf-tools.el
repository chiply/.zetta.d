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

;; this is the start of a more automated solution, but you lose the navigability that you get with org noter -- might not be a problem though if the pdf-tools annotation navigation is good,
;;(defun extract-pdf-annotations (pdf-file output-file)
     ;;"Extract annotations from PDF-FILE and save to OUTPUT-FILE."
     ;;(with-temp-buffer
       ;;(let ((annotations (pdf-info-getannots nil pdf-file)))
         ;;(with-temp-file output-file
           ;;(dolist (annot annotations)
             ;;(let ((content (cdr (assoc 'contents annot))))
               ;;(when content
                 ;;(insert (format "%s\n" content))))))))
     ;;(message "Annotations extracted to %s" output-file))
;;
   ;;;; Usage:
   ;;;; (extract-pdf-annotations "~/Downloads/patterns.pdf" "~/Downloads/patterns.txt")

;; actually, can use org-noter's skeleton function, it contains something that uses pdf-get-annots, would just need to customize this and create a bulk function out of it...  So can use interactively while in emacs to only pull annotations for the first time, then can run in bulk to refresh!  could look into making this part of a pdf save hook or something.
;;.

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
