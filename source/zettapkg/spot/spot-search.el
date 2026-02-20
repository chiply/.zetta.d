;;; -*- lexical-binding: t; -*-

(require 'ht)

(require 'spot-util)
(require 'spot-var)


;; Mutex and cache
(defvar spot--mutex (make-mutex)
  "A mutex to ensure that only one search request is made at a time.")
(defvar spot--cache (ht-create)
  "A cache to store search results for reuse.")

;; Candidate lists (these get set by the request function)
(defvar spot--candidates-album '())
(defvar spot--candidates-artist '())
(defvar spot--candidates-playlist '())
(defvar spot--candidates-track '())
(defvar spot--candidates-show '())
(defvar spot--candidates-episode '())
(defvar spot--candidates-audiobook '())

(defun spot--parse-command (input)
  "Parse the input command string into a query and arguments."
  (if (string-match "\\(.*?\\)\\s-+--\\s-+\\(.*\\)" input)
      (let* ((query (match-string 1 input))
             (args-str (match-string 2 input))
             (args (mapcar
                    (lambda (arg)
                      (when (string-match
                             "\\(?:--\\)?\\([^=]+\\)=\\(.*\\)" arg)
                        (cons (match-string 1 arg)
                              (match-string 2 arg))))
                    (split-string args-str))))
        (list query (delq nil args)))
    (list input nil)))


(defun spot--transform-alist-to-q-params (alist)
  "Transform an alist into a query string for URL parameters."
  (mapconcat
   'identity
   (-map (lambda (x) (concat "&" (car x) "=" (cdr x))) (car alist))))


(defun spot--search-items (input)
  "Search for items on Spotify based on the input."
  (let* ((parsed-command (spot--parse-command input))
         (query (car parsed-command))
         (args (cdr parsed-command))
         (args (spot--transform-alist-to-q-params args))
         (q-params (concat
                    (spot--base-q-params)
                    args
                    "&type=" "album," "artist,"
                    "playlist," "track," "show," "episode,"
                    "audiobook"
                    "&q=" query))
         (alist (spot-request
                 :method "GET"
                 :url spot-search-url
                 :q-params q-params
                 :parse-json t)))
    (spot--alist-to-ht alist)))


(defun spot--union-search-items (table)
  (vconcat
   (when (ht-get* table 'albums) (ht-get* table 'albums 'items))
   (when (ht-get* table 'artists) (ht-get* table 'artists 'items))
   (when (ht-get* table 'playlists) (ht-get* table 'playlists 'items))
   (when (ht-get* table 'tracks) (ht-get* table 'tracks 'items))
   (when (ht-get* table 'shows) (ht-get* table 'shows 'items))
   (when (ht-get* table 'episodes) (ht-get* table 'episodes 'items))
   (when (ht-get* table 'audiobooks) (ht-get* table 'audiobooks 'items))))


(defun spot--set-search-candidates (candidates)
  (setq spot--candidates-album (spot--filter candidates "album"))
  (setq spot--candidates-artist (spot--filter candidates "artist"))
  (setq spot--candidates-playlist (spot--filter candidates "playlist"))
  (setq spot--candidates-track (spot--filter candidates "track"))
  (setq spot--candidates-show (spot--filter candidates "show"))
  (setq spot--candidates-episode (spot--filter candidates "episode"))
  (setq spot--candidates-audiobook (spot--filter candidates "audiobook")))


;; Cached request
(defun spot--search-cached (query cache)
  (when (not (ht-get cache query))
    (setq search-results (spot--propertize-items
                          (spot--union-search-items
                           (spot--search-items query))))
    (ht-set cache query search-results))
  (setq search-results (ht-get cache query))
  (spot--set-search-candidates search-results))


;; Locked request
(defun spot--search-cached-and-locked (query mutex cache)
  (with-mutex mutex
    (spot--search-cached query cache)))


(provide 'spot-search)
