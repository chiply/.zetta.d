;;; pubmed.el --- Configure pubmed -*- lexical-binding: t; -*-

(use-package pubmed
  :ensure (:host gitlab :repo "fvdbeek/emacs-pubmed")

  :commands (pubmed-search pubmed-advanced-search)

  :config
  (setq pubmed-bibtex-default-file (expand-file-name "bibliography.bib" zetta-literature-dir))
  (setq pubmed-bibtex-keypattern "[auth][year][shorttitle]")
  (add-hook 'pubmed-mode-hook #'display-line-numbers-mode)
  (add-hook 'pubmed-show-mode-hook #'display-line-numbers-mode)

  ;; to fix bibtex not working
  ;;(load-file (expand-file-name "source/straight/repos/emacs-pubmed/pubmed-bibtex.el" user-emacs-directory) )

  (defun pubmed-extract-pmid ()
    "Extract the PMID from the current buffer."
    (interactive)
    (let ((pmid-regex "PMID:\\s-*\\([0-9]+\\)"))
      (save-excursion
        (goto-char (point-min))
        (if (re-search-forward pmid-regex nil t)
            (let ((pmid (match-string 1)))
              (message "Extracted PMID: %s" pmid)
              pmid)
          (message "PMID not found in the buffer")))))

  (defun pubmed-extract-title ()
    "Extract the title from the second line of the current buffer."
    (interactive)
    (let ((title nil))
      (save-excursion
        (goto-char (point-min))
        (forward-line 2)  ;; Move to the second line
        (setq title (thing-at-point 'line t)))  ;; Get the content of the line
      (if title
          (progn (message "Extracted Title: %s" (string-trim title))
                 title)
        (message "Title not found in the buffer."))))

  (defun pubmed-link-open (id _)
    (run-with-timer pubmed-entry-delay nil #'pubmed--show-entry id))

  (defun pubmed-link-store-link ()
    (when (eq major-mode 'pubmed-show-mode)
      (org-store-link-props
       :type "pubmed"
       :link (format "pubmed:%s" (pubmed-extract-pmid))
       :description (pubmed-extract-title))))

  (setq pubmed-base-url "https://pubmed.ncbi.nlm.nih.gov/40769122/")

  (defun pubmed-eww ()
    (interactive)
    (eww (concat pubmed-base-url (pubmed-extract-pmid))))

  (with-eval-after-load 'org
    (org-link-set-parameters
     "pubmed"
     :follow #'pubmed-link-open
     :store #'pubmed-link-store-link))

  :general
  (
   :keymaps 'pubmed-mode-map
   "C-<return>" 'pubmed-bibtex-write
   )
  (
   :keymaps 'menu-lookup-map
   "p" 'pubmed-search
   )
  )
;;; pubmed.el ends here
