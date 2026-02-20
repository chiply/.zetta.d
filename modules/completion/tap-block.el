;; TODO:
;; block titles -- just maker sure the reggex works
;; naming convention: tap-[thing]-
;; functiton to surround selection witth block open and block end





;;;; utils

;; dynamically compute block names
(defun comment-start () (s-trim comment-start))
(defun tap-block-regex () (concat "^" (comment-start) (comment-start) "block"))
(defun tap-block-open-regex () (concat "^" (comment-start) (comment-start) "blockbeg"))
(defun tap-block-close-regex () (concat "^" (comment-start) (comment-start) "blockend"))

(defun tap-block-on-open ()
  (interactive)
  (string-match (tap-block-open-regex) (s-trim (thing-at-point 'line))))

(defun tap-block-on-close ()
  (interactive)
  (string-match (tap-block-close-regex) (s-trim (thing-at-point 'line))))

(defun tap-block-find (direction open-clos beg-end &optional move)
  (interactive)
  (let* ((regex (cond ((string= open-clos "open") (tap-block-open-regex))
                      ((string= open-clos "close") (tap-block-close-regex))))
         (pos (save-excursion
                (cond ((string= direction "forward") (re-search-forward regex nil t))
                      ((string= direction "backward") (re-search-backward regex nil t)))
                (cond ((string= beg-end "beginning") (beginning-of-line))
                      ((string= beg-end "end") (end-of-line)))
                (point)
                )))
    ;; for testing purposes, when MOVE, move cursor to this position
    (when (and pos move) (goto-char pos))
    ;; return pos
    pos
    )
  )



;;;; forward block
(defun block-next-block ()
  (interactive)
  (when (tap-block-on-open) (end-of-line))
  (tap-block-find "forward" "open" "beginning" t)
  )

(defun block-backward-block ()
  (interactive)
  (tap-block-find "backward" "open" "beginning" t)
  )

(defun block-forward-block (&optional arg)
  (interactive "p")
  (setq arg (or arg 1)) 
  (while (and (> arg 0) (not (eobp)) (block-next-block))
    (setq arg (1- arg)))
  (while (and (< arg 0) (not (bobp)) (block-backward-block))
    (setq arg (1+ arg)))
  )

(put 'block 'forward-op 'block-forward-block)



(defun tap-in-block ()
  (interactive)
  ;; top is beginning
  ;; bottom is close
  (let ((above (save-excursion
                 (unless (or (tap-block-on-open) (tap-block-on-close))
                   (re-search-backward (tap-block-regex) nil t))
                 (cond ((tap-block-on-open) "open")
                       ((tap-block-on-close) "close")
                       )
                 ))
        (below (save-excursion
                 (unless (or (tap-block-on-open) (tap-block-on-close))
                   (re-search-forward (tap-block-regex) nil t)
                   )
                 (cond ((tap-block-on-open) "open")
                       ((tap-block-on-close) "close")
                       )
                 ))
        )
    (or
     (tap-block-on-open) (tap-block-on-close)
     (and (string= above "open") (string= below "close")))
    )
  )


;;; bounds of thing and point
(defun block-bounds-of-block-at-point ()
  (interactive)
  ;; save excursion is necessary, otherwise poin gets moved
  ;; unexpectedly and locks cursors
  (save-excursion
    (when (and
           (tap-in-block)
           (tap-block-find "backward" "open" "beginning")
           (tap-block-find "forward" "close" "beginning"))
      (let* ((beg (cond ((bobp) (point))
                        ((tap-block-on-open) (progn (beginning-of-line) (point)))
                        (t (tap-block-find "backward" "open" "beginning"))))
             (end (cond ((eobp) (point))
                        ((tap-block-on-close) (progn (beginning-of-line) (point)))
                        (t (1+ (tap-block-find "forward" "close" "end"))))))
        (cons beg end)))))

(put 'block 'bounds-of-thing-at-point 'block-bounds-of-block-at-point)





