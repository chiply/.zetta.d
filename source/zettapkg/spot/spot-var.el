;;; -*- lexical-binding: t; -*-

(defvar spot--playlist-selected nil)
(defvar spot--selected-playlist-id nil)

(defvar spot-client-id "7b036492368d47c492d048aa8aec339b")
(defvar spot-client-secret "4deb0f8b549f436a9d46202e701b57b8")
(defvar spot-id-secret
  (concat spot-client-id ":" spot-client-secret))
(defvar spot-b64-id-secret
  (base64-encode-string spot-id-secret t))
(defvar spot-redirect-uri (url-hexify-string "https://spotify.com"))
(defvar spot-auth-url-full
  (url-encode-url
   (concat
    "https://accounts.spotify.com/en/authorize"
    "?response_type=code&client_id=" spot-client-id
    "&redirect_uri=" spot-redirect-uri
    "&scope=" (concat "streaming "
                      "user-read-birthdate "
                      "user-read-email "
                      "user-read-private "
                      "user-read-playback-state "
                      "user-library-modify "
                      "user-library-read "
                      "user-modify-playback-state "
                      "user-follow-read "
                      "playlist-modify-public "
                      "playlist-modify-private "
                      "user-read-recently-played")
    "&show_dialog=" "true")))
(defvar spot-token-url "https://accounts.spotify.com/api/token")
(defvar spot-search-url "https://api.spotify.com/v1/search")
(defvar spot-access-token nil)
(defvar spot-refresh-token nil)

;; there are synchronicity issues when displaying currently-playing
;; after doing player action (i.e. next, previous), even when using
;; spot-message-currently-playing as a callback funtion, so for now
;; force sleep time between changing track and calling
;; spot-message-currently-playing to resolve this issue.
(defvar spot-wait-time 1.0)
(defvar spot-player-url "https://api.spotify.com/v1/me/player")
(defvar spot-player-play-url (concat spot-player-url "/play"))
(defvar spot-currently-playing-url (concat spot-player-url "/currently-playing"))
(defvar spot-categories-url "https://api.spotify.com/v1/browse/categories")
(defvar spot-browse-url "https://api.spotify.com/v1/browse")
(defvar spot-playlist-url "https://api.spotify.com/v1/users/spotify/playlists")
(defvar spot-new-releases-url "https://api.spotify.com/v1/browse/new-releases")
(defvar spot-albums-url "https://api.spotify.com/v1/albums")
(defvar spot-artist-url "https://api.spotify.com/v1/artists")
(defvar spot-recommendations-url "https://api.spotify.com/v1/recommendations")
(defvar spot-me-url "https://api.spotify.com/v1/me")
(defvar spot-users-url "https://api.spotify.com/v1/users")
(defvar spot-following-url "https://api.spotify.com/v1/me/following")
(defvar spot-tracks-url "https://api.spotify.com/v1/tracks/")
(setq spot-recently-played-url "https://api.spotify.com/v1/me/player/recently-played")
(defvar spot--request-timeout 10)


(defun spot--base-q-params ()
  (concat "?access_token=" spot-access-token))



(provide 'spot-var)
