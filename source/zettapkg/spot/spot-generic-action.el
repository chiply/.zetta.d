;;; -*- lexical-binding: t; -*-

(require 'ht)

(require 'spot-mode-line)
(require 'spot-var)
(require 'spot-generic-query)



(defun spot-add-current-track-to-playlist ()
  (interactive)
  (setq spot--playlist-selected nil)
  (let* ((current (spot--alist-to-ht (spot--currently-playing)))
         (track-uri (propertize
                     (ht-get* current 'item 'uri)
                     'category 'track
                     'multi-data current)))
    (if track-uri
        (spot-action--add-track-to-playlist track-uri)
      (message "No track currently playing.")))
  (setq spot--playlist-selected nil))


(defun spot--player-action (action)
  (spot-request-async
   :method (cond
            ((member action '("play" "pause")) "PUT")
            ((member action '("next" "previous")) "POST"))
   :url (cond
         ((string= action "play") (format "%s/play" spot-player-url))
         ((string= action "next") (format "%s/next" spot-player-url))
         ((string= action "previous") (format "%s/previous" spot-player-url))
         ((string= action "pause") (format "%s/pause" spot-player-url)))
   :q-params (spot--base-q-params)
   :callback (when (member action '("play" "next" "previous"))
               (lambda (_) (run-with-timer 2.0 nil 'spot--update-modeline-lighters)))
   :extra-headers `(("Content-Length" . "0"))))


;; commands
(defun spot-player-play () (interactive) (spot--player-action "play"))
(defun spot-player-pause () (interactive) (spot--player-action "pause"))
(defun spot-player-next () (interactive) (spot--player-action "next"))
(defun spot-player-previous () (interactive) (spot--player-action "previous"))



(provide 'spot-generic-action)
