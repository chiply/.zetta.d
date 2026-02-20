;;; -*- lexical-binding: t -*-


;; LEFT OFF -- look into hercules instead since it gives better, more
;; 'integrated' hints.  keep in mind repeat mode takes a typical
;; command and turns it into a repeater... this is very different from
;; how hydra/transient/herc work
;; Also check out repeat-help for the 'integrated hints' for the repeat menu

;; philosophy
;; move towards using built-ins for most use cases.  default to adding to native emacs keymaps (eg with defvar-keymap) to leverage the existing API and existing usage of it (think how many hydra or transient like popup menus there are in emacs keymaps, both built-in and distributed).

;; key setup requirements
;; 1. easy to define keys for meow, evil, and vanilla emacs; support for general chord
;; 2. use of built-ins for simple usecases like repeat mode
;; 3. is hercules obsolete?  should support anyway
;; 4. support for bulkier UIS like transient, hydras, but only when their differential UI features are required (magit, zmc)

(defun command1 () (interactive) (message "command1"))
(defun command2 () (interactive) (message "command2"))
(defun command3 () (interactive) (message "command3"))
(defun command4 () (interactive) (message "command4"))
(defun command5 () (interactive) (message "command5"))


;;;;;;;;;;;;; REPEAT_MODE
;; use case: define a new keymap that repeats the last command, but
;; also has a few other commands that can be run -- aggregates
;; functionality from multiple features

;; can repeat-mode be temprarily turned on?
(defmacro zetta-crud-repeat-map (keymap key command &optional repeat hint)
  `(progn
     ;; bind key
     ;; todo use general instead?  what are the advantages there?
     ;; that's just an optimization
     (keymap-set ,keymap ,key ,command)
     ;; repeat
     (if ,repeat (put ,command 'repeat-map ',keymap)
       (remprop ,command 'repeat-map))
     (if ,hint (put ,command 'repeat-hint ,hint)
       (remprop ,command 'repeat-hint))))

;; define a macro that can be used to run zetta-crud-repeat-map for a set
;; of commands, supplied with the following syntax
(defmacro zetta-crud-repeat-map-set (keymap &rest commands)
  `(progn
     (when (not (keymapp ,keymap)) (defvar ,keymap))
     ,@(mapcar (lambda (command)
                 `(zetta-crud-repeat-map
                   ,keymap
                   ,(nth 0 command)
                   ,(nth 1 command)
                   ,(nth 2 command)
                   ,(nth 3 command)))
               commands)))

;; eg
;;(zetta-crud-repeat-map comma-repeat-map "1" #'command1 t "command 1")

(zetta-crud-repeat-map-set
 comma-repeat-map
 ("1" #'command1 t "command 1")
 ("2" #'command2 t "command 2")
 ("3" #'command3 t "command 3")
 ("4" #'command4 t "command 4")
 ("5" #'command5 t "command 5"))

(define-key global-map (kbd "C-+") comma-repeat-map)



;;;;;;;;;;;;;;; HERC
;; TODO -- function that takes a keyseq and keymap and creates a hercules from the keymap
;; 2 macros - 1 to create the hercules and 1 to bind it to the key
(defun herc-command1 () (interactive) (message "command1"))
(defun herc-command2 () (interactive) (message "command2"))
(use-package hercules)

;; keymap can be altered with any command -- note special ones (eg not
;; general-) need to be used for things like repeat keys, but these
;; manipulate the same keymaps
(defvar zmenu-1 (make-sparse-keymap))
(general-define-key :keymaps 'zmenu-1 "1" 'herc-command1 "2" 'herc-command2)

;; INPUT: keymap (zmenu-1)
;;(hercules-def :toggle-funs #'zmenu-1-fun :keymap 'zmenu-1 :transient t)
(hercules-def :toggle-funs 'zmenu-1-fun :keymap 'zmenu-1 :transient t)
(define-key global-map (kbd "C-=") 'zmenu-1-fun)

;; macro to bind a key to a keymap -- it creates the herc-def if it doesn't exist already
;; TODO commit then start migrating -- 1 create the macro -- 2 replace all defhydras with general-define-key -- 3 replace all general


;;;;;;;;;;; UI

;; hydra
;; transient
;; hydra-registry


;;;;; get repeat maps on demand...
;;;; still clunky though
(defun repeated-prefix-help-command ()
  (interactive)
  (when-let* ((keys (this-command-keys-vector))
              (prefix (seq-take keys (1- (length keys))))
              (orig-keymap (key-binding prefix 'accept-default))
              (keymap (copy-keymap orig-keymap))
              (exit-func (set-transient-map keymap t #'which-key-abort)))
    (define-key keymap [remap keyboard-quit]
                (lambda () (interactive) (funcall exit-func)))
    (which-key--create-buffer-and-show nil keymap)))
;;(setq prefix-help-command #'repeated-prefix-help-command)


;; keymap can be altered with any command -- note special ones (eg not
;; general-) need to be used for things like repeat keys, but these
;; manipulate the same keymaps
(defun repeater-command1 () "really useful docstring" (interactive) (message "command1"))
(defun repeater-command2 () "really useful docstring" (interactive) (message "command2"))
(defvar repeater-demo (make-sparse-keymap))
(define-key repeater-demo "1" 'repeater-command1)
(define-key repeater-demo "2" 'repeater-command2)
(define-key repeater-demo "3"
            (lambda ()
              (interactive)
              (completing-read "test" '("a" "b" "c" "d" "e" "f" "q"))))
(define-key repeater-demo "44" (lambda () (interactive) (message "44")))
(defvar repeater-demo2 (make-sparse-keymap))
(define-key repeater-demo2 "1" 'repeater-command1)



;; NOTE -- got which key piece working!  It's a matter of setting which keys display action to dispkay-buffer-no-window, then using `which-key--create-buffer-and-show` to show without waiting for keyboard input from the user, so the we can defer the display of the buffer to display-buffer.  note this also allows us to aviod the issue running cimpleting re
;; TODO not working on multiple
(repeater repeater-demo)
(repeater repeater-demo2)


