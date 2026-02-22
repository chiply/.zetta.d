;;; gif-screencast.el --- Configure gif-screencast -*- lexical-binding: t; -*-

(use-package gif-screencast
  :config
  ;; Use png + Emacs-internal capture (no screencapture permission needed,
  ;; and macOS screencapture doesn't support ppm despite what the docs say).
  (setq gif-screencast-capture-format "png"
        gif-screencast-capture-prefer-internal t
        gif-screencast-args '("-x"))

  ;; IM7 installs convert/mogrify symlinks that enter IM6 compat mode,
  ;; which matches the argument ordering gif-screencast expects.
  (setq gif-screencast-convert-program "convert"
        gif-screencast-cropping-program "mogrify"
        gif-screencast-cropping-args #'gif-screencast-cropping-arg-list)

  ;; Retina: 3840x2160 rendered at 1920x1080
  (setq gif-screencast-scale-factor 2.0)

  ;; gifsicle not installed
  (setq gif-screencast-want-optimized nil)

  ;; Fix: gif-screencast uses %T (HH:MM:SS) in filenames, but ImageMagick
  ;; interprets colons as coder prefixes (e.g. "17:56:53.png" → coder "17").
  ;; Override capture to use dashes instead.
  (define-advice gif-screencast-capture (:override () zetta-colon-safe)
    "Capture with colon-safe filenames for ImageMagick compatibility."
    (let* ((time (current-time))
           (file (expand-file-name
                  (concat (format-time-string "screen-%F-%H-%M-%S-%3N" time)
                          "." gif-screencast-capture-format)
                  gif-screencast-screenshot-directory)))
      (if (and (fboundp 'x-export-frames)
               (string= gif-screencast-capture-format "png")
               gif-screencast-capture-prefer-internal)
          (gif-screencast-capture--internal file)
        (setq gif-screencast--counter (+ gif-screencast--counter 1))
        (let ((p (gif-screencast--start-process
                  gif-screencast-program
                  (append gif-screencast-args (list file)))))
          (set-process-sentinel p 'gif-screencast-capture-sentinel)))
      (push (make-gif-screencast-frame
             :timestamp (time-subtract time gif-screencast--offset)
             :filename file)
            gif-screencast--frames))))
;;; gif-screencast.el ends here
