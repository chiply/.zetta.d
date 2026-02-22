;;; -*- lexical-binding: t; -*-

(require 'ht)
(require 'consult-omni)

(require 'spot-util)
(require 'spot-var)
(require 'spot-search)

;;; Completion functions
;; album
;; TODO -- can async re-use this function?
(cl-defun spot--omni-request-album (query &rest args &key callback &allow-other-keys)
  (let ((annotated-results
         (progn (spot--search-cached-and-locked
                 query spot--mutex spot--cache)
                spot--candidates-album)))
    (funcall callback annotated-results)
    annotated-results))

;; artist
(cl-defun spot--omni-request-artist (query &rest args &key callback &allow-other-keys)
  (let ((annotated-results
         (progn (spot--search-cached-and-locked
                 query spot--mutex spot--cache)
                spot--candidates-artist)))
    (funcall callback annotated-results)
    annotated-results))

;; playlist
(cl-defun spot--omni-request-playlist (query &rest args &key callback &allow-other-keys)
  (let ((annotated-results
         (progn (spot--search-cached-and-locked
                 query spot--mutex spot--cache)
                spot--candidates-playlist)))
    (funcall callback annotated-results)
    annotated-results))

;; track
(cl-defun spot--omni-request-track (query &rest args &key callback &allow-other-keys)
  (let ((annotated-results
         (progn (spot--search-cached-and-locked
                 query spot--mutex spot--cache)
                spot--candidates-track)))
    (funcall callback annotated-results)
    annotated-results))

;; show
(cl-defun spot--omni-request-show (query &rest args &key callback &allow-other-keys)
  (let ((annotated-results
         (progn (spot--search-cached-and-locked
                 query spot--mutex spot--cache)
                spot--candidates-show)))
    (funcall callback annotated-results)
    annotated-results))

;; episode
(cl-defun spot--omni-request-episode (query &rest args &key callback &allow-other-keys)
  (let ((annotated-results
         (progn (spot--search-cached-and-locked
                 query spot--mutex spot--cache)
                spot--candidates-episode)))
    (funcall callback annotated-results)
    annotated-results))

;; audiobook
(cl-defun spot--omni-request-audiobook (query &rest args &key callback &allow-other-keys)
  (let ((annotated-results
         (progn (spot--search-cached-and-locked
                 query spot--mutex spot--cache)
                spot--candidates-audiobook)))
    (funcall callback annotated-results)
    annotated-results))

;; current user playlists
(cl-defun spot--omni-request-current-user-playlists (query &rest args &key callback &allow-other-keys)
  (let ((annotated-results
         (spot--propertize-items
          (ht-get*
           (spot--alist-to-ht
            (spot-request
             :method "GET"
             :url (format "%s/playlists" spot-me-url)
             :q-params (spot--base-q-params)
             :parse-json t))
           'items))))
    (funcall callback annotated-results)
    annotated-results))

;; playlist tracks
(cl-defun spot--omni-request-playlist-tracks (query &rest args &key callback &allow-other-keys)
  (let ((annotated-results
         (spot--propertize-items
          (-map
           (lambda (x) (ht-get* x 'track))
           (ht-get*
            (spot--alist-to-ht
             (spot-request
              :method "GET"
              :url (format "%s/%s/tracks" spot-playlist-url spot--selected-playlist-id)
              :q-params (spot--base-q-params)
              :parse-json t))
            'items)))))
    (funcall callback annotated-results)
    annotated-results))

;;; consult-omni
(defun spot--omni-group-function (sources cand transform &optional group-by)
  (ht-get (get-text-property 0 'multi-data cand) 'type))

;; artist
(consult-omni-define-source
 "artist"
 :narrow-char ?a :min-input 1 :category 'artist :require-match nil
 :type 'dynamic :request #'spot--omni-request-artist
 :group #'spot--omni-group-function
 :interactive consult-omni-intereactive-commands-type
 :enabled t)

;; album
(consult-omni-define-source
 "album"
 :narrow-char ?A :min-input 1 :category 'album :require-match nil
 :type 'dynamic :request #'spot--omni-request-album
 :group #'spot--omni-group-function
 :interactive consult-omni-intereactive-commands-type
 :enabled t)

;; playlist
(consult-omni-define-source
 "playlist"
 :narrow-char ?p :min-input 1 :category 'playlist :require-match nil
 :type 'dynamic :request #'spot--omni-request-playlist
 :group #'spot--omni-group-function
 :interactive consult-omni-intereactive-commands-type
 :enabled t)

;; track
(consult-omni-define-source
 "track"
 :narrow-char ?t :min-input 1 :category 'track :require-match nil
 :type 'dynamic :request #'spot--omni-request-track
 :group #'spot--omni-group-function
 :interactive consult-omni-intereactive-commands-type
 :enabled t)

;; show
(consult-omni-define-source
 "show"
 :narrow-char ?s :min-input 1 :category 'show :require-match nil
 :type 'dynamic :request #'spot--omni-request-show
 :group #'spot--omni-group-function
 :interactive consult-omni-intereactive-commands-type
 :enabled t)

;; episode
(consult-omni-define-source
 "episode"
 :narrow-char ?e :min-input 1 :category 'episode :require-match nil
 :type 'dynamic :request #'spot--omni-request-episode
 :group #'spot--omni-group-function
 :interactive consult-omni-intereactive-commands-type
 :enabled t)

;; audiobook
(consult-omni-define-source
 "audiobook"
 :narrow-char ?b :min-input 1 :category 'audiobook :require-match nil
 :type 'dynamic :request #'spot--omni-request-audiobook
 :group #'spot--omni-group-function
 :interactive consult-omni-intereactive-commands-type
 :enabled t)

;; current-user-playlists
(consult-omni-define-source
 "current-user-playlists"
 :narrow-char ?b :min-input 1 :category 'current-user-playlists :require-match nil
 :type 'dynamic :request #'spot--omni-request-current-user-playlists
 :group #'spot--omni-group-function
 :interactive consult-omni-intereactive-commands-type
 :enabled t)

;; MULTI
(setq
 consult-omni-spot-sources
 '("artist" "album" "playlist" "track" "show" "episode" "audiobook"))

(defun consult-omni-spot-search (&optional initial prompt sources no-callback &rest args)
  (interactive "P")
  (let ((sources (or sources consult-omni-spot-sources)))
    (consult-omni-multi initial prompt sources no-callback 1 args)))

(provide 'spot-consult-omni)
