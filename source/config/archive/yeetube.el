(use-package yeetube
  :init (define-prefix-command 'my/yeetube-map)
  :config
  ;;(setf yeetube-mpv-disable-video t) ;; Disable video output
  (setf yeetube-display-thumbnails-p nil)
  :bind (("C-c y" . 'my/yeetube-map)
          :map my/yeetube-map
		  ("s" . 'yeetube-search)
		  ("b" . 'yeetube-play-saved-video)
		  ("d" . 'yeetube-download-videos)
		  ("p" . 'yeetube-mpv-toggle-pause)
		  ("v" . 'yeetube-mpv-toggle-video)
		  ("V" . 'yeetube-mpv-toggle-no-video-flag)
		  ("k" . 'yeetube-remove-saved-video)))
