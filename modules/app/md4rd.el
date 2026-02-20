(use-package md4rd
  :config
  (defun md4rd-load-comments-from-url (url)
    "Load and display Reddit comments from URL in md4rd format.
URL should be a Reddit permalink or comments URL."
    (interactive "sReddit URL: ")
    (let ((json-url (md4rd--convert-to-json-url url)))
      (when json-url
        (message "Fetching comments from: %s" json-url)
        (md4rd--fetch-comments json-url))))

  (defun md4rd--convert-to-json-url (url)
    "Convert a Reddit URL to its JSON API endpoint."
    (cond
     ;; Already a JSON URL
     ((string-match-p "\\.json$" url) url)
     
     ;; Reddit permalink or comments URL
     ((string-match "reddit\\.com/r/[^/]+/comments/[^/?]+" url)
      (let ((clean-url (replace-regexp-in-string "\\?.*" "" url)))
        (if (string-suffix-p "/" clean-url)
            (concat clean-url ".json")
          (concat clean-url "/.json"))))
     
     ;; Old reddit format
     ((string-match "old\\.reddit\\.com" url)
      (md4rd--convert-to-json-url (replace-regexp-in-string "old\\." "" url)))
     
     ;; Mobile reddit format  
     ((string-match "m\\.reddit\\.com" url)
      (md4rd--convert-to-json-url (replace-regexp-in-string "m\\." "" url)))
     
     ;; www.reddit format
     ((string-match "www\\.reddit\\.com" url)
      (md4rd--convert-to-json-url (replace-regexp-in-string "www\\." "" url)))
     
     (t 
      (message "Invalid Reddit URL format: %s" url)
      nil)))

  ;; For elfeed integration
  (defun md4rd-elfeed-show-reddit-comments ()
    "Show Reddit comments for the current elfeed entry if it's a Reddit URL."
    (interactive)
    (when (bound-and-true-p elfeed-show-entry)
      (let ((url (elfeed-entry-link elfeed-show-entry)))
        (if (string-match-p "reddit\\.com" url)
            (md4rd-load-comments-from-url url)
          (message "Current entry is not a Reddit URL")))))

  ;; Optional: Add to elfeed-show-mode-map if you want a keybinding
  (general-unbind :keymaps 'elfeed-show-mode-map "R")
  (general-define-key :keymaps 'elfeed-show-mode-map :states 'normal "R" 'md4rd-elfeed-show-reddit-comments)

  ;; needed to use this to set things up https://not-an-aardvark.github.io/reddit-oauth-helper/
  (setq
   md4rd-subs-active
   '(lisp+Common_Lisp emacs prolog dataisbeautiful archlinux aws
     datascience Guitar healthIT jazzguitar jazztheory KnowledgeGraph
     javascript MachineLearning planetemacs Python stats SQL
     programming vim Watches webdev eink))

  (general-unbind :keymaps 'md4rd-mode :states 'normal "q")
  (general-define-key :keymaps 'md4rd-mode :states 'normal "q" 'kill-current-buffer)

  ;; fixing face
  (defface md4rd--greentext-face
    '((((type graphic) (background dark))
       :background unspecified :foreground "#90a959")
      (((type graphic) (background light))
       :background unspecified :foreground "#90a959")
      (t :background unspecified :foreground "#90a959"))
    "Face for rendering greentexts."
    :group 'md4rd)


  ;; NOTE buggy
  ;;(add-hook 'md4rd-mode-hook 'md4rd-indent-all-the-lines)
  )
