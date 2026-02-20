;; LEFT OFF

;; this is really adding a 3rd dimension, and the xtra feature for the
;; use case of 'rewinding' to a 'snapshot' that can be created on the
;; fly.

;; todo - my own implementation using winner and ht, based on
;; progressive subdivision of workspaces

;; todo: test persisting (start inicludng wiinds again)
;; similar semantics for the winds spaces tabs, previous, swtich etc...
;; order of the views... should be reversed
;; how to handle renaming, deleting, etc...

;;;;;;;;;;;;;;;;;;;;;; Snapshots
(defun zetta-strip-text-properties (str)
  (let* ((foo    str)
         (start  0)
         (end    (length foo)))
    (set-text-properties start end nil foo)
    foo)
  )

(defun zetta-get-snapshots ()
  (let ((snapshots (-filter
                    (lambda (bm-view-name)
                      (string-match "snapshot-*" bm-view-name ))
                    (bookmark-view-names)
                    )))
    (when snapshots (-map
                     (lambda (snapshot) (zetta-strip-text-properties snapshot))
                     snapshots
                     ))
    )
  )

(defun zetta-delete-snapshots ()
  (interactive)
  (-map
   (lambda (x) (bookmark-view-delete x))
   (zetta-get-snapshots)
   )
  )


(defun snapshot-lessp (string1 string2)
  (let (
        (string1_number (string-to-number (car (last (split-string string1 "-")))))
        (string2_number (string-to-number (car (last (split-string string2 "-")))))
        )
    (< string1_number string2_number)
    )

  )

(defun zetta-bookmark-view-generate-snapshot-name ()
  ;; get names
  (let* ((snapshots (zetta-get-snapshots)))
    (if snapshots
        (progn 
          (setq snapshots-sorted (cl-sort snapshots 'snapshot-lessp))
          (concat
           "snapshot-"
           (number-to-string (+ 1 (string-to-number
                                   (car (last (split-string
                                               (car (last (cl-sort snapshots-sorted 'snapshot-lessp))) "-"))))))))
      "snapshot-1")))


(tab-bar-mode +1)


;;;;;;;;;;;;; ws-cfg views
(setq zetta-ws-cfg-bv-list '(
                         ;; car is ws cfg and cdr is a bookmark view (bv)
                         ((main 1) . ("bv--main-1: default"))
                         ))
(setq zetta-ws-cfg-bv-current-bv "bv--main-1: default")

(setq zetta-ws-cfg-bv-leftoff '())

;;(add-to-list 'desktop-globals-to-save 'zetta-ws-cfg-bv-list)
;;(add-to-list 'desktop-globals-to-save 'zetta-ws-cfg-bv-leftoff)
;;(add-to-list 'desktop-globals-to-save 'zetta-ws-cfg-bv-current-bv)


(defun zetta-ws-cfg-bvs ()
  (alist-get
   `(,(intern (car (car zetta-ws-alist))) ,(winds-get-cur-cfg))
   zetta-ws-cfg-bv-list
   nil nil 'equal)
  )


(defun zetta-ws-cfg-bv-new-bv (&optional name)
  (interactive)
  ;;;; pre
  ;; save current bookmark
  (bookmark-view-save zetta-ws-cfg-bv-current-bv)
  ;; rest
  (let* ((name (or name (completing-read "bv name" '())))
         (bvprefix "bv--")
         (bm-full-name (concat bvprefix (car (car zetta-ws-alist)) "-" (number-to-string (winds-get-cur-cfg)) (format ": %s" name))))
    (bookmark-view-save bm-full-name)
    (setf
     (alist-get
      `(,(intern (car (car zetta-ws-alist))) ,(winds-get-cur-cfg))
      zetta-ws-cfg-bv-list
      nil nil 'equal)
     (append
      (alist-get
       `(,(intern (car (car zetta-ws-alist))) ,(winds-get-cur-cfg))
       zetta-ws-cfg-bv-list
       nil nil 'equal)
      `(,(concat bvprefix (car (car zetta-ws-alist)) "-" (number-to-string (winds-get-cur-cfg)) ": " name))))
    ;;(bookmark-view-open bm-full-name)
    (setq zetta-ws-cfg-bv-current-bv bm-full-name)))


;; create the initional bookmark
(zetta-ws-cfg-bv-new-bv "default")


(defun zetta-ws-cfg-bv-switch (&optional name)
  (interactive)
  ;; save current buffer state
  (bookmark-view-save zetta-ws-cfg-bv-current-bv)
  ;; should be switch or create
  (let* ((name (or name (completing-read "select a tab: " (zetta-ws-cfg-bvs))))
         (bvprefix "bv--"))
    (if (member name
                (alist-get
                 `(,(intern (car (car zetta-ws-alist))) ,(winds-get-cur-cfg))
                 zetta-ws-cfg-bv-list nil nil 'equal))
        (progn
          ;; switch to the bookmark
          (bookmark-view name)
          (setq zetta-ws-cfg-bv-current-bv name))
      (progn
        (zetta-ws-cfg-bv-new-bv name)
        (setq zetta-ws-cfg-bv-current-bv
              (concat
               bvprefix
               (car (car zetta-ws-alist))
               "-"
               (number-to-string (winds-get-cur-cfg))
               (format ": %s" name)))))))


;; need to introduce the notion of a current bookmark... note the leftoff functionality here
;; define update current bookmark
(defun zetta-propertize-tab-bar-string-tab (str)
  (if (string= str zetta-ws-cfg-bv-current-bv)
      ;;; ughh... need to modify the text to make the tab bar update
      ;;; immediately... this is an annoyance!  all caps is a good
      ;;; workaround
      (concat (propertize (upcase (nth 1 (split-string str ": "))) 'face 'focus-focused))
    (propertize (nth 1 (split-string str ": ")) 'face 'focus-unfocused)))

(defun zetta-tab-bar-bvs ()
  (let ((ws-cfg-bvs (zetta-ws-cfg-bvs))) 
    (-filter (lambda (x) (member x ws-cfg-bvs)) (bookmark-view-names))))

;; redefined from winds.el
(defun winds-get-status-msg ()
  "Display a status message in the echo area with the current ws id and cfg id."
  (interactive)
  (let* ((wsids  (sort (winds--get-wsids) #'<))
         (cfgids (sort (winds--get-cfgids) #'<))
         (bg       (face-attribute 'mode-line-inactive :background))
         (sel-fg   (face-attribute 'mode-line :foreground))
         (unsel-fg (face-attribute 'mode-line-inactive :foreground))
         (sel-face   `(:background ,bg :foreground ,sel-fg))
         (unsel-face `(:background ,bg :foreground ,unsel-fg))
         (msg-left (mapcar
                    (lambda (id) (if (eq id (winds-get-cur-ws))
                                     (propertize (format "%s " id) 'face sel-face)
                                   (propertize (format "%s " id) 'face unsel-face)))
                    wsids))
         (msg-right (mapcar
                     (lambda (id) (if (eq id (winds-get-cur-cfg))
                                      (propertize (format " %s" id) 'face sel-face)
                                    (propertize (format " %s" id) 'face unsel-face)))
                     cfgids))
         (msg-left  (cl-reduce #'concat msg-left))
         (msg-right (cl-reduce #'concat msg-right))
         (msg-left  (concat (propertize "W " 'face unsel-face) msg-left))
         (msg-right (concat msg-right (propertize " C" 'face unsel-face))))
    (format "%s|%s" msg-left msg-right)
    ;; Don't spam *Messages*
    ))



(defun zetta-tab-bar-string ()
  (concat
   " { "
   (winds-get-status-msg)
   "  [" (mapconcat 'zetta-propertize-tab-bar-string-tab (zetta-tab-bar-bvs) " | ") "]"
   " }"))

(defun zetta-ws-cfg-bv-switcher (dir)
  (let* ((current-index (cl-position zetta-ws-cfg-bv-current-bv (zetta-tab-bar-bvs) :test 'equal))
         (previous-index (- current-index 1))
         (next-index (+ current-index 1))
         (previous-tab (if (>= previous-index 0)
                           (nth previous-index (zetta-tab-bar-bvs))
                         (or (car (last (zetta-tab-bar-bvs) 1))
                             ;; handles case when len = 1
                             (car (zetta-tab-bar-bvs))
                             )))
         (next-tab (or (nth next-index (zetta-tab-bar-bvs)) (car (zetta-tab-bar-bvs)))))
    (cond
     ((string= dir "prev") (zetta-ws-cfg-bv-switch previous-tab))
     ((string= dir "next") (zetta-ws-cfg-bv-switch next-tab)))))     

;; works nicely!
;;(general-define-key
 ;;:keymaps 'override
 ;;:states '(normal visual)
 ;;"C-M-S-<tab>" (lambda () (interactive) (zetta-ws-cfg-bv-switcher "prev"))
 ;;"C-M-<tab>" (lambda () (interactive) (zetta-ws-cfg-bv-switcher "next"))
 ;;"g t" (lambda () (interactive) (zetta-ws-cfg-bv-switch))
 ;;)


(defun zpath ()
  (let ((path (abbreviate-file-name default-directory)))
    (if (> (length path) 30)
        (zetta-minify-path default-directory)
      path
      )
    ))

(defun zwhitespace () (let ((x " ")) x))

(defun zetta-org-outline-path ()
  (when
      (string= major-mode "org-mode")
    (concat " > " (org-display-outline-path) "/" (org-get-heading))))

;; the interface to making snapshoots -- using consuot bookmark to
;; access them
(defun zetta-bookmark-view-snapshot ()
  (interactive)
  (let* ((name (zetta-bookmark-view-generate-snapshot-name))
         (snapshotname (zetta-bookmark-view-generate-snapshot-name)))
    (bookmark-view-save snapshotname) 
    ;; fixes strange issue caused by savnig the bookmark
    (bookmark-view snapshotname)
    )
  )




