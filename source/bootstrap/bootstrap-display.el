;;; bootstrap-display.el --- Configure display utilities -*- lexical-binding: t; -*-

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; Core functions / utils
(defun zetta-soda-get-buffer-window (buf-name)
  (get-buffer-window (get-buffer buf-name)))

(defun zetta-soda-buffer-displayed-p (buf-name)
  (window-live-p (zetta-soda-get-buffer-window buf-name)))

(defun zetta-soda-delete (buf-name)           ;
  (interactive)
  (delete-window (zetta-soda-get-buffer-window buf-name)))

(defun zetta-soda-list-displaying-buffers ()
  "Lists the buffers that are being displayed in the current
frame.  This is done by looping through each displaying window
and storing the buf-or-mode-name of the buffer being displayed in that
window to the buffer list that gets returned."
  (interactive)
  (let ((lst '()))
    (while (not (member (buffer-name (window-buffer)) lst))
      (setq lst (cons (buffer-name (window-buffer)) lst))
      (other-window 1))
    (butlast lst 0)))

(defun zetta-soda-sidewindow-p (buf)
  (if (window-parameter (get-buffer-window buf) 'window-slot)
      t
    nil))

(defun zetta-soda-list-displaying-side-windows ()
  (interactive)
  (let (
        (bufs (zetta-soda-list-displaying-buffers))
        )
    (when (cl-some #'identity (mapcar 'zetta-soda-sidewindow-p bufs))
      t)))

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
  (let ((lst '()))
    (while (not (member (selected-window) lst))
      (setq lst (cons (selected-window) lst))
      (other-window 1))
    (length lst)))

;;;;;;;;;;;; side windows
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; Display buffer alist (leverages soda functions)
;; Max side-window slots per edge: (left top right bottom).
;; 3 slots per edge except bottom gets 4 for which-key + compilation + misc.
(setq window-sides-slots '(3 3 3 4))
;; When t, left/right side windows span the full frame height (above/below top/bottom).
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; Work that needs a graphical frame
;;
;; Under the daemon, anything that measures fonts or lays out the SVG chrome
;; has to wait for the first graphical frame.  The config used to wait on
;; `server-after-make-frame-hook', and that hook is a poor promise: the
;; server runs it only for frames it makes itself, skips it -- every
;; function on it -- when the request arrives while the daemon sits in a
;; minibuffer or an isearch (`server-execute'), and an error in one function
;; on it silences every function after it.  Measured 2026-10-21: a daemon
;; whose only GUI frame carried the server's `nowait' client mark still had
;; every font function armed on that hook an hour later, `zetta-svg-line-fonts'
;; never assigned, and the mode line drawn in the wrong family.
;;
;; So work is registered here instead and runs from the first graphical frame
;; however that frame was made: `after-make-frame-functions' fires for all of
;; them.  It runs from a zero-delay timer, so the frame is complete and we are
;; outside `make-frame', and each function on its own, so one failure cannot
;; take the rest down.

(defvar zetta--graphic-frame-pending nil
  "Functions waiting for a graphical frame, newest first.")

(defvar zetta--graphic-frame-log nil
  "What the dispatcher saw, newest first: (TIME EVENT . DETAILS).
Kept because *Messages* does not survive a session here, and the one
time the queue never drained (2026-10-21) nothing else said why.")

(defun zetta--graphic-frame-note (event &rest details)
  "Record EVENT with DETAILS in `zetta--graphic-frame-log'."
  (push (append (list (format-time-string "%H:%M:%S.%3N") event
                      :pending (length zetta--graphic-frame-pending)
                      :graphic (and (seq-some #'display-graphic-p (frame-list)) t))
                details)
        zetta--graphic-frame-log))

(defvar zetta--graphic-frame-watch nil
  "The idle timer that drains the queue when no hook has; see below.")

(defun zetta--graphic-frame-run-pending ()
  "Run and drop every function in `zetta--graphic-frame-pending', oldest first.
Only once a graphical frame exists; otherwise the queue is left for later."
  (when (seq-some #'display-graphic-p (frame-list))
    (let ((fns (reverse zetta--graphic-frame-pending)))
      (setq zetta--graphic-frame-pending nil)
      (zetta--graphic-frame-note 'run :fns fns)
      (dolist (fn fns)
        (condition-case err
            (funcall fn)
          (error (zetta--graphic-frame-note 'failed :fn fn :error err)
                 (message "zetta: work deferred to the first frame failed: %s: %S"
                          fn err)))))
    (when (and zetta--graphic-frame-watch (null zetta--graphic-frame-pending))
      (cancel-timer zetta--graphic-frame-watch)
      (setq zetta--graphic-frame-watch nil))))

(defun zetta--graphic-frame-made (frame)
  "Schedule the pending work once FRAME, if graphical, is complete.
On `after-make-frame-functions', at the front: a function ahead of it
that signals would otherwise take it down with the rest of the hook."
  (zetta--graphic-frame-note 'frame-made :frame (framep frame)
                             :frame-graphic (display-graphic-p frame))
  (when (and zetta--graphic-frame-pending (display-graphic-p frame))
    (run-at-time 0 nil #'zetta--graphic-frame-run-pending)))

(add-hook 'after-make-frame-functions #'zetta--graphic-frame-made -100)

(defun zetta-when-graphic-frame (fn)
  "Call FN, a function of no arguments, once a graphical frame exists.
From the first one made, however it is made, when there is none yet.  When
one already exists FN still runs from a timer, a second later: a caller
that reaches for this while a frame exists wanted something more of it
than `display-graphic-p' and has nothing to gain from spinning.
Registering FN twice runs it once.

Belt and braces: while the queue waits, an idle timer looks for a
graphical frame once a second and drains the queue the moment it finds
one, so the work happens even if the frame's creation never reached
`after-make-frame-functions' -- which is what the log said about the
2026-10-21 session, with no reason found."
  (unless (memq fn zetta--graphic-frame-pending)
    (push fn zetta--graphic-frame-pending))
  (zetta--graphic-frame-note 'register :fn fn)
  (if (seq-some #'display-graphic-p (frame-list))
      (run-at-time 1 nil #'zetta--graphic-frame-run-pending)
    (unless zetta--graphic-frame-watch
      (setq zetta--graphic-frame-watch
            (run-with-idle-timer 1 t #'zetta--graphic-frame-run-pending)))))

(when (fboundp 'repeatable-wrap)
  (general-define-key
   :keymaps 'menu-run-map
   "m" (** zetta-soda-drink-messages)
   "c"  (** calendar)
   "i"  (** info)
   "M" (** zetta-soda-cap-messages)
   "I" (** zetta-soda-cap-info)))

(provide 'bootstrap-display)
;;; bootstrap-display.el ends here
