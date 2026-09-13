;;; org-decorate.el --- AI decoration of the inbox -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <charliebkr707@gmail.com>
;; Maintainer: Charlie Holland <charliebkr707@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1") (org-ql "0.8") (gptel "0.9"))
;; Keywords: convenience, outlines

;; This file is not part of GNU Emacs.

;;; Commentary:

;; The command file.  `org-decorate-inbox' sends every undecorated inbox
;; entry to the model, one at a time, and writes what comes back as
;; AI_-prefixed properties through the queue's apply layer, so a
;; decoration is logged and undoable like any other write.  Then, in
;; the Inbox view or on the entry:
;;
;;   `org-decorate-accept'        every proposal becomes its real field, the
;;                                AI_ properties go, the entry is refiled;
;;                                one transaction, one undo
;;   `org-decorate-accept-field'  one proposed field
;;   `org-decorate-reject'        strip the proposals, stamp AI_REJECTED
;;   `org-decorate-edit'          jump to the entry with the proposals shown
;;
;; A correction -- a promoted value that differs from the proposal, or a
;; rejected field -- is appended to `org-decorate-corrections-file'.
;;
;; Also here: the duplicate check on capture (`DUPLICATE_OF'), and the
;; git reader that turns a commit naming an entry's ID into
;; `EVIDENCE_DONE', both offered in the Inbox view with the same keys.
;;
;; Which model: `org-decorate-backend', `local' by default (Ollama
;; through its OpenAI-compatible endpoint), `claude' by choice.  A
;; :private: entry is never sent.  Nothing here prompts; a failure is a
;; message and an AI_WHY line, never a partial write.

;;; Code:

(require 'cl-lib)
(require 'json)
(require 'org)
(require 'org-id)
(require 'org-ql)
(require 'org-decorate-core)
(require 'org-decorate-lists)
(require 'org-queue-harvest)
(require 'org-queue-apply)

(declare-function gptel-request "gptel-request")
(declare-function gptel-make-openai "gptel-openai")
(declare-function gptel-make-anthropic "gptel-anthropic")
(declare-function gptel-get-backend "gptel")
(declare-function irs--post "irs" (path payload then &optional else))
(declare-function irs-ensure-server "irs" (&optional callback))
(declare-function zetta-notify "alert" (message &optional title severity))
(declare-function org-capture-get "org-capture" (prop &optional local))
(defvar gptel-backend)
(defvar gptel-model)

(defcustom org-decorate-inbox-file "~/kb/inbox.org"
  "The inbox: where captures land and decoration reads."
  :type 'file
  :group 'org-decorate)

(defcustom org-decorate-backend 'local
  "Which model decorates: `local' (Ollama) or `claude'.
The inbox is personal; the local model keeps every entry on the
machine at the cost of precision.  Part 6 question 4 of composite.org."
  :type '(choice (const local) (const claude))
  :group 'org-decorate)

(defcustom org-decorate-local-model "qwen2.5:7b"
  "The Ollama model the local backend uses."
  :type 'string
  :group 'org-decorate)

(defcustom org-decorate-local-host "localhost:11434"
  "Where Ollama listens."
  :type 'string
  :group 'org-decorate)

(defcustom org-decorate-claude-model "claude-sonnet-5"
  "The model the Claude backend uses."
  :type 'string
  :group 'org-decorate)

(defcustom org-decorate-corrections-file
  (expand-file-name "org-decorate-corrections.el" user-emacs-directory)
  "Where corrections are appended: proposals a person overrode."
  :type 'file
  :group 'org-decorate)

(defcustom org-decorate-git-repos '("~/kb")
  "Repositories whose commit messages are read for entry IDs."
  :type '(repeat directory)
  :group 'org-decorate)

(defcustom org-decorate-git-days 30
  "How far back the git reader looks."
  :type 'integer
  :group 'org-decorate)

(defvar org-decorate-model-function nil
  "Function of (PROMPT SCHEMA CALLBACK) that asks the model.
CALLBACK receives the decoded proposal plist, or nil on failure.  Nil
means `org-decorate--ask-gptel'; tests bind a stub.")

(defvar org-decorate-neighbours-function nil
  "Function of (ENTRY CALLBACK) handing CALLBACK the irs neighbours.
Nil means `org-decorate--neighbours-irs'; tests bind a stub.")

(defvar org-decorate-schema
  '(:type "object"
    :properties (:kind (:type "string")
                 :keyword (:type "string")
                 :target (:type "string")
                 :category (:type "string")
                 :context (:type "string")
                 :energy (:type "string")
                 :tags (:type "array" :items (:type "string"))
                 :effort (:type "string")
                 :impact (:type "integer")
                 :impact_evidence (:type "string")
                 :scheduled_phrase (:type "string")
                 :deadline_phrase (:type "string")
                 :deadline_type (:type "string")
                 :timestamp_phrase (:type "string")
                 :waiting_on (:type "string")
                 :related (:type "array" :items (:type "string"))
                 :repo (:type "string")
                 :problem (:type "string")
                 :why (:type "string")
                 :confidence (:type "number")
                 :field_confidence (:type "object"))
    :required ["kind" "why" "confidence"])
  "The response schema, as gptel's plist form of JSON schema.")


;;;; The prompt

(defun org-decorate--prompt-file ()
  (expand-file-name "prompt.org" (file-name-directory (locate-library "org-decorate"))))

(defun org-decorate--system-prompt ()
  "Return the system prompt text from prompt.org, minus its keywords."
  (with-temp-buffer
    (insert-file-contents (org-decorate--prompt-file))
    (goto-char (point-min))
    (while (re-search-forward "^#\\+.*\n" nil t) (replace-match ""))
    (string-trim (buffer-string))))

(defun org-decorate--render-lists (lists)
  "Render LISTS for the model: compact enumerations."
  (concat
   (format "keywords: %s, none\n" (string-join (plist-get lists :keywords) ", "))
   (format "categories: %s\n" (string-join (plist-get lists :categories) ", "))
   (format "targets: %s\n" (string-join (plist-get lists :targets) ", "))
   (format "contexts: %s, none\n" (string-join (plist-get lists :contexts) ", "))
   (format "energies: %s, none\n" (string-join (plist-get lists :energies) ", "))
   (format "tags: %s\n" (string-join (plist-get lists :tags) ", "))
   (format "efforts: %s\n" (string-join (plist-get lists :efforts) ", "))
   (format "deadline types: %s\n" (string-join (plist-get lists :deadline-types) ", "))
   (when (plist-get lists :people)
     (format "people seen: %s\n" (string-join (plist-get lists :people) ", ")))
   (when (plist-get lists :wikiwords)
     (format "WikiWords with a page: %s\n" (string-join (plist-get lists :wikiwords) ", ")))
   (when (plist-get lists :problems)
     (format "favourite problems (name one in `problem' only when the note bears on it): %s\n"
             (string-join (plist-get lists :problems) " | ")))))

(defun org-decorate--user-prompt (entry lists neighbours)
  "Compose the request text for ENTRY."
  (concat
   "The lists:\n" (org-decorate--render-lists lists)
   "\nThe note:\n"
   (format "heading: %s\n" (plist-get entry :heading))
   (when (plist-get entry :state) (format "keyword already set: %s\n" (plist-get entry :state)))
   (when (plist-get entry :created)
     (format "written on: %s (%s)\n" (org-decorate-core--iso (plist-get entry :created))
             (format-time-string "%A" (encode-time 0 0 12 (% (plist-get entry :created) 100)
                                                    (% (/ (plist-get entry :created) 100) 100)
                                                    (/ (plist-get entry :created) 10000)))))
   (when (plist-get entry :backlink) (format "source link: %s\n" (plist-get entry :backlink)))
   (unless (string-empty-p (plist-get entry :body))
     (format "body:\n%s\n" (plist-get entry :body)))
   (when neighbours
     (concat "\nRelated material already in the notes (title, score):\n"
             (mapconcat (lambda (n) (format "- %s (%.2f)" (plist-get n :title)
                                            (or (plist-get n :score) 0.0)))
                        neighbours "\n")
             "\n"))))


;;;; The model

(defun org-decorate--backend ()
  "Return the gptel backend for `org-decorate-backend', making it once."
  (require 'gptel)
  (pcase org-decorate-backend
    ('claude (or (gptel-get-backend "Claude")
                 (user-error "No Claude backend is registered with gptel")))
    (_ (or (gptel-get-backend "Ollama-decorate")
           (gptel-make-openai "Ollama-decorate"
             :host org-decorate-local-host :protocol "http"
             :endpoint "/v1/chat/completions" :stream nil :key "ollama"
             :models (list (intern org-decorate-local-model)))))))

(defun org-decorate--model ()
  (intern (if (eq org-decorate-backend 'claude) org-decorate-claude-model org-decorate-local-model)))

(defun org-decorate--json-to-proposal (text)
  "Decode TEXT, the model's JSON, into a proposal plist, or nil."
  (when (stringp text)
    (let* ((start (string-match "{" text))
           (end (and start (cl-position ?} text :from-end t)))
           (json (and start end (substring text start (1+ end))))
           (data (and json (ignore-errors
                             (json-parse-string json :object-type 'alist :array-type 'list
                                                :null-object nil :false-object nil)))))
      (when data
        (let (plist)
          (dolist (cell data)
            (let ((key (intern (format ":%s" (car cell))))
                  (value (cdr cell)))
              (setq plist (plist-put plist key
                                     (if (eq key :field_confidence)
                                         (mapcar (lambda (c) (cons (car c) (float (cdr c)))) value)
                                       value)))))
          plist)))))

(defun org-decorate--ask-gptel (prompt schema callback)
  "Ask the configured backend PROMPT with SCHEMA; CALLBACK gets the proposal."
  (require 'gptel)
  (let ((gptel-backend (org-decorate--backend))
        (gptel-model (org-decorate--model)))
    (gptel-request prompt
      :system (org-decorate--system-prompt)
      :schema schema
      :callback (lambda (response _info)
                  (funcall callback (org-decorate--json-to-proposal response))))))

(defun org-decorate--ask (prompt callback)
  (funcall (or org-decorate-model-function #'org-decorate--ask-gptel)
           prompt org-decorate-schema callback))


;;;; Neighbours from irs

(defun org-decorate--neighbours-irs (entry callback)
  "Hand CALLBACK ENTRY's irs neighbours, or nil when irs is not there."
  (if (not (fboundp 'irs--post))
      (funcall callback nil)
    (condition-case nil
        (irs--post "/v1/search/hybrid"
                   `((query . ,(plist-get entry :heading)) (limit . 8))
                   (lambda (data)
                     (funcall callback
                              (mapcar (lambda (result)
                                        (list :title (or (alist-get 'title result)
                                                         (file-name-nondirectory
                                                          (or (alist-get 'path result) "")))
                                              :path (alist-get 'path result)
                                              :score (or (alist-get 'score result) 0.0)))
                                      (append (alist-get 'results data) nil))))
                   (lambda (_err) (funcall callback nil)))
      (error (funcall callback nil)))))

(defun org-decorate--neighbours (entry callback)
  (funcall (or org-decorate-neighbours-function #'org-decorate--neighbours-irs) entry callback))


;;;; Decorating one entry

(defun org-decorate--stamp ()
  (format "%s %s %s prompt=%d schema=%d"
          (format-time-string "[%Y-%m-%d %a %H:%M]")
          org-decorate-backend (org-decorate--model)
          org-decorate-prompt-version org-decorate-schema-version))

(defun org-decorate--task (entry)
  "Return ENTRY as the reference the apply layer locates."
  (list :id (plist-get entry :id) :file (plist-get entry :file)
        :title (plist-get entry :title) :point (plist-get entry :point)))

(defun org-decorate--write (entry writes note)
  "Write WRITES, an alist of (NAME . VALUE), on ENTRY through the apply layer."
  (org-queue-apply-actions
   (mapcar (lambda (cell)
             (list :action 'property :task (org-decorate--task entry)
                   :name (car cell) :value (cdr cell)))
           writes)
   note))

(defun org-decorate-entry (entry lists callback)
  "Decorate ENTRY against LISTS; CALLBACK gets the plan, an error plist, or nil.
Asynchronous: neighbours first, then the model, then the write."
  (cond
   ((plist-get entry :private) (funcall callback nil))
   ((not (org-decorate-core-stale-p entry)) (funcall callback nil))
   (t
    (org-decorate--neighbours
     entry
     (lambda (neighbours)
       (let* ((duplicate (org-decorate-core-duplicate entry neighbours))
              (related (org-decorate-core-related entry neighbours)))
         (org-decorate--ask
          (org-decorate--user-prompt entry lists related)
          (lambda (proposal)
            (let ((plan (org-decorate-core-plan
                         entry proposal lists (org-decorate--stamp)
                         #'org-decorate-resolve-date (org-queue-core-today))))
              (cond
               ((null plan) (funcall callback nil))
               ((plist-get plan :error)
                (org-decorate--write entry
                                     (list (cons "AI_WHY" (plist-get plan :error))
                                           (cons "AI_STAMP" (org-decorate--stamp)))
                                     "decoration failed")
                (funcall callback plan))
               (t
                (when duplicate
                  (push (cons "AI_DUPLICATE_OF"
                              (format "%s [%.2f]" (or (plist-get duplicate :path)
                                                      (plist-get duplicate :title))
                                      (plist-get duplicate :score)))
                        plan))
                (when (and related (not (assoc "AI_RELATED" plan)))
                  (push (cons "AI_RELATED"
                              (mapconcat (lambda (n)
                                           (format "[[file:%s]] [%.2f]" (plist-get n :path)
                                                   (plist-get n :score)))
                                         (seq-take (cl-remove-if-not (lambda (n) (plist-get n :path))
                                                                     related)
                                                   3)
                                         " "))
                        plan))
                (org-decorate--write entry plan "decorated")
                (funcall callback plan))))))))))))

(defun org-decorate--entries (file &optional all)
  "Return the entries of FILE that need decorating, or ALL of them."
  (with-current-buffer (find-file-noselect (expand-file-name file))
    (org-with-wide-buffer
     (let (entries)
       (org-map-entries
        (lambda ()
          (when (= 1 (org-current-level))
            ;; An ID so the reply, which arrives after the inbox may have
            ;; changed, can find its entry again.
            (org-id-get-create)
            (let ((entry (org-decorate-entry-at-point)))
              (when (or all (and (not (plist-get entry :private))
                                 (org-decorate-core-stale-p entry)))
                (push entry entries)))))
        nil 'file)
       (when (buffer-modified-p) (save-buffer))
       (nreverse entries)))))

;;;###autoload
(defun org-decorate-inbox (&optional file)
  "Decorate every undecorated entry in FILE (default the inbox), one at a time."
  (interactive)
  (let* ((file (or file org-decorate-inbox-file))
         (entries (org-decorate--entries file))
         (lists (org-decorate-lists))
         (total (length entries))
         (done 0) (failed 0))
    (if (null entries)
        (message "Nothing to decorate in %s" (file-name-nondirectory file))
      (message "Decorating %d entr%s with %s..." total (if (= 1 total) "y" "ies")
               org-decorate-backend)
      (cl-labels ((next ()
                    (if (null entries)
                        (let ((text (format "Decorated %d of %d%s" done total
                                            (if (> failed 0) (format ", %d failed" failed) ""))))
                          (message "%s" text)
                          (when (fboundp 'zetta-notify) (zetta-notify text "Inbox")))
                      (let ((entry (pop entries)))
                        (org-decorate-entry
                         entry lists
                         (lambda (plan)
                           (cond ((null plan) nil)
                                 ((plist-get plan :error) (cl-incf failed))
                                 (t (cl-incf done)))
                           (next)))))))
        (next)))))

;;;###autoload
(defun org-decorate-this ()
  "Decorate the entry at point."
  (interactive)
  (org-id-get-create)
  (save-buffer)
  (let ((entry (org-decorate-entry-at-point)))
    (org-decorate-entry entry (org-decorate-lists)
                        (lambda (plan)
                          (message "%s" (cond ((null plan) "Nothing to decorate")
                                              ((plist-get plan :error) (plist-get plan :error))
                                              (t (format "Decorated: %s"
                                                         (cdr (assoc "AI_WHY" plan))))))))))


;;;; The confirm gesture

(defun org-decorate--corrections-append (records)
  "Append RECORDS to the corrections file."
  (when records
    (make-directory (file-name-directory org-decorate-corrections-file) t)
    (with-temp-buffer
      (when (file-readable-p org-decorate-corrections-file)
        (insert-file-contents org-decorate-corrections-file))
      (goto-char (point-max))
      (let ((print-length nil) (print-level nil)
            (stamp (format-time-string "[%Y-%m-%d %a %H:%M]")))
        (dolist (record records)
          (prin1 (append record (list :stamp stamp)) (current-buffer))
          (insert "\n")))
      (write-region (point-min) (point-max) org-decorate-corrections-file))))

(defun org-decorate--entry-here ()
  "Return the entry at point, in an agenda or an Org buffer."
  (cond
   ((derived-mode-p 'org-agenda-mode)
    (let ((marker (or (org-get-at-bol 'org-hd-marker) (org-get-at-bol 'org-marker))))
      (unless marker (user-error "No entry on this line"))
      (with-current-buffer (marker-buffer marker)
        (org-with-wide-buffer
         (goto-char marker)
         (org-decorate-entry-at-point)))))
   ((derived-mode-p 'org-mode) (org-decorate-entry-at-point))
   (t (user-error "Not on an entry"))))

(defun org-decorate--after ()
  "Redraw an agenda after a write."
  (when (derived-mode-p 'org-agenda-mode)
    (org-agenda-redo)))

(defun org-decorate--proposed-names (entry)
  (cl-remove-if-not (lambda (name) (org-decorate-core-property entry name))
                    '("AI_KEYWORD" "AI_TARGET" "AI_CONTEXT" "AI_ENERGY" "AI_TAGS" "AI_EFFORT"
                      "AI_IMPACT" "AI_SCHEDULED" "AI_DEADLINE" "AI_TIMESTAMP" "AI_WAITING_ON"
                      "AI_RELATED")))

;;;###autoload
(defun org-decorate-accept (&optional fields)
  "Promote the entry's proposals to real fields, strip them, refile.
With FIELDS, a list of AI_ names, only those; the rest count as
corrections.  One apply, one undo."
  (interactive)
  (let* ((entry (org-decorate--entry-here))
         (actions (org-decorate-core-accept-actions entry fields))
         (evidence (org-decorate-core-property entry "EVIDENCE_DONE")))
    (when (and evidence (null (org-decorate--proposed-names entry)))
      ;; Commit evidence with nothing else proposed: accepting marks DONE.
      (setq actions (list (list :action 'state :to "DONE"))))
    (unless actions (user-error "Nothing proposed on %s" (plist-get entry :title)))
    (when fields
      (org-decorate--corrections-append
       (mapcar (lambda (name)
                 (list :hash (org-decorate-core-property entry "AI_HASH") :field name
                       :proposed (org-decorate-core-property entry name) :corrected nil
                       :prompt org-decorate-prompt-version))
               (cl-set-difference (org-decorate--proposed-names entry) fields :test #'equal))))
    (org-queue-apply-actions
     (mapcar (lambda (action) (plist-put action :task (org-decorate--task entry))) actions)
     (if fields (format "accepted %s" (string-join fields " ")) "accepted the decoration"))
    (org-decorate--after)
    (message "%s: %d change%s.  ,-o-u undoes them" (plist-get entry :title)
             (length actions) (if (= 1 (length actions)) "" "s"))))

;;;###autoload
(defun org-decorate-accept-field ()
  "Promote one proposed field, chosen by completion."
  (interactive)
  (let* ((entry (org-decorate--entry-here))
         (names (or (org-decorate--proposed-names entry)
                    (user-error "Nothing proposed on %s" (plist-get entry :title))))
         (name (completing-read "Accept: "
                                (mapcar (lambda (n) (format "%s = %s" n (org-decorate-core-property entry n)))
                                        names)
                                nil t)))
    (org-decorate-accept (list (car (split-string name " = "))))))

;;;###autoload
(defun org-decorate-reject ()
  "Strip the proposals and stamp AI_REJECTED, so this prompt does not re-propose."
  (interactive)
  (let* ((entry (org-decorate--entry-here))
         (strip (org-decorate-core-strip-actions entry)))
    (unless strip (user-error "Nothing proposed on %s" (plist-get entry :title)))
    (org-decorate--corrections-append
     (mapcar (lambda (name)
               (list :hash (org-decorate-core-property entry "AI_HASH") :field name
                     :proposed (org-decorate-core-property entry name) :corrected nil
                     :prompt org-decorate-prompt-version))
             (org-decorate--proposed-names entry)))
    (org-queue-apply-actions
     (mapcar (lambda (action) (plist-put action :task (org-decorate--task entry)))
             (append strip
                     (list (list :action 'property :name "AI_REJECTED"
                                 :value (format "%s prompt=%d"
                                                (format-time-string "[%Y-%m-%d %a %H:%M]")
                                                org-decorate-prompt-version)))))
     "rejected the decoration")
    (org-decorate--after)
    (message "%s: proposals removed" (plist-get entry :title))))

;;;###autoload
(defun org-decorate-edit ()
  "Jump to the entry with its proposals in the echo area, to edit by hand."
  (interactive)
  (let ((entry (org-decorate--entry-here)))
    (when (derived-mode-p 'org-agenda-mode) (org-agenda-goto))
    (message "%s" (mapconcat (lambda (name)
                               (format "%s %s" (substring name 3)
                                       (org-decorate-core-property entry name)))
                             (org-decorate--proposed-names entry) "  "))))

;;;###autoload
(defun org-decorate-strip-all (&optional file)
  "Remove every AI_ property from every entry in FILE (default the inbox)."
  (interactive)
  (let ((actions
         (apply #'append
                (mapcar (lambda (entry)
                          (mapcar (lambda (action) (plist-put action :task (org-decorate--task entry)))
                                  (org-decorate-core-strip-actions entry)))
                        (org-decorate--entries (or file org-decorate-inbox-file) t)))))
    (if actions
        (org-queue-apply-actions actions "stripped every decoration")
      (message "Nothing to strip"))))


;;;; Duplicates on capture

(defvar org-decorate--captured nil
  "The ID of the entry the last capture finalised, for the duplicate check.")

(defun org-decorate--note-capture ()
  "Remember the captured entry's ID (creating one) before finalize."
  (when (and (derived-mode-p 'org-mode)
             (not (equal (org-capture-get :key) "j")))
    (save-excursion
      (goto-char (point-min))
      (when (re-search-forward "^\\*+ " nil t)
        (setq org-decorate--captured (org-id-get-create))))))

(defun org-decorate--local-neighbours (entry)
  "Return the harvest's entries as neighbours, scored by normalised title."
  (let ((title (org-decorate-core-normalise (plist-get entry :heading))))
    (delq nil
          (mapcar (lambda (task)
                    (unless (equal (plist-get task :id) (plist-get entry :id))
                      (list :id (plist-get task :id) :title (plist-get task :title)
                            :done (and (org-queue-core-done-p task) t)
                            :score (if (equal title (org-decorate-core-normalise
                                                     (plist-get task :title)))
                                       1.0 0.0))))
                  (org-queue-harvest)))))

(defun org-decorate--find-id (id)
  "Return a marker for the entry ID: org-id first, then the inbox and the files."
  (or (ignore-errors (org-id-find id t))
      (cl-some (lambda (file)
                 (when (file-readable-p (expand-file-name file))
                   (with-current-buffer (find-file-noselect (expand-file-name file))
                     (org-with-wide-buffer
                      (goto-char (point-min))
                      (when (re-search-forward (concat "^[ \t]*:ID:[ \t]+" (regexp-quote id) "[ \t]*$")
                                               nil t)
                        (org-back-to-heading t)
                        (point-marker))))))
               (cons org-decorate-inbox-file (org-decorate--files)))))

(defun org-decorate-check-duplicate (&optional id)
  "Write DUPLICATE_OF on the entry ID when an open entry already says the same."
  (when-let* ((id (or id org-decorate--captured))
              (marker (org-decorate--find-id id)))
    (setq org-decorate--captured nil)
    (with-current-buffer (marker-buffer marker)
      (org-with-wide-buffer
       (goto-char marker)
       (let* ((entry (org-decorate-entry-at-point))
              (duplicate (org-decorate-core-duplicate entry (org-decorate--local-neighbours entry))))
         (when (and duplicate (not (org-decorate-core-property entry "DUPLICATE_OF")))
           (org-queue-apply-actions
            (list (list :action 'property :task (org-decorate--task entry)
                        :name "DUPLICATE_OF" :value (plist-get duplicate :id)))
            "captured before")
           duplicate))))))

(defun org-decorate--after-capture ()
  "Run the duplicate check after a capture, without blocking it."
  (when org-decorate--captured
    (run-with-idle-timer 1 nil #'org-decorate-check-duplicate)))

;;;###autoload
(defun org-decorate-enable-capture-hooks ()
  "Check every capture for a duplicate."
  (add-hook 'org-capture-before-finalize-hook #'org-decorate--note-capture)
  (add-hook 'org-capture-after-finalize-hook #'org-decorate--after-capture))


;;;; Commits as evidence of DONE

(defun org-decorate-git-commits (repo &optional since)
  "Return the commits of REPO since SINCE as plists (:sha :message :time).
SINCE is a number of days, or a string git's --since reads (\"@EPOCH\")."
  (let ((default-directory (expand-file-name repo))
        (since (cond ((null since) (format "%d.days" org-decorate-git-days))
                     ((numberp since) (format "%d.days" since))
                     (t since))))
    (when (file-directory-p (expand-file-name ".git"))
      (with-temp-buffer
        (when (zerop (ignore-errors
                       (call-process "git" nil t nil "log"
                                     (format "--since=%s" since)
                                     "--format=%H%x1f%at%x1f%B%x1e")))
          (delq nil
                (mapcar (lambda (record)
                          (let ((fields (split-string record "\x1f")))
                            (when (= 3 (length fields))
                              (list :sha (string-trim (nth 0 fields))
                                    :time (string-to-number (nth 1 fields))
                                    :message (string-trim (nth 2 fields))
                                    :repo repo))))
                        (split-string (buffer-string) "\x1e" t "[ \t\n]+"))))))))

(defun org-decorate-git-all-commits (&optional since)
  "Return the commits of every repository in `org-decorate-git-repos'."
  (apply #'append (mapcar (lambda (repo) (org-decorate-git-commits repo since))
                          org-decorate-git-repos)))

;;;###autoload
(defun org-decorate-git-evidence (&optional days)
  "Write EVIDENCE_DONE on open entries whose ID a recent commit names.
Idempotent: an entry already carrying the property is left alone."
  (interactive)
  (let* ((tasks (cl-remove-if (lambda (task) (or (org-queue-core-done-p task)
                                                 (null (plist-get task :id))))
                              (org-queue-harvest)))
         (evidence (org-decorate-core-commit-evidence
                    (org-decorate-git-all-commits days)
                    (mapcar (lambda (task) (plist-get task :id)) tasks)))
         (actions
          (delq nil
                (mapcar (lambda (cell)
                          (let ((task (cl-find (car cell) tasks
                                               :key (lambda (task) (plist-get task :id))
                                               :test #'equal)))
                            (when task
                              (list :action 'property :task task
                                    :name "EVIDENCE_DONE" :value (cdr cell)))))
                        evidence))))
    (if actions
        (progn (org-queue-apply-actions actions "commit evidence")
               (message "%d entr%s with commit evidence" (length actions)
                        (if (= 1 (length actions)) "y" "ies")))
      (message "No commit names an open entry"))
    evidence))

(defun org-decorate-git-day-events (_date day-start day-end)
  "Return the commits between DAY-START and DAY-END as day-log events."
  (delq nil
        (mapcar (lambda (commit)
                  (when (and (>= (plist-get commit :time) day-start)
                             (< (plist-get commit :time) day-end))
                    (list :time (plist-get commit :time) :kind 'commit
                          :title (format "%s: %s" (file-name-nondirectory
                                                   (directory-file-name (plist-get commit :repo)))
                                         (car (split-string (plist-get commit :message) "\n")))
                          :id (plist-get commit :sha))))
                (org-decorate-git-all-commits (format "@%d" day-start)))))

(provide 'org-decorate)
;;; org-decorate.el ends here
