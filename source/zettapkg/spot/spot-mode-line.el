;;; -*- lexical-binding: t; -*-

(require 'ht)

(require 'spot-generic-query)
(require 'spot-util)

(defvar spot--modeline-track nil)
(defvar spot--modeline-artist nil)
(defvar spot--modeline-album nil)
(defvar spot--modeline-repeat-state nil)
(defvar spot--modeline-release-date nil)
(defvar spot--modeline-shuffle-state nil)
(defvar spot--modeline-smart-shuffle nil)

(defvar spot--timer-started nil)
(defvar spot--update-timers '())
(defvar spot--update-interval 30)

(defun spot--update-modeline-lighters ()
  (let* ((current (spot--alist-to-ht (spot--currently-playing))))
    (when current
      (setq spot--modeline-track
            (ht-get* current 'item 'name))
      (setq spot--modeline-artist
            (ht-get* (nth 0 (ht-get* current 'item 'artists)) 'name))
      (setq spot--modeline-album
            (ht-get* current 'item 'album 'name))
      (setq spot--modeline-repeat-state
            (ht-get* current 'repeat_state))
      (setq spot--modeline-release-date
            (ht-get* current 'item 'album 'release_date))
      (setq spot--modeline-shuffle-state
            (ht-get* current 'shuffle_state))
      (setq spot--modeline-smart-shuffle
            (ht-get* current 'smart_shuffle)))
    (when (not current)
      (setq spot--modeline-track nil)
      (setq spot--modeline-artist nil)
      (setq spot--modeline-album nil)
      (setq spot--modeline-repeat-state nil)
      (setq spot--modeline-release-date nil)
      (setq spot--modeline-shuffle-state nil)
      (setq spot--modeline-smart-shuffle nil))))

(defun spot--check-for-modeline-update ()
  (spot--update-modeline-lighters)
  ;; NOTE when let is used because when no device is active, `current`
  ;; will be nil
  (when-let* ((current (spot--alist-to-ht (spot--currently-playing)))
              (progress (ht-get current 'progress_ms))
              (duration (ht-get* current 'item 'duration_ms))
              (remaining (- duration progress))
              (delay (max 0 remaining)))
    (-map (lambda (timer) (cancel-timer timer)) spot--update-timers)
    ;; NOTE updates at the estimated time when the track changes (one
    ;; second after the track changes)
    (add-to-list
     'spot--update-timers
     (run-with-timer
      (+ (/ delay 1000.0) 1.0) nil
      'spot--update-modeline-lighters))))

(defun spot--start-update-timer ()
  (when (not spot--timer-started)
    (run-with-timer
     0 spot--update-interval
     'spot--check-for-modeline-update)
    (setq spot--timer-started t)))

(defun spot-mode-line-string ()
  (let* ((lighters `(,spot--modeline-track
                     ,spot--modeline-artist
                     ,spot--modeline-album
                     ,spot--modeline-release-date
                     ,(cond
                       ((equal spot--modeline-repeat-state "off") nil)
                       ((equal spot--modeline-repeat-state nil) nil)
                       (t "repeat"))
                     ,(or
                       (cond
                        ((equal :json-false spot--modeline-smart-shuffle) nil)
                        ((equal t spot--modeline-smart-shuffle) "smart shuffle")
                        ((equal nil spot--modeline-smart-shuffle) nil))
                       (cond
                        ((equal :json-false spot--modeline-shuffle-state) nil)
                        ((equal t spot--modeline-shuffle-state) "shuffle")
                        ((equal nil spot--modeline-shuffle-state) nil))
                       )))
         (lighters (remove nil lighters)))
    (propertize
     (if lighters (mapconcat 'identity lighters " * ") "*")
     ;; the official spotify green
     'face `(
             ;;:foreground "#1db954"
             :foreground ,brushup-fg-4
                         ))))

(provide 'spot-mode-line)
