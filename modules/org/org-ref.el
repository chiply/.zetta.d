(use-package org-ref
  :demand t
  :config
  (setq org-ref-insert-cite-function
        (lambda ()
          (org-cite-insert nil)))
  (require 'bibtex)

  (setq bibtex-completion-bibliography (list (expand-file-name "bibliography.bib" zetta-literature-dir))
        bibtex-completion-library-path (list (expand-file-name "pdf/" zetta-literature-dir))
        bibtex-completion-notes-path "~/org-roam/"
        org-ref-bibtex-pdf-download-dir "~/pdfs/"
        bibtex-completion-notes-template-multiple-files "* ${author-or-editor}, ${title}, ${journal}, (${year}) :${=type=}: \n\nSee [[cite:&${=key=}]]\n"

        bibtex-completion-additional-search-fields '(keywords)
        ;;bibtex-completion-display-formats
        ;;'((article       . "${=has-pdf=:1}${=has-note=:1} ${year:4} ${author:36} ${title:*} ${journal:40}")
        ;;(inbook        . "${=has-pdf=:1}${=has-note=:1} ${year:4} ${author:36} ${title:*} Chapter ${chapter:32}")
        ;;(incollection  . "${=has-pdf=:1}${=has-note=:1} ${year:4} ${author:36} ${title:*} ${booktitle:40}")
        ;;(inproceedings . "${=has-pdf=:1}${=has-note=:1} ${year:4} ${author:36} ${title:*} ${booktitle:40}")
        ;;(t             . "${=has-pdf=:1}${=has-note=:1} ${year:4} ${author:36} ${title:*}"))
        bibtex-completion-pdf-open-function 'find-file
        )

  (setq bibtex-autokey-year-length 4
        bibtex-autokey-name-year-separator "-"
        bibtex-autokey-year-title-separator "-"
        bibtex-autokey-titleword-separator "-"
        bibtex-autokey-titlewords 2
        bibtex-autokey-titlewords-stretch 1
        bibtex-autokey-titleword-length 5
        )

  ;;:general
  ;;(
   ;;:keymaps '(override)
   ;;"s-u" 'org-ref-bibtex-hydra/body
   ;;)
  )
