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
  (spot-mode 1))

;;; spot.el ends here
