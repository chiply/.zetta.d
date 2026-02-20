(use-package gif-screencast
  :config
  ;; ImageMagick 7 uses `magick` as the top-level command.
  ;; `magick` alone acts as `convert`; cropping needs `magick mogrify`.
  (setq gif-screencast-convert-program "magick"
        gif-screencast-cropping-program "magick"
        gif-screencast-cropping-args '("mogrify" "-format" "png" "-crop")))
