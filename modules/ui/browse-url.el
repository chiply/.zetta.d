;;; browse-url.el --- Configure browse-url -*- lexical-binding: t; -*-

(use-package browse-url
  :ensure nil
  :commands browse-url
  ;;:config
  ;; unsetting this for now
  ;;(setq
   ;;browse-url-handlers
   ;;'(
     ;;;; urls that cannot render fully in eww
     ;;("youtube.com" . browse-url-default-browser)
     ;;("github.com" . browse-url-default-browser)
     ;;("melpa.org" . browse-url-default-browser)
     ;;;; gives really nice hotswitching to view html files while
     ;;;; working on them
     ;;("^.+.html" . browse-url-default-browser)
     ;;;; everything else, use eww-browse-url
     ;;("." . eww-browse-url)
     ;;))
  )
;;; browse-url.el ends here
