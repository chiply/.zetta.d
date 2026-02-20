;;; -*- lexical-binding: t -*-

;; TODO migrate all hydras to menus

;; TODO nested menus go back to the previous menu?  this could be a
;; complex feature....


;; NOTE interesting exercise in completely alternative implementation
;; drawback to this approach is not being able to 'escape' out of a
;; menu by pressing a key outside of it although there could be a way
;; to build this in?
;;(defun foo () (interactive) (message "foo"))
;;(defun bar () (interactive) (message "bar"))
;;(setq which-key-persistent-popup t)
;;(defmacro repeatable (function)
;;`(lambda ()
;;(interactive)
;;(let* ((keys (this-command-keys-vector))
;;(prefix (seq-take keys (1- (length keys))))
;;(orig-km (key-binding prefix 'accept-default))
;;(km (copy-keymap orig-km)))
;;(,function)
;;(which-key-reload-key-sequence prefix))))
;;(general-define-key :keymaps 'override "C-c o m" (repeatable foo) "C-c o M" (repeatable bar))


;; NOTE on using repeat map we can see repeat mode does a similar
;; thing to menu -- once the repeat mode is active, the prefix is
;; tossed out... this contributes to similar issues with which-key:

;;(setq which-key-persistent-popup t)
;;(defun zfun1 () (interactive) (message "one"))
;;(defun zfun2 () (interactive) (message "two"))
;;(defvar-keymap zetta-repeat-map :repeat t "1" 'zfun1 "2" 'zfun2)
;;(general-define-key :keymaps 'override "C-c @" zetta-repeat-map)


;; TODO document decision to not create hydra/transient helpers:
;; basically we already have which-key and completing read interface;
;; hydra/transient would be redundant and we also wouldn't be using
;; the full power of those packages, which are more designed to be
;; complex forms where state can be changed and persisted across
;; invokations and even emacs sessions, and where certain key-chords
;; can 'exit' while others do not

;; NOTE design consideration re transient maps not showing their full
;; history -- would repeats do this?  but wouldn't repeat maps involve
;; moving away from using regular keymaps for this?  Or could you
;; still copy the keymap to make a repeating version?

;; NOTE still think I'm not fully leveraging built-in
;; keybindings... when I bind to maps I'm binding the menu function,
;; not the map itself -- is that even possible without a repeater
;; (TODO)?  something like 'prefix command'... but think about things
;; I'm missing out on (eg full whic-key integration)

;; WHICH KEY ISSUES----------

;; NOTE -- actually DIDN"T SOLVE WHICH KEY FOR VERSATILE CH"
;; yet... post-command hook is local, so doesn't work elsewhere

;; NOTE -- leaving the below intact -- update got which key interface
;; working from versatile-C-h... this is very challenging because of
;; how which key is hijacking the C-h and prefix help command, also
;; other huge issues with which-key... the solution is also a
;; frustrating one as it involves significant config in which-key, I
;; alread hada signifcant config in which key to support menu's use of
;; it.  The difficulty of integrating which key will likely make this
;; unpublishable as a package, unless I'm willing to decouple two, or
;; simply provide the which key helper as optional config -- enabling
;; that would require me to make versatile-C-h configurable in this
;; manner (another TODO).  The main todo for now is to make which key
;; work from menu

;; LEFTOFF - mostly working, but C-h doesn't work in which key from
;; menu... also, even when i can get the which key help up things like
;; toggle docstrings doesn't work because it goes back to the SEQUENCE
;; which is top level, not the keymap... another reason why maybe
;; which key shouldn't really be integrated as a helper here...
;; potential design choice would be to keep which key for versatile
;; c-h and abandon for menu...  justifiable -- value in which key
;; interface is being able to explore keymaps... not really as
;; important with menus which are standalone, narrower scope

;; NOTE important as well to realize that the menus are actually no
;; preserviing all the key presses, -- eg ,wh is ,w setting a
;; transient map, then h is a keybinding within that map. you wouldn't
;; be able to which key undo up to , and select a different menu for
;; exmple

;; NOTE in the from menu which key, C-h is still bound to embark...
;; that's actually a binding in the keymap which nullified C-h (see
;; docs)... really need a different keymap for the versatile-C-h


;; TODO which-key issue, when calling which key from menu, can't use
;; C-h to dispatch which-key help (scroll, undo key etc...)

;; TODO some kind of undo-key, like there is in which key.  This would
;; be used for both nested maps as well as cases where there are
;; key-sequences (not just single key presses) in the active
;; map... maybe have to escape into which-key to accomplish this?
;; would that interfere with the map being maintained by menu?  TODO
;; first would be wise to have a mode line indicator of what the
;; current prefix is as so I can actually see the key being undone.  I
;; think which-key gives feedback for this, but embark doesn't TODO:
;; note that with my current config, which-key-undo isn't actually
;; working itself... not sure what's going on.  Also undo brings to
;; top level unconditionally, might be something to do with resetting
;; the transient map... TODO 

;; TODO really need to strip back which key config and start
;; over... see if I can get undo key and other behavior
;; working... maybe could have the which key always appear? would that
;; be the end of the world?

;; -------------WHICH KEY ISSUES

;; DONE which key isn't working in versatile-C-h, need to figure out
;; (it doesn't seem to activate the keymap). solved by adding to the
;; which key help function `(when km (set-transient-map km))`


;; DONE versatile-c-h which-key toggle is malfunctioning, especially
;; when quitting with C-g... maybe unwind protext would help?  unwind
;; protect did help but the code is very dirty, need to cleanup, put a
;; note in the code for now

;; DONE Why am I getting ‘Error in pre-command-hook
;; (clear-transient-map): (quit)’; sometimes when quitting out of a
;; menu, sometimes when auto quitting my pressinga key not in a menu.
;; Can't even find docs for clear-transient-map.  I've tried to bring
;; in the exit function from set-transient-map but didn't work... its
;; because which-key-abort in my on exit function was calling
;; keyboard-quit

;; NOTE: when using nested menus, need to refresh which key by hitting
;; the keybinding... also issue with the message in the echo line
;; being overwritten by the previous one

;; DONE way to toggle which-key-help on and off (done, re-press the
;; keybinding), and a way to toggle embark-help on and off (done,
;; re-press the keybinding, either select the option from completing
;; read of @ keybinding).  Can also press C-g for embark (needed to
;; add to restore menu to get this working, already worked for which
;; key since C-g exited the whole menue, thereby running the exit
;; function which sets the toggle to nil)

;; DONE try nested menus (hydra-theme from menu-window is a good first
;; candidate for trying this, convert the hydra to a menu then
;; implement)... NOTE.  Ran into issue, not easy to bind
;; menu-*-keymap, get the error Wrong type argument: commandp,
;; menu-theme-keymap... Ah the solution is that you actually bind
;; menu-*, not menu-*-keymap

;; TODO should be an embark task, but how to toggle between the two
;; kinds of help for embark, and possibly even which-key for embark?

;; TODO also an embark task (maybe?) but a way to make an embark map
;; into a menu on the fly... for example, I hit C-. on a symbol and
;; want to take multiple actions (consider if this is covered enough
;; by embark-no-quit, albeit without the other features of menu).
;; what is a repeatable keybinding in embark?
;; embark-keybinding-repeat?

;; TODO add docstrings to functions

;; TODO switching between different types of help in menu is still
;; confusing / inconsistent this should get fixed in a deep dive.  May
;; need to settle on C-g'ing out of the menu, but maybe that's not
;; possible with which key

;; TODO refine which-key settings, can I display the keymap?

;; TODO add which-key-like embark-verbose-indicator to the helpers for
;; both menu and versatile C-h... NOTE challenging, there isn't a
;; simple function I can call manually for this... deprioritizing

;; TODO get some way to guaruntee that prefix-help-command is set to
;; versatile-C-h NOTE: seems to be working so far with limited
;; testing, not sure what changed... maybe setting embark indicators?
;; either way, need to wait to see if this continues working beyond
;; whenever an autoloaded package overrides the prefix-help-command

;; CANCELLED add embark key prompter helper:
;; https://github.com/oantolin/embark/wiki/Additional-Actions#use-embark-like-a-leader-key


(defvar-keymap menu--active-km)
(defvar menu--indicator nil)
(defvar menu--which-key-toggle nil)
(defvar menu--embark-help-toggle nil)
(defvar-local menu--minibuffer-km nil)

(defvar menu-set-transient-map-message "%k"
  "Value of %k displays the active keys, which is a nice first pass
before invoking one of the helper commands to get a better description
of the keymap.  Any value here acts as an indicator in the echo-line
that a transient-map is active, however, it cannot be used as a fully
robust alternative to menu-indicator because sometimes side-effects
occuring while using the keymap can cause the echo-line to be flushed or
occupied by other text.  That being said, nice behavior is that pressing
a key in the transient map will force the message to appear in the echo
line (unless that command bound to that key flushes or occupies the
echo-line), so can sometimes be an indicator that you are still in the
transient map when you are pressing a certain key (like j, k for
navigating) and aren't seeing the anticipated result")
(defvar menu-set-transient-map-keep-pred-fn t
  "NOTE; when set to nil, menus will exit no matter what key is
pressed, when set to t menus will exit if a key not in map is pressed,
set to a function returning t will only exit keymap if a quitter key is
pressed.  Important to understand the critical distinction between the
subtly different values of `t` and `'(lambda () t)`: the former keeps
transient keymaps if pressing a key in that map, the latter keeps the
transient map no matter what key is pressed.  NOTE: setting this to a
function weirdly leaves the map message in the echo area, not sure why")

;; TODO decouple the function intended to be used from versatile-C-h
;; and from menu, it's leading to too much bad code
;; Help popups (design should work for both versatile-C-h and menu)
;; TODO remove km, not used
(defun menu-prefix-help-command-which-key (&optional km key-seq)
  (interactive)
  (unwind-protect
      (let ((display-settings
             '((display-buffer-in-side-window) (window-height . 0.3)))
            ;;(_ (setq which-key-idle-delay 1000))
            (_ (setq prefix-help-command 'which-key-C-h-dispatch))
            )
        (if menu--which-key-toggle
            (progn (kill-buffer which-key-buffer-name)
                   (setq menu--which-key-toggle nil))
          (progn
            ;; NOTE bad code, this is a way to express if called from
            ;; versatile-C-h then set toggle to nill

            ;; NOTE very odd that you need the dispatch before
            ;; reloading the key sequence, can prove this manually too
            (which-key-C-h-dispatch)
            (if (or key-seq)
                (which-key-reload-key-sequence key-seq)
              ;; TODO if this doesn't work, can try to lookup the
              ;; key-seq based on the map actually this would work
              ;; because a new transient map is set -- it's not like
              ;; ,wh is a full key chord -- ,w sets the new transient
              ;; map, of which h is a part

              ;; LEFTOFF TODO C-h doesn't trigger, but I think it's because it
              ;; isn't bound when displaying which-key this way
              (progn
                (which-key--create-buffer-and-show nil menu--active-km)
                ;;(setq zetta-which-key-showing t)
                )
              )
            (setq menu--which-key-toggle t))
          )
        )
    (progn
      ;; NOTE bad code, this is a way to express if called from
      ;; versatile-C-h then set toggle to nil
      (when km (setq menu--which-key-toggle nil))
      )
    ))



(defun menu-prefix-help-command-embark (&optional km)
  (interactive)
  (if menu--embark-help-toggle
      (progn
        (setq menu--embark-help-toggle nil)
        (keyboard-quit))
    (progn
      (setq menu--embark-help-toggle t)
      (embark-bindings-in-keymap (or km menu--active-km)))))


;; Menu code starts here
(defun menu-set-transient-map--on-exit ()
  ;; update state
  (setq menu--indicator nil)
  (setq menu--active-km nil)
  (setq menu--which-key-toggle nil)
  ;; update display
  (force-mode-line-update)
  ;; NOTE modified version of `which-key-abort` because this function
  ;; contains a call to `keyboard-quit` which resulted in the
  ;; following error: `Error in pre-command-hook
  ;; (clear-transient-map): (quit)`
  (let ((which-key-inhibit t)) (which-key--hide-popup-ignore-command)))


(defun menu-get-child-map (km)
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map km) map))


(defun menu-set-transient-map (km)
  ;; NOTE subtle distinction between set-transient-map's on-exit
  ;; argument (the function that gets called when the transient keymap
  ;; exits), and the 'exit-function' returned by set-transient-map
  ;; (the function that can be called to cause the keymap to be
  ;; exited) returned by set-transient-map
  (set-transient-map
   km
   menu-set-transient-map-keep-pred-fn
   #'menu-set-transient-map--on-exit
   menu-set-transient-map-message))


(defun menu-define-quitter-keys (km exit-function)
  (define-key km [remap keyboard-quit]
              (lambda () (interactive) (funcall exit-function)))
  (define-key km [remap keyboard-escape-quit]
              (lambda () (interactive) (funcall exit-function)))
  (define-key km [remap minibuffer-keyboard-quit]
              (lambda () (interactive) (funcall exit-function))))


(defun menu-define-helpers (km)
  "Note these need to be called without arguments, they effectively need to
detect the current km.  describe-prefix-bindings works because
overriding bindings are set"
  ;; TODO this enable which-key help to work at top level fo
  ;; menu... but doesn't work in nested bindings, why?  Still other
  ;; issues with which key help even at top level of menu (see above)
  ;; maybe something to do with the post command hook?
  (define-key km (kbd "?") 'which-key-C-h-dispatch)
  (define-key km (kbd "C-h") 'menu-prefix-help-command-embark)
  (define-key km (kbd "C-S-h") 'menu-prefix-help-command-which-key)
  ;; TODO doesn't work
  (define-key km (kbd "M-S-h") 'describe-prefix-bindings))


;; Workhorse function
(defun menu (km)
  (let* ((transient-km (menu-get-child-map km))
         (_ (progn
              (menu-define-helpers transient-km)
              ;;(setq which-key-persistent-popup t)
              (setq menu--indicator t)
              (setq menu--active-km transient-km)))
         (exit-function (menu-set-transient-map transient-km)))
    (menu-define-quitter-keys transient-km exit-function)
    (force-mode-line-update)))


;; Hooks
(defun menu-suspend-transient-map ()
  (when menu--active-km
    (setq-local menu--minibuffer-km (copy-keymap menu--active-km))
    ;; NOTE this is a sparse version of what exit-function is... maybe
    ;; that's okay, just noting here
    (setq overriding-terminal-local-map nil)))


(defun menu-restore-transient-map ()
  (setq menu--embark-help-toggle nil)
  (when (keymapp menu--minibuffer-km)
    (menu menu--minibuffer-km)))


(add-hook 'minibuffer-setup-hook 'menu-suspend-transient-map)
(add-hook 'minibuffer-exit-hook 'menu-restore-transient-map)


;; Macro
(defmacro defmenu (function-name km-name)
  `(progn
     (defvar ,km-name (make-sparse-keymap))
     ;; TODO set variable for current keymap name for use in the
     ;; modeline and force-mode-line-update
     (defun ,function-name () (interactive) (menu ,km-name))))


;; Enhanced help
(defun versatile-C-h ()
  "NOTE (setq prefix-help-command 'versatile-C-h for a more flexible help
interface and access to on-the-fly menus)"
  (interactive)
  (let* ((keys (this-command-keys-vector))
         (prefix (seq-take keys (1- (length keys))))
         (orig-km (key-binding prefix 'accept-default))
         (km (copy-keymap orig-km))
         (key (read-key
               (concat "h (embark), "
                       "H (which-key),"
                       "M-h (menu), "
                       "or M-S-h (describe-prefix-bindings):"))))
    ;;(setq which-key-persistent-popup nil)
    (cond ((eq key ?\C-h) (menu-prefix-help-command-embark km))
          ((eq key ?\C-\S-h) (menu-prefix-help-command-which-key km prefix))
          ;; TODO is this an on the fly menu?
          ((eq key ?\M-h) (menu km))
          ;;((eq key ?\M-\S-h) (describe-prefix-bindings)) ;; TODO invalid seq
          (t (message "Invalid key"))))
  
  )

;; TODO delete, this is here to test versatile-C-h
(general-define-key
 :keymaps 'override
 "C-c o o" '(lambda () (interactive) (message "hello"))
 "C-c o p" '(lambda () (interactive) (message "bye"))
 )

(provide 'menu)

