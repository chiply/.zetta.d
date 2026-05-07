;;; consult-omni.el --- Configure consult-omni -*- lexical-binding: t; -*-

(use-package consult-omni
  :ensure (consult-omni
           :host github
           :repo "armindarvish/consult-omni"
           :files (:defaults "sources/*.el"))
  :after consult
  :config

  (setq consult-omni-show-preview t)
  (setq consult-omni-preview-key "C-=")
  (setq consult-omni-default-count 10)

  ;; use the same browse functions as the rest of the config
  (setq consult-omni-default-browse-function #'browse-url)
  (setq consult-omni-alternate-browse-function #'eww-browse-url)

  ;; group by source in multi searches
  (setq consult-omni-group-by :source)
  (setq consult-omni-highlight-matches-in-minibuffer t)
  (setq consult-omni-highlight-matches-in-file t)

  ;; consult-omni-buffer compatibility shim:
  ;; consult-omni-buffer.el references the old consult--source-* (double dash)
  ;; private API vars, but consult 2.x renamed them to consult-source-*
  ;; (single dash). We bridge with defvaralias so consult-omni-buffer can load.
  (dolist (name '(buffer modified-buffer hidden-buffer project-buffer
                  recent-file project-recent-file bookmark))
    (let ((old (intern (format "consult--source-%s" name)))
          (new (intern (format "consult-source-%s" name))))
      (unless (boundp old)
        (defvaralias old new))))

  ;; Fix upstream bug: consult-omni--get-split-style-character calls
  ;; (char-to-string nil) when the split style has no :initial key
  ;; (e.g. comma style only has :separator). The upstream `or` wrapping
  ;; doesn't help because char-to-string errors before or can short-circuit.
  ;; Must redefine here because consult-omni.el overwrites the fix in consult.el.
  (defun consult-omni--get-split-style-character (&optional style)
    
    "Get the character for consult async split STYLE.
STYLE defaults to `consult-async-split-style'."
    (let* ((style (or style consult-async-split-style 'none))
           (char (or (plist-get (alist-get style consult-async-split-styles-alist) :initial)
                     (plist-get (alist-get style consult-async-split-styles-alist) :separator))))
      (if char (char-to-string char) "")))

  ;; Fix upstream bug: consult-omni--highlight-format-candidate calls
  ;; (propertize title ...) without guarding for nil title.  Web sources
  ;; (e.g. Brave AutoSuggest) can return candidates with nil titles,
  ;; crashing in async process filter callbacks.
  (cl-defun consult-omni--highlight-format-candidate (&rest args &key source query url title snippet face &allow-other-keys)
    "Return a highlighted formatted string for candidates with ARGS."
    (let* ((frame-width-percent (floor (* (frame-width) 0.1)))
           (source (and (stringp source) (propertize source 'face 'consult-omni-source-type-face)))
           (match-str (and (stringp query) (not (equal query ".*")) (consult--split-escaped query)))
           (face (or (consult-omni--get-source-prop source :face) face 'consult-omni-default-face))
           (title (or title ""))
           (title-str (propertize title 'face face))
           (title-str (consult-omni--set-string-width title-str (* 4 frame-width-percent)))
           (snippet (and (stringp snippet) (consult-omni--set-string-width snippet (* 3 frame-width-percent))))
           (snippet (and (stringp snippet) (propertize snippet 'face 'consult-omni-snippet-face)))
           (urlobj (and url (url-generic-parse-url url)))
           (domain (and (url-p urlobj) (url-domain urlobj)))
           (domain (and (stringp domain) (propertize domain 'face 'consult-omni-domain-face)))
           (path (and (url-p urlobj) (url-filename urlobj)))
           (path (and (stringp path) (propertize path 'face 'consult-omni-path-face)))
           (url-str (consult-omni--set-url-width domain path (* frame-width-percent 2)))
           (str (concat title-str
                        (when url-str (concat "\s" url-str))
                        (when snippet (concat "\s\s" snippet))
                        (when source (concat "\t" source)))))
      (if consult-omni-highlight-matches-in-minibuffer
          (cond
           ((listp match-str)
            (mapc (lambda (match) (setq str (consult-omni--highlight-match match str t))) match-str))
           ((stringp match-str)
            (setq str (consult-omni--highlight-match match-str str t)))))
      str))

  (setq consult-omni-sources-modules-to-load
        `(consult-omni-buffer
          consult-omni-apps
          consult-omni-grep
          consult-omni-ripgrep
          consult-omni-projects
          consult-omni-dict
          consult-omni-calc
          consult-omni-man
          ;; web sources — API keys in ~/.private.el
          consult-omni-google
          consult-omni-brave
          consult-omni-brave-autosuggest
          consult-omni-youtube
          consult-omni-wikipedia
          consult-omni-stackoverflow
          ;; gptel source — requires gptel-backend to be set; we point
          ;; consult-omni at whichever backend gptel has configured
          ,@(when (featurep 'gptel) '(consult-omni-gptel))
          ;; PubMed module loaded for standalone M-x consult-omni-pubmed,
          ;; but excluded from consult-omni-web multi command.
          ;; Upstream bug: esummary async callback does unguarded
          ;; (gethash key data) where data is nil for UIDs missing from
          ;; the results hash.  The crash is inside the url-retrieve
          ;; process filter callback so it can't be caught with
          ;; condition-case around the caller.  Patching the function
          ;; didn't help — likely a second crash site in the esearch or
          ;; format-candidate path.  Revisit when upstream fixes land.
          consult-omni-pubmed))

  (require 'consult-omni-sources)
  (consult-omni-sources-load-modules)

  ;; Load gptel source lazily when gptel becomes available
  (with-eval-after-load 'gptel
    (unless (member 'consult-omni-gptel consult-omni-sources-modules-to-load)
      (add-to-list 'consult-omni-sources-modules-to-load 'consult-omni-gptel t)
      (require 'consult-omni-gptel nil t))
    ;; consult-omni-gptel's defcustom default `(or gptel-backend
    ;; gptel--openai)' is evaluated when consult-omni-gptel.el loads,
    ;; which can happen before user gptel config sets `gptel-backend'.
    ;; Re-sync after gptel loads so calls to (gptel-backend-name
    ;; consult-omni-gptel-backend) don't hit `wrong-type-argument
    ;; gptel-backend nil'.
    (when (and (boundp 'gptel-backend) gptel-backend)
      (setq consult-omni-gptel-backend gptel-backend))
    (when (and (boundp 'gptel-model) gptel-model)
      (setq consult-omni-gptel-model (format "%s" gptel-model))))

  ;; embark integration
  (require 'consult-omni-embark)

  ;; local multi — buffers, files, projects, tools

  (setq consult-omni-multi-sources
        '("Buffer"
          "Recent File"
          "Bookmark"
          "Apps"
          "ripgrep"
          "Projects"
          "Dictionary"
          "calc"
          "man"))


  ;; web multi — search engines, references, media
  (defun consult-omni-web ()
    "Multi-source web search via consult-omni."
    (interactive)
    (let ((consult-omni-multi-sources
           '("Google"
             "Brave"
             "Brave AutoSuggest"
             "YouTube"
             "Wikipedia"
             "StackOverflow"
             "gptel"
             ;; "PubMed" — excluded, see note in sources list above
             )))
      (consult-omni-multi)))

  (defun zetta-popup-omni-web ()
    "Run consult-omni-web in a popup frame."
    (interactive)
    (zetta-popup-frame-run #'consult-omni-web))

  (general-define-key
   :keymaps 'menu-lookup-map
   "o" 'consult-omni-multi
   "O" 'consult-omni-web))

;;; consult-omni.el ends here

