(use-package origami)

;; basic tweaks and bindings
(setenv "BROWSER" "chrome")

;; ob-restclient and ob-http alternatives
(use-package verb
  :after org
  :config
  (define-key org-mode-map (kbd "C-c C-r") verb-command-map)
  (org-babel-do-load-languages
   'org-babel-load-languages
   '((python . t) (emacs-lisp . t) (sql . t) (C . t) (sqlite . t)
     (js . t) (ditaa . t) (dot . t) (shell . t ) (latex . t )
     (verb . t)))
  )


;; by default, make inline images look like thumbnails.  If using
;; actual width of the image, then it takes up too much space in the
;; buffer
;;(setq org-image-actual-width 200)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; Flow / tasks
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;  Super Agenda


;; export backends
;;(require 'ox-beamer)
(use-package epresent)
(use-package ox-reveal
  :config
  (setq org-reveal-root "https://cdnjs.cloudflare.com/ajax/libs/reveal.js/3.6.0/"
        org-reveal-mathjax t))
(use-package htmlize )
(use-package ox-jekyll-md)

;; from the docs
;; "To stop Org from evaluating code blocks to speed exports, use the
;; header argument ‘:eval never-export’ (see Evaluating Code
;; Blocks). To stop Org from evaluating code blocks for greater
;; security, set the org-export-use-babel variable to nil, but
;; understand that header arguments will have no effect."
;; NOTE setting this to nil causes issues.  when dealing with an org
;; document and hot exporting, you can increase efficiency by
;; narrowing the buffer
(setq org-export-use-babel t)

;; convenient super bindinigs for organization
(setq zetta-captured-from-win "")

(general-define-key 
 :kemaps 'override
 "s-t" '(lambda () (interactive)
          (setq zetta-captured-from-win (selected-window))
          (org-capture nil "h")
          (org-set-property "received" (format-time-string "%Y-%m-%d %a %H:%M"))
          (org-id-get-create)
          )
 "s-T" '(lambda () (interactive)
          (setq zetta-captured-from-win (selected-window))
          (org-capture nil "H")
          (org-set-property "received" (format-time-string "%Y-%m-%d %a %H:%M"))
          (org-id-get-create)
          )
 )

;; note order matters here as there is overlap between org
;; roam and org-mode (org-roam is in org mode, but it matches
;; for this first, so it displays in slot 2, not slot 1)
;;(zetta-side "^\\*org-roa*" 'right 2 0.20 0.30)


;;;;;;;;;;;;;;;;; Literature management
;;(zetta-side "bibliography.bib" 'right 2 0.30)

(setq org-ref-insert-link-function 'org-ref-insert-link-hydra/body
      org-ref-insert-label-function 'org-ref-insert-label-link
      org-ref-insert-ref-function 'org-ref-insert-ref-link
      org-ref-cite-onclick-function (lambda (_) (org-ref-citation-hydra/body)))


(defun gpc/open-node-roam-ref-url ()
  "Open the URL in this node's ROAM_REFS property, if one exists"
  (interactive)
  (when-let ((ref-url (org-entry-get-with-inheritance "ROAM_REFS")))
    (browse-url ref-url)))


(defun gpc/open-node-roam-ref-url-eww ()
  "Open the URL in this node's ROAM_REFS property, if one exists"
  (interactive)
  (when-let ((ref-url (org-entry-get-with-inheritance "ROAM_REFS")))
    (eww-browse-url ref-url)))


;;(add-hook 'org-mode-hook (lambda () (font-lock-add-keywords
;;nil
;;'(("^-\\{5,\\}"  0 '(:foreground "red" :weight bold))))))

;;(remove-hook 'org-mode-hook (lambda () (undo-tree-mode 1)))

(setq org-id-link-to-org-use-id t)

(setq org-time-stamp-formats
      '("<%Y-%m-%d %a>" . "<%Y-%m-%d %a %H:%M:%S>"))


(use-package ox
  :ensure nil
  :demand t
  :config
  ;; Load ox-md first so we can derive from 'md backend
  (require 'ox-md)
  ;; fropm https://emacs.stackexchange.com/questions/42471/how-to-export-markdown-from-org-mode-with-syntax
  (org-export-define-derived-backend 'mymd 'md
    :menu-entry
    '(?y "Export to My Markdown"
         ((?M "To temporary buffer"
              (lambda (a s v b) (org-mymd-export-as-markdown a s v)))
          (?m "To file" (lambda (a s v b) (org-mymd-export-to-markdown a s v)))
          (?o "To file and open"
              (lambda (a s v b)
                (if a (org-mymd-export-to-markdown t s v)
                  (org-open-file (org-mymd-export-to-markdown nil s v)))))))
    :translate-alist '((example-block . org-mymd-example-block)
                       (fixed-width . org-mymd-example-block)
                       (src-block . org-mymd-example-block)))

  (defun org-mymd-example-block (example-block _content info)
    "Transcode element EXAMPLE-BLOCK as ```lang ...'''."
    (format "```%s\n%s\n```"
            (org-element-property :language example-block)
            (org-remove-indentation
             (org-export-format-code-default example-block info))))

;;;###autoload
  (defun org-mymd-export-as-markdown (&optional async subtreep visible-only)
    "See `org-md-export-as-markdown'."
    (interactive)
    (org-export-to-buffer 'mymd "*Org My MD Export*"
      async subtreep visible-only nil nil (lambda () (text-mode))))

;;;###autoload
  (defun org-mymd-convert-region-to-md ()
    "See `org-md-convert-region-to-md'."
    (interactive)
    (org-export-replace-region-by 'mymd))

;;;###autoload
  (defun org-mymd-export-to-markdown (&optional async subtreep visible-only)
    "See `org-md-export-to-markdown'."
    (interactive)
    (let ((outfile (org-export-output-file-name ".md" subtreep)))
      (org-export-to-file 'mymd outfile async subtreep visible-only)))

;;;###autoload
  (defun org-mymd-publish-to-md (plist filename pub-dir)
    "Analogous to `org-md-publish-to-md'."
    (org-publish-org-to 'mymd filename ".md" plist pub-dir))

  (setq org-pandoc-options-for-markdown '((wrap . none)))

  )






(defun org-babel-tangle--unbracketed-link (params)
  "Get a raw link to the src block at point, without brackets.

The PARAMS are the 3rd element of the info for the same src block."
  (unless (string= "no" (cdr (assq :comments params)))
    (save-match-data
      (let* (;; The created link is transient.  Using ID is not necessary,
             ;; but could have side-effects if used.  An ID property may
             ;; be added to existing entries thus creating unexpected file
             ;; modifications.
             ;; CHANGED
             ;;(org-id-link-to-org-use-id nil)
             (l (org-no-properties
                 (cl-letf (((symbol-function 'org-store-link-functions)
                            (lambda () nil)))
                   (org-store-link nil))))
             (bare (and (string-match org-link-bracket-re l)
                        (match-string 1 l))))
        (when bare
          (if (and org-babel-tangle-use-relative-file-links
                   (string-match org-link-types-re bare)
                   (string= (match-string 1 bare) "file"))
              (concat "file:"
                      (file-relative-name (substring bare (match-end 0))
                                          (file-name-directory
                                           (cdr (assq :tangle params)))))
            bare))))))

;; needed by my blog
(defun org-add-custom-ids ()
  "Add CUSTOM_ID properties to each heading in the current Org buffer."
  (interactive)
  (save-excursion
    (goto-char (point-min))
    (while (re-search-forward org-heading-regexp nil t)
      (let* ((heading (org-get-heading t t t t))
             (custom-id (replace-regexp-in-string
                         "[^a-zA-Z0-9_-]" "-"
                         (downcase heading)))
             (existing-id (org-entry-get nil "CUSTOM_ID")))
        (org-set-property "CUSTOM_ID" custom-id)))))




(defvar my-org-treemap-temp-file "~/treemap.html") ; Firefox inside Snap can't access /tmp
(defvar my-org-treemap-command "treemap" "Executable to generate a treemap.")

(defun my-org-treemap-include-p (node)
  (not (or (member "notree" (org-element-property :tags node))
           (org-element-property-inherited :archivedp node 'with-self))))

(defun my-org-treemap--node-label (node)
  "Return heading title with CUSTOM_ID appended if present."
  (let ((title (org-no-properties (org-element-property :raw-value node)))
        (cid   (org-element-property :CUSTOM_ID node)))
    (if cid
        (format "%s" cid)
      title)))

(defun my-org-treemap-data (node &optional path)
  "Output the size of headings underneath this one."
  (let ((sub
         (apply
          'append
          (org-element-map
              (org-element-contents node)
              '(headline)
            (lambda (child)
              (if (my-org-treemap-include-p child)
                  (my-org-treemap-data
                   child
                   (append path (list (my-org-treemap--node-label node))))
                (list
                 (list
                  (-
                   (org-element-end child)
                   (org-element-begin child))
                  (string-join
                   (cdr
                    (append path
                            (list
                             (my-org-treemap--node-label node)
                             (my-org-treemap--node-label child))))
                   "/")
                  nil))))
            nil nil 'headline))))
    (append
     (list
      (list
       (-
        (org-element-end node)
        (org-element-begin node)
        (apply '+ (mapcar 'car sub))
        )
       (string-join
        (cdr
         (append path
                 (list (my-org-treemap--node-label node))))
        "/")
       (my-org-treemap-include-p node)))
     sub)))

(defun my-org-treemap ()
  "Generate a treemap."
  (interactive)
  (save-excursion
    (goto-char (point-min))
    (let ((file (expand-file-name (expand-file-name my-org-treemap-temp-file)))
          (data (cdr (my-org-treemap-data (org-element-parse-buffer)))))
      (with-temp-file file
        (call-process-region
         (mapconcat
          (lambda (entry)
            (if (elt entry 2)
                (format "%d %s\n" (car entry)
                        (replace-regexp-in-string org-link-bracket-re "\\2" (cadr entry)))
              ""))
          data
          "")
         nil
         my-org-treemap-command nil t t))
      (browse-url (concat "file://" (expand-file-name my-org-treemap-temp-file))))))

;; for blog
(setq org-use-sub-superscripts '{})
(setq org-export-with-sub-superscripts nil)

(setq org-html-with-latex 'mathjax)
