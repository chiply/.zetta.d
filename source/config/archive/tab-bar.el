;;(setq zetta-ws-cfg-tabbar-list '(
                             ;;;; car is ws cfg and cdr is list of tabs
                             ;;((main 1) . ("default"))
                             ;;))


;;(defun zetta-new-tab ()
  ;;(interactive)
  ;;(let ((tabname (completing-read "tab name: " '()))
        ;;;; is needed for rename function to work on the right tabkj?
        ;;(tab-bar-tabs-function 'tab-bar-tabs)
       ;; 
        ;;)
    ;;(tab-bar-new-tab 1)
    ;;(tab-bar-rename-tab tabname)
    ;;(setf
     ;;(alist-get
      ;;`(,(intern (car (car zetta-ws-alist))) ,(winds-get-cur-cfg))
      ;;zetta-ws-cfg-tabbar-list
      ;;nil nil 'equal)
     ;;(append
      ;;(alist-get
       ;;`(,(intern (car (car zetta-ws-alist))) ,(winds-get-cur-cfg))
       ;;zetta-ws-cfg-tabbar-list
       ;;nil nil 'equal)
      ;;`(,tabname))
     ;;)
    ;;)
  ;;)


;;(defun zetta-get-tab-bar-tabs-for-ws-cfg ()
  ;;(interactive)
  ;;(alist-get
   ;;`(,(intern (car (car zetta-ws-alist))) ,(winds-get-cur-cfg))
   ;;zetta-ws-cfg-tabbar-list
   ;;nil nil 'equal
   ;;)
  ;;)




;; what to do about default tab?

;; gets tabs for current ws cfg -- thiis shuold be the tab bar function
;; NEED CONFIG IN HERE
;;(defun zetta-tab-bar-tabs (&optional frame)
  ;;(let ((tabs (frame-parameter frame 'tabs)))
    ;;(if tabs
        ;;(let* ((current-tab (tab-bar--current-tab-find tabs))
               ;;(current-tab-name (assq 'name current-tab))
               ;;(current-tab-explicit-name (assq 'explicit-name current-tab)))
          ;;(when (and current-tab-name
                     ;;current-tab-explicit-name
                     ;;(not (cdr current-tab-explicit-name)))
            ;;(setf (cdr current-tab-name)
                  ;;(funcall tab-bar-tab-name-function))))
      ;;;; Create default tabs
      ;;(setq tabs (list (tab-bar--current-tab-make)))
      ;;(tab-bar-tabs-set tabs frame))
    ;;;; CHANGING THIS PART -- filtering for membershiip in list
    ;;(-filter
     ;;(lambda (tab) (member (cdr (assq 'name tab)) (zetta-get-tab-bar-tabs-for-ws-cfg)))
     ;;tabs)
    ;;)
  ;;)



;; LEFT OFF - use bookmark view for everything???
;; could still tie them to the work space right?
;; STILL NEED THE LEFT OFF FUCNTIONALITY, whch is a fundamentally different usecase
;; (bookmark-view-names)

;; views - snapshot views; tab views (ws cfg)

;; implement some tab switcher command like 'local bookmark'...
;; store a tab mode in could store ths in the tab bar no?






;; early signs of working...
;; doesn't work with previous tab / next tab...
;;(setq tab-bar-tabs-function 'tab-bar-tabs)

;;(tab-bar-tab-name-current)
;;(tab-bar--current-tab-find (frame-parameter (selected-frame) 'tabs))
;;(frame-parameter frame 'tabs)
;;(tab-bar--current-tab-make)


;; (funcall tab-bar-tabs-function)







