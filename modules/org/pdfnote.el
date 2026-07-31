;;; org/pdfnote.el --- Native PDF annotations -> Logseq notes -*- lexical-binding: t; -*-

;;; Commentary:
;; Thin loader for the `pdfnote' package (currently vendored under
;; `source/zettapkg/pdfnote/').  One-way sync: the native annotations
;; you make in a PDF -- typically highlights drawn on an iPad, which are
;; embedded in the PDF itself -- become an Org notes page in the Logseq
;; graph, each highlight backlinking to the source PDF.
;;
;; This is the missing half of `modules/org/pdf-tools.el', whose header
;; already states the intent: annotate natively, one-way sync PDF ->
;; notes.  Logseq's own highlighter can't consume these because it
;; stores highlights in an .edn sidecar rather than in the PDF.
;;
;; Commands: `pdfnote-sync-file', `pdfnote-sync-buffer',
;; `pdfnote-sync-all', `pdfnote-preview', `pdfnote-visit-notes'.

;;; Code:

(use-package pdfnote
  :ensure nil
  :load-path "source/zettapkg/pdfnote"
  :commands (pdfnote-sync-file pdfnote-sync-buffer pdfnote-sync-all
             pdfnote-preview pdfnote-visit-notes)
  :init
  ;; kb targeting (was the Logseq graph): PDFs live under ~/kb/pdf/
  ;; (domain subdirs); notes are a SIBLING <name>-annotations.org next
  ;; to each PDF — the same convention org-remark uses for kb files —
  ;; so pdf: links are same-dir relative and resolve against the note's
  ;; own directory.
  (setq pdfnote-file-prefix ""      ; logseq-era naming; dir context suffices
        pdfnote-assets-directory (expand-file-name "~/kb/pdf/")
        pdfnote-pages-directory  (expand-file-name "~/kb/pdf/")
        pdfnote-asset-link-directory "."
        pdfnote-page-file-function
        (lambda (pdf)
          (concat (file-name-sans-extension pdf) "-annotations.org")))
  ;; Register the `pdf:' backlink early (before the package is first
  ;; loaded) so those links are followable in any Org buffer; following
  ;; one autoloads the package on demand.
  (with-eval-after-load 'org
    (autoload 'pdfnote-follow-link "pdfnote" "Follow a pdf: Org link." nil)
    (org-link-set-parameters "pdf" :follow #'pdfnote-follow-link))
  ;; From a pdf-view buffer: sync its annotations / jump to its notes.
  (with-eval-after-load 'pdf-view
    (define-key pdf-view-mode-map (kbd "C-c C-n") #'pdfnote-sync-buffer)
    (define-key pdf-view-mode-map (kbd "C-c C-o") #'pdfnote-visit-notes)))

;;; org/pdfnote.el ends here
