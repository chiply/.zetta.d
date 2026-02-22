;;; bootstrap-display.el --- Configure display utilities -*- lexical-binding: t; -*-

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; Core functions / utils
(defun zetta-soda-get-buffer-window (buf-name)
  (get-buffer-window (if (get-buffer buf-name)
                         (get-buffer buf-name)
                       (message "fooobar"))))

(defun zetta-soda-buffer-displayed-p (buf-name)
  (window-live-p (zetta-soda-get-buffer-window buf-name)))

(defun zetta-soda-delete (buf-name)           ;
  (interactive)
  (delete-window (zetta-soda-get-buffer-window buf-name)))

(defun zetta-soda-list-displaying-buffers ()
  "Lists the buffers that are being displayed in the current
frame.  This is done by looping through each displaying window
and storing the buf-or-mode-name of the buffer being sdisplayed in that
window to the buffer list that gets returned."
  (interactive)
  (let ((lst '()))
    (while (not (member (buffer-name (window-buffer)) lst))
      (setq lst (cons (buffer-name (window-buffer)) lst))
      (other-window 1))
    (butlast lst 0)))

(defun zetta-soda-sidewindow-p (buf)
  (if (window-parameter (get-buffer-window buf) 'window-slot)
      (message "yes")
    (message "no")))

(defun zetta-soda-list-displaying-side-windows ()
  (interactive)
  (let (
        (bufs (zetta-soda-list-displaying-buffers))
        )
    (when (member "yes" (mapcar 'zetta-soda-sidewindow-p bufs))
      (message "foo"))))

(defun zetta-soda-get-mode (buffer)
  (with-current-buffer buffer major-mode))

(defun zetta-soda-mode-displayed-p (mode)
  "Returns buf-name of buffer if a buffer with the major mode is
being displayed, otherwise returns nil"
  (let ((displaying-buffers (zetta-soda-list-displaying-buffers)))
    (-filter
     (lambda (buffer) (string-match mode (symbol-name (zetta-soda-get-mode buffer))))
     displaying-buffers)))

(defun zetta-soda-list-mode-buffers (mode)
  "Returns buf-name of buffer if a buffer with the major mode is
being displayed, otherwise returns nil"
  (let ((displaying-buffers (buffer-list)))
    (-filter
     (lambda (buffer) (string-match mode (symbol-name (zetta-soda-get-mode buffer))))
     displaying-buffers)))

(defun zetta-soda-mode-name (mode)
  (lambda (buffer &rest optional)
    (with-current-buffer buffer
      (string-match mode (symbol-name major-mode)))))

(defun zetta-soda-count-windows ()
  (setq lst '())
  (while (not (member (selected-window) lst))
    (setq lst (cons (selected-window) lst))
    (other-window 1))
  (length lst))

;;;;;;;;;;;; side windows
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; Display buffer alist (leverages soda functions)
;; left top right bottom
(setq window-sides-slots '(3 3 3 4))
;; tryign this ou for now
(setq window-sides-vertical t)

;; note you need to reevaluate the zetta-side function
(setq zetta-side-display-default-height-top 0.2)
(setq zetta-side-display-default-height-bottom 0.2)
(setq zetta-side-display-default-width-left 0.2)
(setq zetta-side-display-default-width-right 0.25)

(defun zetta-side (&rest args)
  ;; delete old config
  (let ((regex (or (plist-get args :regex) (error "must supply regex")))
        (side (or (plist-get args :side) nil))
        (slot (or (plist-get args :slot) nil))
        (size (or (plist-get args :size) nil))
        (size2 (or (plist-get args :size2) nil)))
    (setq
     display-buffer-alist
     (-remove
      (lambda (elt)
        (cond
         ((stringp (nth 0 elt)) (string= (nth 0 elt) regex))
         ((equal (nth 0 elt) 'popper-display-control-p) nil) ;;keep
         ((equal (nth 0 elt) 'closure)
          (equal (cdr (nth 0 (nth 1 (nth 0 elt)))) regex))
         (t nil)))
      display-buffer-alist))

    ;; set height or width if side window
    (let ((height (cond
                   ((and size size2) size)
                   ((equal side 'top) (or size zetta-side-display-default-height-top))
                   ((equal side 'bottom) (or size zetta-side-display-default-height-bottom))
                   ((or (equal side 'left) (equal side 'right)) nil)))
          (width (cond
                  ((and size size2) size2)
                  ((equal side 'left) (or size zetta-side-display-default-width-left))
                  ((equal side 'right) (or size zetta-side-display-default-width-right))
                  ((or (equal side 'top) (equal side 'bottom)) nil)))
          (slot (or slot 0)))

      ;; update
      (add-to-list
       'display-buffer-alist
       (if (string-match "-mode$" regex)
           `(,(zetta-soda-mode-name regex)
             (display-buffer-reuse-window display-buffer-in-side-window)
             (reusable-frames . visible)
             (side . ,side) (slot . ,slot)
             (window-height . ,height) (window-width . ,width)
             (window-parameters . ((no-delete-other-windows . 1))))
         `(,regex
           (display-buffer-reuse-window display-buffer-in-side-window)
           (reusable-frames . visible)
           (side . ,side) (slot . ,slot)
           (window-height . ,height) (window-width . ,width)
           (window-parameters . ((no-delete-other-windows . 1)))))
       nil))
    ))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; Soda drink, cao, and switch to buffer
(defun zetta-soda-drink (func &optional buf-or-mode-name)
  (cond
   ;; displayed (by buffer name)
   ((zetta-soda-buffer-displayed-p buf-or-mode-name)
    (select-window (get-buffer-window buf-or-mode-name)))
   ;; displayed (by mode name)
   ((zetta-soda-mode-displayed-p buf-or-mode-name)
    (select-window (get-buffer-window (nth 0 (zetta-soda-mode-displayed-p buf-or-mode-name)))))
   ;; running, not displayed
   ((and (get-buffer buf-or-mode-name) (not (zetta-soda-buffer-displayed-p buf-or-mode-name)))
    (display-buffer buf-or-mode-name))

   ((not (get-buffer buf-or-mode-name))
    (funcall func buf-or-mode-name)))
  )

(defun zetta-soda-cap (target &optional mode-based)
  ;; what about closing based on mode?
  (interactive)
  (if mode-based
      ;; do a mode-based delete (should only be one window with that mode, based on how this tool is used)
      (let ((buf (nth 0 (zetta-soda-mode-displayed-p target))))
        (if buf
            (zetta-soda-delete buf)
          (message "Nothing like this is being displayed at the moment")))
    ;; otherwise, do a buffer-based delete
    (zetta-soda-delete target)))

(defun zetta-soda-create-and-display-messages (&optional buf-or-mode-name)
  (let ((buf (current-buffer)))
    (let ((newbuf (get-buffer-create "*Messages*")))
      (switch-to-buffer buf)
      (display-buffer newbuf))))

(defun zetta-soda-drink-messages ()
  (interactive)
  (zetta-soda-drink (quote zetta-soda-create-and-display-messages) "*Messages*"))

(defun zetta-soda-cap-messages ()
  (interactive)
  (zetta-soda-cap "*Messages*"))

(defun zetta-soda-cap-info ()
  (interactive)
  (zetta-soda-cap "*info*"))

(general-define-key
 :keymaps 'menu-run-map
 "m" (** zetta-soda-drink-messages)
 "c"  (** calendar)
 "i"  (** info)
 "M" (** zetta-soda-cap-messages)
 "I" (** zetta-soda-cap-info))

(defalias 'use-package-handler/:display 'use-package-handle-forms)
(defalias 'use-package-normalize/:display 'use-package-normalize-forms)
(add-to-list 'use-package-keywords :display t)

(provide 'bootstrap-display)
;;; bootstrap-display.el ends here
