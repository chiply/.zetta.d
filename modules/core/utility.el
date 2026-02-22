;;; utility.el --- Configure utility functions -*- lexical-binding: t; -*-

(defun zetta-wget ()
  (interactive)
  (let ((dir "~/Downloads/")
        (url (eww-current-url)))
    ;; download the asset (pdf)
    (async-shell-command
     (concat "cd " dir " && " "wget " url))
    ;; add bibtex entry
    (org-ref-url-html-to-bibtex (expand-file-name "bibliography.bib" zetta-literature-dir) url)))

;; note!  embark act on links browses to them...

;; presumably get these from some interactive function

;; works reasonably well
(defun zetta-download-pdf ()
  (interactive)
  (let* ((url (eww-current-url))
         (title (read-from-minibuffer "Title: "))
         (key (downcase (replace-regexp-in-string " " "-" title)))
         )
    (async-shell-command (concat "cd ~/Downloads/ && wget " url))

    (progn
      (find-file (expand-file-name "bibliography.bib" zetta-literature-dir))
      (evil-goto-line)
      (insert
       "\n"
       (format "@online{%s,\n" key)
       (format "  title = {%s},\n" title)
       (format "  url = {%s},\n" url)
       "}\n\n"
       )
      (save-buffer)
      (backward-word)
      (kill-new url)
      (org-ref-open-bibtex-notes)
      )
    )
  ;; download pdf
  )

(defun append-to-zsh-history (command)
  (let ((timestamp (format-time-string "%s"))
        (hist-file (expand-file-name "~/.zsh_history")))
    (write-region
     (format ": %s:0;%s\n" timestamp command)
     nil hist-file t)))
;;; utility.el ends here
