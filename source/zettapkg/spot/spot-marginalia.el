;;; -*- lexical-binding: t; -*-

(require 'ht)
(require 'marginalia)


;; album
(defun annotate-album (album)
  (concat
   " <- "
   (mapconcat
    'identity
    `(,(ht-get* (get-text-property 0 'multi-data album) 'name)
      ,(ht-get* (nth 0 (ht-get* (get-text-property 0 'multi-data album) 'artists)) 'name)
      ,(ht-get* (get-text-property 0 'multi-data album) 'release_date)
      ,(number-to-string (ht-get* (get-text-property 0 'multi-data album) 'total_tracks)))
    " || ")))


;; artist
(defun annotate-artist (artist)
  (concat
   " <- "
   (mapconcat
    'identity
    `(,(ht-get* (get-text-property 0 'multi-data artist) 'name)
      ,(number-to-string (ht-get* (get-text-property 0 'multi-data artist) 'popularity))
      ,(number-to-string (ht-get* (get-text-property 0 'multi-data artist) 'followers 'total)))
    " || ")))


;; track
(defun round-to-two-decimals (num)
  (/ (round (* num 100)) 100.0))


(defun annotate-track (track)
  (concat
   " <- "
   (mapconcat
    'identity
    `(,(ht-get* (get-text-property 0 'multi-data track) 'name)

      ,(number-to-string (ht-get* (get-text-property 0 'multi-data track) 'track_number))
      ,(ht-get* (nth 0 (ht-get* (get-text-property 0 'multi-data track) 'artists)) 'name)
      ,(number-to-string (round-to-two-decimals
                          (/
                           (ht-get* (get-text-property 0 'multi-data track) 'duration_ms)
                           60000.0)))
      ,(ht-get* (get-text-property 0 'multi-data track) 'album 'name)
      ,(ht-get* (get-text-property 0 'multi-data track) 'album 'album_type)
      ,(ht-get* (get-text-property 0 'multi-data track) 'album 'release_date))
    " || ")))


;; playlist
(defun annotate-playlist (playlist)
  (concat
   " <- "
   (mapconcat
    'identity
    `(,(ht-get* (get-text-property 0 'multi-data playlist) 'name)
      ,(number-to-string (ht-get* (get-text-property 0 'multi-data playlist) 'tracks 'total)))
    " || ")))


;; show
(defun annotate-show (show)
  (concat
   " <- "
   (mapconcat
    'identity
    `(,(ht-get* (get-text-property 0 'multi-data show) 'name)
      ,(ht-get* (get-text-property 0 'multi-data show) 'publisher)
      ,(ht-get* (get-text-property 0 'multi-data show) 'media_type)
      ,(number-to-string (ht-get* (get-text-property 0 'multi-data show) 'total_episodes))
      ,(ht-get* (get-text-property 0 'multi-data show) 'description))
    " || ")))


;; episode
(defun annotate-episode (episode)
  (concat
   " <- "
   (mapconcat
    'identity
    `(,(ht-get* (get-text-property 0 'multi-data episode) 'name)
      ,(ht-get* (get-text-property 0 'multi-data episode) 'release_date)
      ,(ht-get* (get-text-property 0 'multi-data episode) 'description)
      ,(number-to-string (round-to-two-decimals
                          (/
                           (ht-get* (get-text-property 0 'multi-data episode) 'duration_ms)
                           60000.0))))
    " || ")))


;; audiobook
(defun annotate-audiobook (audiobook)
  (concat
   " <- "
   (mapconcat
    'identity
    `(,(ht-get* (get-text-property 0 'multi-data audiobook) 'name)
      ,(ht-get* (get-text-property 0 'multi-data audiobook) 'publisher)
      ,(ht-get* (nth 0 (ht-get* (get-text-property 0 'multi-data audiobook) 'narrators)) 'name)
      ,(ht-get* (nth 0 (ht-get* (get-text-property 0 'multi-data audiobook) 'authors)) 'name)
      ,(string-replace "\n" " " (ht-get* (get-text-property 0 'multi-data audiobook) 'description)))
    " || ")))


;; register
(add-to-list 'marginalia-annotator-registry '(album annotate-album))
(add-to-list 'marginalia-annotator-registry '(artist annotate-artist))
(add-to-list 'marginalia-annotator-registry '(playlist annotate-playlist))
(add-to-list 'marginalia-annotator-registry '(track annotate-track))
(add-to-list 'marginalia-annotator-registry '(show annotate-show))
(add-to-list 'marginalia-annotator-registry '(episode annotate-episode))
(add-to-list 'marginalia-annotator-registry '(audiobook annotate-audiobook))


(provide 'spot-marginalia)
