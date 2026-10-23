;;; spot.el --- Configure spot -*- lexical-binding: t; -*-

(use-package spot
  :ensure (:host github :repo "chiply/spot")
  :commands (spot-authorize
             spot-refresh
             spot-consult-search
             spot-consult-search-current-user-playlists
             spot-consult-search-playlist-tracks
             spot-player-play
             spot-player-pause
             spot-player-next
             spot-player-previous
             spot-add-current-track-to-playlist
             spot-mode-line-string)
  :config
  ;; The 30 s mode-line poll was `url-retrieve-synchronously' -- a hard
  ;; main-loop block of 100-400 ms (10 s worst case) -- and nothing killed
  ;; the response buffer: 51 of 86 live buffers were " *http api.spotify.com*"
  ;; after 26 minutes, all marked on every GC (OPTIMIZATIONS.org).  Three
  ;; repairs, all overrides of package functions so they take effect on the
  ;; installed version; the proper home for each is chiply/spot itself.
  ;;
  ;; 1. Every remaining synchronous JSON fetch kills its response buffer.
  (defun zetta-spot--retrieve-url-to-alist-synchronously (url)
    "`spot-retrieve-url-to-alist-synchronously', releasing the buffer."
    (let ((buf (url-retrieve-synchronously url nil nil spot--request-timeout)))
      (when buf
        (unwind-protect
            (with-current-buffer buf
              (spot--report-response-error)
              (let ((json (decode-coding-region (+ 1 url-http-end-of-headers)
                                                (point-max) 'utf-8 t)))
                (unless (string= json "") (json-read-from-string json))))
          (kill-buffer buf)))))
  (advice-add 'spot-retrieve-url-to-alist-synchronously :override
              #'zetta-spot--retrieve-url-to-alist-synchronously)

  ;; 2. The poll itself goes through `url-retrieve': the main loop is never
  ;;    held, and the one-shot "track ends" timer is the only one kept in
  ;;    `spot--update-timers' (the original pushed a new one per poll and
  ;;    never dropped the dead ones).
  (defun zetta-spot--apply-currently-playing (alist)
    "Update the lighters from ALIST and schedule the track-end refresh."
    (let ((current (spot--alist-to-ht alist)))
      (spot--update-modeline-lighters current)
      (mapc #'cancel-timer spot--update-timers)
      (setq spot--update-timers nil)
      (when-let* ((progress (and current (ht-get current 'progress_ms)))
                  (item (ht-get current 'item))
                  (duration (ht-get item 'duration_ms))
                  (remaining (- duration progress))
                  (delay (max 0 remaining)))
        (push (run-with-timer (+ (/ delay 1000.0) 1.0) nil
                              #'spot--update-modeline-lighters nil)
              spot--update-timers))))
  (defun zetta-spot--check-for-modeline-update ()
    "Asynchronous `spot--check-for-modeline-update'."
    (let ((url-request-method "GET")
          (url-request-extra-headers (spot--auth-headers)))
      (url-retrieve
       (concat spot-player-url (spot--base-q-params))
       (lambda (status)
         (let ((buf (current-buffer)))
           (unwind-protect
               (unless (plist-get status :error)
                 (spot--report-response-error)
                 (let* ((json (and (bound-and-true-p url-http-end-of-headers)
                                   (decode-coding-region (+ 1 url-http-end-of-headers)
                                                         (point-max) 'utf-8 t)))
                        (alist (and json (not (string= json ""))
                                    (ignore-errors (json-read-from-string json)))))
                   (zetta-spot--apply-currently-playing alist)))
             (kill-buffer buf))))
       nil t t)))
  (advice-add 'spot--check-for-modeline-update :override
              #'zetta-spot--check-for-modeline-update)

  (spot-mode 1))

;;; spot.el ends here
