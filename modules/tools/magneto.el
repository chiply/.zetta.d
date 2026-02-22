;;; magneto.el --- Configure magneto -*- lexical-binding: t; -*-

;; FIRST: make 1) embark-action and 2) magneto-action sequential, with embark action being optional

;; move general to the config layer

(defun magneto-avy-read (initial-input tree display-fn cleanup-fn)
  (catch 'done
    (setq avy-current-path initial-input)
    ;; set counter
    (setq counter 0)
    (while tree
      ;; increment counter
      (setq counter (+ 1 counter))
      (let ((avy--leafs nil))
        (avy-traverse tree
                      (lambda (path leaf)
                        (push (cons path leaf) avy--leafs)))
        (dolist (x avy--leafs)
          (funcall display-fn (car x) (cdr x))))
      (let ((char (funcall
                   avy-translate-char-function
                   (if (eq counter 1)
                       ;; first time round, give the sequence literally
                       (cond
                        ((string-equal initial-input "a") 97)
                        ((string-equal initial-input "s") 115)
                        ((string-equal initial-input "d") 100)
                        )
                     (read-key))))
            window
            branch)
        (funcall cleanup-fn)
        (if (setq window (avy-mouse-event-window char))
            (throw 'done (cons char window))
          (if (setq branch (assoc char tree))
              (progn
                ;; Ensure avy-current-path stores the full path prior to
                ;; exit so other packages can utilize its value.
                (setq avy-current-path
                      (concat avy-current-path (string (avy--key-to-char char))))
                (if (eq (car (setq tree (cdr branch))) 'leaf)
                    (throw 'done (cdr tree))))
            (funcall avy-handler-function char)))))))

;; Adapted from aw-select
(defun magneto-ace-get-window (initial-input)
  (interactive)
  "Selecting with ace window"
  (let* ((wnd-list (aw-window-list))
         (candidate-list
          (mapcar (lambda (wnd)
                    (cons (aw-offset wnd) wnd))
                  wnd-list))
         (win (cdr (magneto-avy-read initial-input (avy-tree candidate-list aw-keys)
                                     (if (and ace-window-display-mode
                                              (null aw-display-mode-overlay))
                                         (lambda (_path _leaf))
                                       aw--lead-overlay-fn)
                                     aw--remove-leading-chars-fn))))
    win))

;; Defaults
(setq magneto-default-source-action "move"
      magneto-default-destination-action "f"
      magneto-default-select-action "o"
      magneto-default-action-action "switch-buffer"
      magneto-default-destination-window nil
      magneto-default-embark-candidate nil
      magneto-default-embark-action nil)

(defun magneto-make-indirect ()
  (interactive)
  (switch-to-buffer
   (clone-indirect-buffer
    (format "*indirect--%s*" (buffer-name (current-buffer)))
    nil)))

(defun magneto-restore-defaults ()
  (interactive)
  (setq magneto-source-action magneto-default-source-action
        magneto-destination-action magneto-default-destination-action
        magneto-select-action magneto-default-select-action
        magneto-action-action magneto-default-action-action
        magneto-destination-window magneto-default-destination-window
        magneto-embark-candidate magneto-default-embark-candidate
        magneto-embark-action magneto-default-embark-action))

;; Instantiates the variables from Defaults
(magneto-restore-defaults)

(defun magneto-move-after-select (buf-orig)
  (cond
   ((string= magneto-destination-action "f") nil)
   ((string= magneto-destination-action "V") (split-window))
   ((string= magneto-destination-action "v") (split-window) (windmove-down))
   ((string= magneto-destination-action "H") (split-window-horizontally))
   ((string= magneto-destination-action "h") (split-window-horizontally) (windmove-right)))
  (cond
   ;; switch-buffer is candidateless, this would never be supplied by
   ;; embark
   (magneto-embark-action (if magneto-embark-candidate
                              (funcall magneto-embark-action magneto-embark-candidate)
                            (funcall magneto-embark-action)))
   ((string= magneto-action-action "switch-buffer")
    (switch-to-buffer buf-orig))
   ;; candidates possibly coming from embark
   ((string= magneto-action-action "execute-command")
    (call-interactively (execute-extended-command nil)))
   ((string= magneto-action-action "find-file")
    (call-interactively 'find-file))
   ((string= magneto-action-action "consult-buffer")
    (consult-buffer)))
  (selected-window))

(defun magneto-select-win-dest-ace (buf-orig)
  (if magneto-destination-window
      ;; if a window was specified already...
      (progn
        (select-window magneto-destination-window)
        (magneto-move-after-select buf-orig))
    ;; otherwise, invoke ace-window now
    (aw-select "Select a window!: "
               (lambda (window)
                 (aw-switch-to-window window)
                 (magneto-move-after-select buf-orig)))))

(defun magneto-select-win-dest-side (buf-orig)
  (let ((side (cond
               ((member magneto-destination-action '("t" "T")) 'top)
               ((member magneto-destination-action '("b" "B")) 'bottom)
               ((member magneto-destination-action '("r" "R")) 'right)
               ((member magneto-destination-action '("l" "L")) 'left)))
        (slot (cond
               ((member magneto-destination-action '("t" "b" "r" "l")) 10)
               ((member magneto-destination-action '("T" "B" "R" "L")) -10)))
        ;; NOTE: kind of mind-boggling -- not sure why other entries in
        ;; display-buffer-alist are having an affect here.  This is a
        ;; good general note, for the future.  Whenever using
        ;; display-buffer directly, probably want to clear
        ;; display-buffer-alist
        (display-buffer-alist nil)
        )
    (display-buffer
     buf-orig
     `((display-buffer-in-side-window)
       (side . ,side)
       (slot . ,slot)
       (window-parameters . ((no-delete-other-windows . 1)))))))

(defun magneto-select-win-dest (buf-orig)
  (cond
   ((member magneto-destination-action '("f" "V" "v" "H" "h"))
    (magneto-select-win-dest-ace buf-orig))
   ((member magneto-destination-action '("t" "T" "b" "B" "r" "R" "l" "L"))
    ;; Note: returns the window
    (magneto-select-win-dest-side buf-orig))))

(defun magneto-process-source (win-orig)
  ;; temporarily switch to a different buffer in win-orig.  we should create this buffer
  (cond
   ((string= magneto-source-action "move") (delete-window win-orig))
   ((string= magneto-source-action "pull") (switch-to-prev-buffer win-orig))
   ((string= magneto-source-action "copy") nil)))

(defun magneto-process-select (win-orig win-dest)
  (cond
   ((string= magneto-select-action "o") (select-window win-dest))
   ((string= magneto-select-action "O") (select-window win-orig))))

(defun magneto-move (&optional repeat)
  (interactive)
  (let* ((buf-orig (current-buffer))
         (win-orig (selected-window))
         ;; CREATE-MAYBE
         (win-dest (magneto-select-win-dest buf-orig)))
    ;;;; CLEAN-MAYBE
    (magneto-process-source win-orig)
    ;;;; PLACE-CURSOR
    (magneto-process-select win-orig win-dest))
  (magneto-restore-defaults))

(defun magneto-set-magneto-source-action (setting)
  (interactive)
  (setq magneto-source-action setting))

(defun magneto-set-magneto-destination-action (setting)
  (interactive)
  (setq magneto-destination-action setting))

(defun magneto-set-magneto-selection-action (setting)
  (interactive)
  (setq magneto-selection-action setting))

(defun magneto-set-magneto-action-action (setting)
  (interactive)
  (setq magneto-action-action setting))

(defun magneto-set-magneto-destination-window (setting)
  (interactive)
  (setq magneto-destination-window (magneto-ace-get-window setting)))

(define-prefix-command 'magneto-map)
(general-define-key
 :keymaps 'magneto-map
 "s-m" 'magneto-move
 "<return>" 'magneto-move

 ;; source actions
 "m" (** (lambda () (interactive) (magneto-set-magneto-source-action "move")))
 "c" (** (lambda () (interactive) (magneto-set-magneto-source-action "copy")))
 "p" (** (lambda () (interactive) (magneto-set-magneto-source-action "pull")))

 ;; destniation actions
 "0" (** (lambda () (interactive) (magneto-set-magneto-destination-action "f")))
 "h" (** (lambda () (interactive) (magneto-set-magneto-destination-action "h")))
 "H" (** (lambda () (interactive) (magneto-set-magneto-destination-action "H")))
 "v" (** (lambda () (interactive) (magneto-set-magneto-destination-action "v")))
 "V" (** (lambda () (interactive) (magneto-set-magneto-destination-action "V")))
 "t" (** (lambda () (interactive) (magneto-set-magneto-destination-action "t")))
 "T" (** (lambda () (interactive) (magneto-set-magneto-destination-action "T")))
 "b" (** (lambda () (interactive) (magneto-set-magneto-destination-action "b")))
 "B" (** (lambda () (interactive) (magneto-set-magneto-destination-action "B")))
 "l" (** (lambda () (interactive) (magneto-set-magneto-destination-action "l")))
 "L" (** (lambda () (interactive) (magneto-set-magneto-destination-action "L")))
 "r" (** (lambda () (interactive) (magneto-set-magneto-destination-action "r")))
 "R" (** (lambda () (interactive) (magneto-set-magneto-destination-action "R")))

 ;; selection actions
 "o" (** (lambda () (interactive) (magneto-set-magneto-selection-action "o")))
 "O" (** (lambda () (interactive) (magneto-set-magneto-selection-action "O")))

 ;; action actions
 "w" (** (lambda () (interactive) (magneto-set-magneto-action-action "consult-buffer")))
 "x" (** (lambda () (interactive) (magneto-set-magneto-action-action "execute-command")))
 "f" (** (lambda () (interactive) (magneto-set-magneto-action-action "find-file")))
 "C-b" (** (lambda () (interactive) (magneto-set-magneto-action-action "switch-buffer")))

 ;; note only a-d are used for ace
 "a" (** (lambda () (interactive) (magneto-set-magneto-destination-window "a")))
 "s" (** (lambda () (interactive) (magneto-set-magneto-destination-window "s")))
 "d" (** (lambda () (interactive) (magneto-set-magneto-destination-window "d"))))

;; embark integration
(defun my/embark-magneto-action (keymap action key-sequence)
  ;; define a functions and bind it to a key
  (let ((function-name (intern (concat "my/embark-magneto-" (symbol-name action)))))
    `(progn
       (defun ,function-name ()
         (interactive)
         (with-demoted-errors "%s"
           (magneto-restore-defaults)
           (magneto-set-magneto-source-action "copy")
           ;; set candidate and action
           (setq magneto-embark-candidate (read-from-minibuffer ""))
           (setq magneto-embark-action ',action)
           (hydra-magneto/body)))
       (condition-case nil
           (define-key ,keymap ,(kbd (concat "s-o " key-sequence)) ',function-name)
         (error (message ,(concat
                           (symbol-name keymap)
                           " "
                           (symbol-name function-name)
                           " didn't work")))))))

(defun magneto-embark-export ()
  (interactive)
  (call-interactively 'embark-export)
  (hydra-magneto/body))

;; embark general map
(general-define-key :keymaps 'override "s-m" 'magneto-map)

;;;;;; experimenting with getting keymap data:
(defun parse-keymap (keymap &optional prefix)
  (let (result)
    (map-keymap
     (lambda (key command)
       (let* ((key-str (single-key-description key))
              (new-prefix (if prefix (concat prefix " " key-str) key-str)))
         (if (keymapp command)
             (setq result
                   (append result
                           (parse-keymap
                            command
                            (replace-regexp-in-string " " "-" new-prefix))))
           (push (list command new-prefix) result))))
     keymap)
    (nreverse result)))

;;;; filter out digit arguments
;;;; filter out magneto actoins
(defun my/embark-bind-keys (keymap)
  (-map
   (lambda (x)
     (eval (my/embark-magneto-action keymap (car x) (cadr x))))
   ;; filtered list of keymaps
   (-filter
    (lambda (x)
      (and
       ;; Binding only certain commands, but looking in every keymap.
       ;; moving away from creating a magneto for everything
       (or
        (s-contains? "find-file" (symbol-name (car x)))
        (s-contains? "consult-bookmark" (symbol-name (car x)))
        (s-contains? "goto-grep" (symbol-name (car x)))
        )
       ;; avoid rebinding digit arg / my/embark
       (not (or
             (s-contains? "digit-arg" (symbol-name (car x)))
             ;; TODO collect and export should work
             ;;(s-contains? "collect" (symbol-name (car x)))
             ;;(s-contains? "export" (symbol-name (car x)))
             ;;(s-contains? "become" (symbol-name (car x)))
             (s-contains? "my/embark" (symbol-name (car x)))
             (s-contains? "embark-org-link-map" (symbol-name (car x)))))
       )
      )
    (parse-keymap (eval keymap)))))

(defun zetta-embark-bind-keys ()
  (setq embark-maps-list (-map (lambda (x) (if (listp (cdr x)) (car (cdr x)) (cdr x))) embark-keymap-alist))
  (-map (lambda (x)
          (condition-case nil
              (progn (my/embark-bind-keys x))
            (error nil)))
        embark-maps-list)
  )

(add-hook 'elpaca-after-init-hook (lambda () (when (require 'embark nil t) (zetta-embark-bind-keys))))
;;; magneto.el ends here
