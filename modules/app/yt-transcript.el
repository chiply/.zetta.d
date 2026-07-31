;;; app/yt-transcript.el --- YouTube transcripts -> kb -*- lexical-binding: t; -*-

;;; Commentary:
;; `zetta-kb-save-yt-transcript': prompt for a YouTube URL, fetch its
;; transcript via yt-dlp (manual subtitles preferred, auto-captions as
;; fallback), and write an Org file of timestamp-linked lines into
;; ~/kb/yt-transcript/.  Returns the file path and takes the URL as a
;; plain argument, so it composes for bulk imports:
;;
;;   (dolist (u my-url-list) (zetta-kb-save-yt-transcript u))
;;
;; The json3 caption format is parsed directly (rather than VTT) because
;; auto-captions in VTT arrive as rolling duplicated windows; json3
;; events are clean per-caption lines.

;;; Code:

(require 'cl-lib)
(declare-function zetta-kb--sanitize-file-name "eww")

(defvar zetta-kb-yt-transcript-directory
  (expand-file-name "~/kb/yt-transcript/")
  "Root for YouTube transcripts saved into the synced kb tree.")

(defun zetta-kb--yt-video-json (url)
  "Return yt-dlp's metadata for URL as an alist."
  (unless (executable-find "yt-dlp")
    (user-error "yt-dlp not found — brew install yt-dlp"))
  (with-temp-buffer
    (let ((status (call-process "yt-dlp" nil (list t nil) nil
                                "--no-warnings" "--skip-download" "-J" url)))
      (unless (eq status 0)
        (user-error "yt-dlp failed (%s) for %s" status url)))
    (goto-char (point-min))
    (json-parse-buffer :object-type 'alist :array-type 'list)))

(defun zetta-kb--yt-caption-url (meta)
  "Return (JSON3-URL . KIND) for the best English track in META.
Manual subtitles win over auto-captions."
  (let ((pick (lambda (tracks kind)
                (cl-loop for (lang . fmts) in tracks
                         when (string-match-p "\\`en" (format "%s" lang))
                         return (cl-loop for fmt in fmts
                                         when (equal (alist-get 'ext fmt) "json3")
                                         return (cons (alist-get 'url fmt) kind))))))
    (or (funcall pick (alist-get 'subtitles meta) "subtitles")
        (funcall pick (alist-get 'automatic_captions meta) "auto-captions")
        (user-error "No English transcript available for this video"))))

(defun zetta-kb--yt-transcript-lines (caption-url)
  "Fetch CAPTION-URL (json3) and return a list of (SECONDS . TEXT)."
  (with-current-buffer (url-retrieve-synchronously caption-url t t 30)
    (goto-char (point-min))
    (re-search-forward "\n\n" nil t)    ; past HTTP headers
    (let* ((data (json-parse-buffer :object-type 'alist :array-type 'list))
           (events (alist-get 'events data))
           lines prev)
      (kill-buffer)
      (dolist (ev events)
        (let ((text (string-trim
                     (replace-regexp-in-string
                      "[ \t\n]+" " "
                      (mapconcat (lambda (s) (or (alist-get 'utf8 s) ""))
                                 (alist-get 'segs ev) "")))))
          (when (and (not (string-empty-p text))
                     (not (equal text prev)))  ; auto-caption echo guard
            (setq prev text)
            (push (cons (/ (or (alist-get 'tStartMs ev) 0) 1000) text)
                  lines))))
      (nreverse lines))))

(defun zetta-kb--yt-stamp (secs)
  "SECS as M:SS or H:MM:SS."
  (let ((h (/ secs 3600)) (m (/ (% secs 3600) 60)) (s (% secs 60)))
    (if (> h 0) (format "%d:%02d:%02d" h m s) (format "%d:%02d" m s))))

;;;###autoload
(defun zetta-kb-save-yt-transcript (url)
  "Fetch the transcript for the YouTube video at URL into kb.
Writes ~/kb/yt-transcript/<title>.org — one line per caption, each
timestamped with an org link that opens the video at that moment.
Interactively, prompts for URL.  Returns the file path, so bulk
imports are just a `dolist' over this function."
  (interactive (list (read-string "YouTube URL: ")))
  (let* ((meta (zetta-kb--yt-video-json url))
         (id (alist-get 'id meta))
         (title (or (alist-get 'title meta) id))
         (channel (or (alist-get 'uploader meta) (alist-get 'channel meta)))
         (canonical (format "https://youtu.be/%s" id))
         (cap (zetta-kb--yt-caption-url meta))
         (lines (zetta-kb--yt-transcript-lines (car cap)))
         (dir (file-name-as-directory zetta-kb-yt-transcript-directory))
         (target (expand-file-name
                  (concat (zetta-kb--sanitize-file-name title) ".org") dir)))
    ;; same title, different video -> disambiguate with the id
    (when (and (file-exists-p target)
               (not (with-temp-buffer
                      (insert-file-contents target nil 0 2000)
                      (search-forward id nil t))))
      (setq target (expand-file-name
                    (concat (zetta-kb--sanitize-file-name title)
                            " -- " id ".org")
                    dir)))
    (make-directory dir t)
    (with-temp-file target
      (insert "#+title: " title "\n")
      (when channel (insert "#+channel: " (format "%s" channel) "\n"))
      (insert "#+source: " canonical "\n"
              "#+transcript_kind: " (cdr cap) "\n"
              "#+filetags: :yt:transcript:\n\n")
      (dolist (l lines)
        (insert (format "[[%s?t=%d][%s]] %s\n"
                        canonical (car l) (zetta-kb--yt-stamp (car l))
                        (cdr l)))))
    (message "kb yt: %s (%d lines, %s)"
             (abbreviate-file-name target) (length lines) (cdr cap))
    target))

;;; app/yt-transcript.el ends here
