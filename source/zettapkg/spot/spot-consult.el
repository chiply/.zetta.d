;;; -*- lexical-binding: t; -*-

(require 'consult)

(require 'spot-util)
(require 'spot-search)
(require 'spot-var)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; multi-search
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; completion functions
(defun spot--consult-completion-function-consult-album (query)
  (spot--search-cached-and-locked query spot--mutex spot--cache) spot--candidates-album)

(defun spot--consult-completion-function-consult-artist (query)
  (spot--search-cached-and-locked query spot--mutex spot--cache) spot--candidates-artist)

(defun spot--consult-completion-function-consult-playlist (query)
  (spot--search-cached-and-locked query spot--mutex spot--cache) spot--candidates-playlist)

(defun spot--consult-completion-function-consult-track (query)
  (spot--search-cached-and-locked query spot--mutex spot--cache) spot--candidates-track)

(defun spot--consult-completion-function-consult-show (query)
  (spot--search-cached-and-locked query spot--mutex spot--cache) spot--candidates-show)

(defun spot--consult-completion-function-consult-episode (query)
  (spot--search-cached-and-locked query spot--mutex spot--cache) spot--candidates-episode)

(defun spot--consult-completion-function-consult-audiobook (query)
  (spot--search-cached-and-locked query spot--mutex spot--cache) spot--candidates-audiobook)


;; histories
(setq spot--history-sourceAlbum nil)
(setq spot--history-sourceArtist nil)
(setq spot--history-sourcePlaylist nil)
(setq spot--history-sourceTrack nil)
(setq spot--history-sourceShow nil)
(setq spot--history-sourceEpisode nil)
(setq spot--history-sourceAudiobook nil)


;; sources
(setq spot--consult-source-album
      `(
        :async ,(consult--dynamic-collection
                    #'spot--consult-completion-function-consult-album
                  :min-input 1)
        :name "spot--consult-source-album"
        :narrow ?a
        :category album
        :history spot--history-sourceAlbum))


(setq spot--consult-source-artist
      `(
        :async ,(consult--dynamic-collection
                    #'spot--consult-completion-function-consult-artist
                  :min-input 1)
        :name "spot--consult-source-artist"
        :narrow ?A
        :category artist
        :history spot--history-sourceArtist))


(setq spot--consult-source-playlist
      `(
        :async ,(consult--dynamic-collection
                    #'spot--consult-completion-function-consult-playlist
                  :min-input 1)
        :name "spot--consult-source-playlist"
        :narrow ?p
        :category playlist
        :history spot--history-sourcePlaylist))


(setq spot--consult-source-track
      `(
        :async ,(consult--dynamic-collection
                    #'spot--consult-completion-function-consult-track
                  :min-input 1)
        :name "spot--consult-source-track"
        :narrow ?t
        :category track
        :history spot--history-sourceTrack))


(setq spot--consult-source-show
      `(
        :async ,(consult--dynamic-collection
                    #'spot--consult-completion-function-consult-show
                  :min-input 1)
        :name "spot--consult-source-show"
        :narrow ?s
        :category show
        :history spot--history-sourceShow))


(setq spot--consult-source-episode
      `(
        :async ,(consult--dynamic-collection
                    #'spot--consult-completion-function-consult-episode
                  :min-input 1)
        :name "spot--consult-source-episode"
        :narrow ?e
        :category episode
        :history spot--history-sourceEpisode))


(setq spot--consult-source-audiobook
      `(
        :async ,(consult--dynamic-collection
                    #'spot--consult-completion-function-consult-audiobook
                  :min-input 1)
        :name "spot--consult-source-audiobook"
        :narrow ?b
        :category audiobook
        :history spot--history-sourceAudiobook))


(setq search-sources
      '(
        spot--consult-source-album spot--consult-source-artist
        spot--consult-source-playlist spot--consult-source-track
        spot--consult-source-show spot--consult-source-episode
        spot--consult-source-audiobook))


;; multi
(setq spot--consult-search-search-history nil)


(defun spot-consult-search (&optional initial)
  (interactive)
  ;; NOTE optionally reset cache everytime this is invoked
  ;;(setq spot--cache (ht-create))
  (consult--multi
   search-sources
   :history '(:input spot--consult-search-search-history)
   :initial initial))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; current user playlists
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun spot--consult-completion-function-consult-current-user-playlists (query)
  (spot--propertize-items
   (ht-get*
    (spot--alist-to-ht
     (spot-request
      :method "GET"
      :url (format "%s/playlists" spot-me-url)
      :q-params (spot--base-q-params)
      :parse-json t))
    'items)))


(setq spot--history-sourceCurrentUserPlaylists nil)


(setq spot--consult-source-current-user-playlists
      `(
        :async ,(consult--dynamic-collection
                    #'spot--consult-completion-function-consult-current-user-playlists
                  :min-input 0)
        :name "spot--consult-source-current-user-playlists"
        :narrow ?b
        :category current-user-playlists
        :history spot--history-sourceCurrentUserPlaylists))


(setq spot--consult-search-current-user-playlists-history nil)


(defun spot-consult-search-current-user-playlists ()
  "NOTE this doesn't actually query the backend to filter playlists,rather
it lists all playlists.  To get instant filterning in emacs, you can hit
SPC and comma to filter the output"
  (interactive)
  (consult--multi
   '(spot--consult-source-current-user-playlists)
   :history '(:input spot--consult-search-current-user-playlists-history)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; playlist tracks
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun spot--consult-completion-function-playlist-tracks (query)
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
     'items))))


(setq spot--history-sourcePlaylistTracks nil)


(setq spot--consult-source-playlists-tracks
      `(
        :async ,(consult--dynamic-collection
                    #'spot--consult-completion-function-playlist-tracks
                  :min-input 0)
        :name "spot--consult-source-playlists-tracks"
        :narrow ?b
        :category playlist-tracks
        :history spot--history-sourcePlaylistTracks))


(setq spot--consult-search-playlist-tracks-history nil)


(defun spot-consult-search-playlist-tracks ()
  "NOTE this doesn't actually query the backend to filter playlists,rather
it lists all playlists.  To get instant filterning in emacs, you can hit
SPC and comma to filter the output"
  (interactive)
  (consult--multi
   '(spot--consult-source-playlists-tracks)
   :history '(:input spot--consult-search-playlist-tracks-history)))



(provide 'spot-consult)
