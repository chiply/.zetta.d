;;; -*- lexical-binding: t; -*-

(require 'ht)

(require 'spot-mode-line)
(require 'spot-consult)
(require 'spot-var)

(defun spot-action--generic-show-data (item)
  (let ((buf (get-buffer-create "*spotify-search-result*")))
    (with-current-buffer buf
      (erase-buffer)
      (insert (yaml-encode (get-text-property 0 'multi-data item))))
    (switch-to-buffer buf)
    (beginning-of-buffer)
    (yaml-mode)
    (yaml-pro-mode 1)))

(defun spot-action--list-album-tracks (item)
  (let* ((table (get-text-property 0 'multi-data item))
         (album-name (ht-get* table 'name))
         (artist-name (ht-get* (nth 0 (ht-get* table 'artists)) 'name)))
    (spot-consult-search
     (concat
      "album:" album-name
      " "
      "artist:" artist-name " -- --type=track"))))

(defun spot-action--list-artist-tracks (item)
  (let* ((table (get-text-property 0 'multi-data item))
         (artist-name (ht-get* table 'name)))
    (spot-consult-search
     (concat "artist:" artist-name " -- --type=track"))))

(defun spot-action--list-playlist-tracks (item)
  (let* ((table (get-text-property 0 'multi-data item))
         (playlist-id (ht-get* table 'id)))
    (setq spot--selected-playlist-id playlist-id)
    (spot-consult-search-playlist-tracks)))

(defun spot-action--generic-play-uri (item)
  (let* ((table (get-text-property 0 'multi-data item))
         (type (ht-get table 'type))
         (offset (cond
                  ((string= type "track") `(("uri" . ,(ht-get* table 'uri))))
                  ((string= type "playlist") '(("position" . 0)))
                  ((string= type "album") '(("position" . 0)))
                  ((string= type "artist") nil)))
         (context_uri (cond
                       ((string= type "track") (ht-get* table 'album 'uri))
                       ((string= type "playlist") (ht-get* table 'uri))
                       ((string= type "album") (ht-get* table 'uri))
                       ((string= type "artist") (ht-get* table 'uri))))
         (json (list))
         (_ (when context_uri (add-to-list 'json
                                           (cons 'context_uri context_uri))))
         (_ (when offset (add-to-list 'json
                                      (cons 'offset offset))))
         (json (json-encode json)))
    (spot-request-async
     :method "PUT"
     :url spot-player-play-url
     :q-params (spot--base-q-params)
     :callback (lambda (_) (run-with-timer 2.0 nil 'spot--update-modeline-lighters))
     :data json)))

(defun spot-action--add-track-to-playlist (item)
  (let* ((playlist (or spot--playlist-selected
                       (progn
                         (setq spot--playlist-selected (car (spot-consult-search-current-user-playlists)))
                         spot--playlist-selected)))
         (playlist-id (ht-get* (get-text-property 0 'multi-data playlist) 'id))
         (track-uri (or
                     ;; regular track
                     (ht-get* (get-text-property 0 'multi-data item) 'uri)
                     ;; from currently playing
                     (ht-get* (get-text-property 0 'multi-data item) 'item 'uri)))
         (json (format "{\"uris\":[\"%s\"]}" track-uri))
         (url (format
               "https://api.spotify.com/v1/playlists/%s/tracks"
               playlist-id)))
    (spot-request-async
     :method "POST"
     :url url
     :q-params (spot--base-q-params)
     :data json)))

;; keymaps
(defvar-keymap embark-artist-keymap :parent embark-general-map)
(defvar-keymap embark-album-keymap :parent embark-general-map)
(defvar-keymap embark-playlist-keymap :parent embark-general-map)
(defvar-keymap embark-track-keymap :parent embark-general-map)
(defvar-keymap embark-show-keymap :parent embark-general-map)
(defvar-keymap embark-episode-keymap :parent embark-general-map)
(defvar-keymap embark-audiobook-keymap :parent embark-general-map)
(defvar-keymap embark-current-user-playlists-keymap :parent embark-general-map)
(defvar-keymap embark-playlist-tracks-keymap :parent embark-general-map)

(add-to-list 'embark-keymap-alist '(album embark-album-keymap))
(add-to-list 'embark-keymap-alist '(artist embark-artist-keymap))
(add-to-list 'embark-keymap-alist '(playlist embark-playlist-keymap))
(add-to-list 'embark-keymap-alist '(track embark-track-keymap))
(add-to-list 'embark-keymap-alist '(show embark-show-keymap))
(add-to-list 'embark-keymap-alist '(episode embark-episode-keymap))
(add-to-list 'embark-keymap-alist '(audiobook embark-audiobook-keymap))
(add-to-list 'embark-keymap-alist '(current-user-playlists embark-current-user-playlists-keymap))
(add-to-list 'embark-keymap-alist '(playlist-tracks embark-playlist-tracks-keymap))

;; bindings
(general-define-key
 :keymaps '(
            embark-artist-keymap embark-album-keymap
            embark-playlist-keymap embark-track-keymap
            embark-show-keymap embark-episode-keymap
            embark-audiobook-keymap
            embark-current-user-playlists-keymap
            embark-playlist-tracks-keymap)
 "s" 'spot-action--generic-show-data
 "P" 'spot-action--generic-play-uri)

(general-define-key
 :keymaps '(embark-track-keymap)
 "+" 'spot-action--add-track-to-playlist)

(general-define-key
 :keymaps '(embark-album-keymap)
 "t" 'spot-action--list-album-tracks)

(general-define-key
 :keymaps '(embark-artist-keymap)
 "t" 'spot-action--list-artist-tracks)

(general-define-key
 :keymaps '(embark-playlist-keymap)
 "t" 'spot-action--list-playlist-tracks)

(provide 'spot-embark)
