;;; -*- lexical-binding: t -*-


;; TODO can't drill down when prefix is in the map that you launch
;; which key from, works if you do C-h u then drill down though, not
;; sure why


;; TODO way to run some action when enterin a keymap -- iedit is a
;; good use case for this. -- might need to change the defprefix
;; function -- there could be a simpler way to do this given that we
;; can bind keys to the prefix commands... actually prefixes can't be
;; called directly

;; TODO when calling a nested keybinding using embark, it resets the
;; prefix key to wherever embark-bindings-in-keymap was called from.
;; This might be preferable behavior

;;; LEFTOFF testing this out by replacing window menu...

;; TODO cleanup hydra

;; TODO cleanup menu stuff, but keep 1 example

;; TODO when entering help from outside repeatable loop, don't get aut
;; updating

;; NOTE i think I have this actually working, including the universal
;; arg stuff.  I think I even have a way to do capturing of last key
;; from outside of repeatable, but likely won't implement this.  Next
;; step is to test and document current functionality / any drawbacks

;; NOTE - accepting this as a tradeoff for now -- calling a non
;; repeatable after typing C-u doesn't quit which key -- can I have
;; process-undefined-key-sequence point back to my-read-key-sequence?
;; might not work or might get the recursion error due to universal
;; args being supplied -- which could also mean I can't use read key
;; in the undefined key sequence thing... i tried fixing this with
;; post-command-hook and using a which-key-protext variable but I
;; wasn't able to do it

;; NOTE given the setup for C-g, repeating can be complicated when
;; executing completing read commands and exiting, since they press
;; C-g, should figure out a work around but also consider this an edge
;; case for now.

(defvar repeatable-current-prefix nil "The current prefix key sequence.")

(defun which-key-settings ()
  (which-key-mode -1)
  (setq which-key-idle-delay 0.1)
  (setq which-key-idle-secondary-delay 0.1)
  (setq which-key-persistent-popup t)
  (which-key-mode +1))


(advice-add 'which-key-C-h-dispatch :before 'which-key-settings)


(defun prefix-help-command-which-key (&optional key-seq)
  (interactive)
  (setq prefix-help-command 'which-key-C-h-dispatch)
  (which-key--create-buffer-and-show key-seq)
  (which-key-reload-key-sequence key-seq)
  (my-read-key-sequence))


(defun my-embark-bindings-in-keymap (km prefix)
  (setq repeatable-current-prefix prefix)
  (let ((command (consult--read
                  (car (embark--formatted-bindings km))
                  :prompt "foo: "
                  :category 'embark-keybinding)))
    (call-interactively (intern (car (last (string-split command)))))))


(defun repeatable-lite-versatile-C-h ()
  (interactive)
  (let* ((keys (this-command-keys-vector))
         (prefix (seq-take keys (1- (length keys))))
         (orig-km (key-binding prefix 'accept-default))
         (km (copy-keymap orig-km))
         (key (read-key
               (concat "C-h (which-key),"
                       "C-H (embark), "
                       " or M-S-h (describe-prefix-bindings):"))))
    (cond ((eq key ?\C-h) (prefix-help-command-which-key prefix))
          ((eq key ?\C-\S-h) (my-embark-bindings-in-keymap km prefix))
          ;; TODO invalid seq?
          ;;((eq key ?\M-\S-h) (describe-prefix-bindings)) 
          (t (message "Invalid key")))))


(defun reload-key-sequence (key-seq)
  (let ((next-event (mapcar (lambda (ev) (cons t ev)) key-seq)))
    (setq prefix-arg current-prefix-arg
          unread-command-events next-event)))


(defun kill-which-key-and-unpersist ()
  (interactive)
  (message "quit which key")
  ;; kill the buffer
  (let ((buf (get-buffer which-key-buffer-name)))
    (when (bufferp buf) (kill-buffer buf)))
  ;; disable persistent popup
  (setq which-key-persistent-popup nil)
  ;; NOTE if we don't kill the timers, then which key buffer will pop
  ;; back up when entering a global prefix from within a repeatable
  ;; function
  (when (and (boundp 'which-key--timer) (timerp which-key--timer))
    (cancel-timer which-key--timer))

  ;; settings
  (which-key-mode -1)
  (setq which-key-idle-delay 10000)
  (setq which-key-idle-secondary-delay 0.01)
  (setq which-key-persistent-popup t)
  (which-key-mode +1)

  ;; reset prefix help command
  (setq prefix-help-command 'repeatable-lite-versatile-C-h)

  ;; reset prefix arg
  (setq current-prefix-arg nil))


(defun process-undefined-key-sequence (&optional ksv)
  (let* ((ksv (or ksv (this-single-command-keys)))
         (last-key-vector (vector (aref ksv (1- (length ksv)))))
         (last-key (key-description last-key-vector)))
    (cond
     ((string= last-key "C-u")
      (setq current-prefix-arg
            (list (* 4 (or (car current-prefix-arg) 1))))
      (reload-key-sequence
       (vconcat
        (make-vector
         (cond
          ((equal (car current-prefix-arg) 4) 1)
          ((equal (car current-prefix-arg) 16) 2)
          ((equal (car current-prefix-arg) 64) 3)
          ((equal (car current-prefix-arg) 256) 4))
         21)
        (seq-take ksv (1- (length ksv))))))
     (t (kill-which-key-and-unpersist)))))


(defun my-read-key-sequence ()
  (let* ((ksv (read-key-sequence-vector nil))
         (last-key-vector (vector (aref ksv (1- (length ksv)))))
         (last-key (key-description last-key-vector))
         (key (key-description ksv))
         (local-binding (keymap-lookup nil key))
         (global-binding (keymap-lookup nil last-key)))
    (cond
     ((string= last-key "C-u") (process-undefined-key-sequence ksv))
     ((string= last-key "C-h") (funcall prefix-help-command))
     ;;((string= last-key "C-g") (keyboard-quit))
     (local-binding
      ;; run kill-which-key-and-unpersist if the local-binding is not
      ;; a repeatable
      (unless (condition-case nil
                  (string-match "^\\*" (symbol-name local-binding))
                (error nil))
        (kill-which-key-and-unpersist))
      (call-interactively local-binding))
     (global-binding
      (cond
       ((keymapp global-binding)
        (kill-which-key-and-unpersist)
        (reload-key-sequence last-key-vector)
        (setq prefix-help-command 'repeatable-lite-versatile-C-h))
       (t 
        (kill-which-key-and-unpersist)
        (execute-kbd-macro last-key-vector)
        (setq prefix-help-command 'repeatable-lite-versatile-C-h))))
     ((string= last-key "C-S-x")
      (kill-which-key-and-unpersist)
      (reload-key-sequence [24])
      (setq prefix-help-command 'repeatable-lite-versatile-C-h))
     (t
      (message "No binding in local or global maps %s" key)
      (kill-which-key-and-unpersist)))))


(defmacro ** (function)
  `(defun ,(intern (format "**%s" function)) ()
     (interactive)
     (let* ((keys (this-command-keys-vector))
            (prefix (or repeatable-current-prefix
                        (seq-take keys (1- (length keys))))))
       ;; call the function
       (call-interactively ',function)

       ;; settings
       (setq repeatable-current-prefix nil)
       (setq current-prefix-arg nil)
       (reload-key-sequence prefix)
       (unless (bufferp (get-buffer which-key-buffer-name))
         (setq prefix-help-command 'repeatable-lite-versatile-C-h))
       (my-read-key-sequence))))


(advice-add #'keyboard-quit :before #'kill-which-key-and-unpersist)
(advice-add #'undefined :override #'process-undefined-key-sequence)


;; Usage
(defun bar () (interactive) (message "bar"))
(defun foo (&optional arg) (interactive "P") (if arg (message "foo") (message "FOO")))
(defun baz () (interactive) (completing-read "foo" '("foo" "bar")))

;; NOTE there must be a valid prefix defined
(general-define-key
 :keymaps 'override
 "C-c o M" (** bar)
 ;; works on functions with prefix args
 "C-c o m" (** foo)
 ;; regular way to bind function
 "C-c o P" 'foo
 "C-c o x p" 'foo
 ;; works on functions which bring up completing read
 "C-c o c" (** baz)
 ;; works with lambdas
 "C-c o l" (** (lambda () (interactive) (message "hi") ))
 )


(provide 'repeatable-lite)
