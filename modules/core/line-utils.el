;;; line-utils.el --- Configure line utilities -*- lexical-binding: t; -*-

;;;;;; Utils
(defvar ml-selected-window nil)

(defun ml-record-selected-window ()
  (setq ml-selected-window (selected-window)))

(defun ml-update-all ()
  (force-mode-line-update t))

(add-hook 'post-command-hook 'ml-record-selected-window)
(add-hook 'buffer-list-update-hook 'ml-update-all)


;;;; functions for generating icons
(defun zetta-line-iedit-icon ()
  (when (and (boundp 'iedit-mode) iedit-mode)
    (all-the-icons-material
     "find_replace"
     :face 'mode-line )))

(defun zetta-line-github-icon ()
  (when vc-mode
    (all-the-icons-faicon
     "github"
     :face 'mode-line )))

(defun zetta-line-modified-icon ()
  (when (buffer-modified-p)
    (all-the-icons-material
     "change_history"
     :face 'mode-line 
     )))

(defun zetta-line-tramp-icon ()
  (when (and (fboundp '4mn-get-tramp-hop-types)
             (member "ssh" (4mn-get-tramp-hop-types)))
    (all-the-icons-faicon "server"
                          :face 'mode-line)))

(defun zetta-line-docker-icon ()
  (when (and (fboundp '4mn-get-tramp-hop-types)
             (member "docker" (4mn-get-tramp-hop-types)))
    (all-the-icons-fileicon
     "dockerfile"
     :face 'mode-line)))

(defun zetta-line-hydra-indicator-icon ()
  (if (and
       ;; hydra loaded
       (boundp 'hydra-curr-map)
       ;; head active
       hydra-curr-map
       ;; on selected window
       (eq ml-selected-window (selected-window)))
      (all-the-icons-material
       "flare"
       
       ;; make invisible in other buffers
       :face 'mode-line 
       )
    nil))

(defun zetta-line-narrowed-icon ()
  (when (buffer-narrowed-p) "N"))




(defun zetta-get-repo-name ()
  (last (split-string
         (nth 0 (split-string
                 (shell-command-to-string
                  "git rev-parse --show-toplevel")
                 "\n"))
         "/"
         ))
  )

(defun zetta-get-branch-name ()
  (nth 0 (split-string
          (shell-command-to-string
           "git rev-parse --abbrev-ref HEAD")
          "\n")))


(defun zetta-line-col () 
  (let ((col-length (length (int-to-string (current-column)))))
    (cond
     ((eq col-length 1) "%c%2 ")
     ((eq col-length 2) "%c%1 ")
     ((eq col-length 3) "%c")
     )
    )
  )




;; This buffer is for text that is not saved, and for Lisp evaluation.
;; To create a file, visit it with C-x C-f and enter text in its buffer.
(defun mode-line-fill-right (face reserve)
  "Return empty space using FACE and leaving RESERVE space on the right."
  (unless reserve
    (setq reserve 20))
  (when (and window-system (eq 'right (get-scroll-bar-mode)))
    (setq reserve (+ reserve 3)))
  (propertize " "
              'display `((space :align-to (- (+ right right-fringe right-margin) ,reserve)))
              ;;'face face
              ))

(defun mode-line-fill-center (face reserve)
  "Return empty space using FACE to the center of remaining space leaving RESERVE space on the right."
  (unless reserve
    (setq reserve 20))
  (when (and window-system (eq 'right (get-scroll-bar-mode)))
    (setq reserve (+ reserve 3)))
  (propertize " "
              'display `((space :align-to (- (+ center (.5 . right-margin)) ,reserve
                                             (.5 . left-margin))))
              ;;'face face
              ))


;; NOTE use this to allow  more space ont eh right, otherwise you will get cutoff
(defconst RIGHT_PADDING 20)

(defun reserve-left/middle (line-align-middle)
  (/ (length (format-mode-line line-align-middle)) 2))

(defun zetta-do-reserve-left/middle (line-align-middle)
  (if (eq ml-selected-window (selected-window))
      (mode-line-fill-center 'mode-line (reserve-left/middle line-align-middle))
    (mode-line-fill-center 'mode-line-inactive
                           (reserve-left/middle line-align-middle))
    ))

(defun reserve-middle/right (line-align-right)
  (+ RIGHT_PADDING (length (format-mode-line line-align-right))))

(defun zetta-do-reserve-middle/right (line-align-right)
  (if (eq ml-selected-window (selected-window))
      (mode-line-fill-right 'mode-line
                            (reserve-middle/right line-align-right))
    (mode-line-fill-right 'mode-line-inactive
                          (reserve-middle/right line-align-right))
    ))


;; extremely conduing, but vars need to be passed to eval as strings
(defun zetta-get-line-format (line-align-left line-align-middle line-align-right)
  (list
   ;; Left
   line-align-left

   ;; Middle
   '(:eval (zetta-do-reserve-left/middle 'line-align-middle))
   line-align-middle

   ;; Right
   '(:eval (zetta-do-reserve-middle/right 'line-align-right))
   line-align-right
   )
  )
;;; line-utils.el ends here
