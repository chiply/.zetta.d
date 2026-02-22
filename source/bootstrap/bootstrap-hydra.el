;;; bootstrap-hydra.el --- Configure hydra menus -*- lexical-binding: t; -*-

(setq shouldnt-load nil)

(setq hydra-registry '())
;; My approach to hydra is broken by elpaca -- something is going on
;; with the code here related to many threads operating on the same
;; data structure simultaneously... things like magit get broken, but
;; I don't see an error in messages.  i do however when i try to rerun
;; the defhydra+.... not sure what's going on there.... I may run into
;; the same issue with keymaps i create....

;; I don't know whether the solution is to first try and fix Hydra,
;; with the escape patch being pulling all of my deaf, hydra
;; definitions into something that gets run by the cleanup file or if
;; I have some key bindings file something that gets run at the end,
;; but all in but like synchronously basically because the
;; asynchronous nature of this is what's causing the iissue . My only
;; concern with doing the key app approaches that I'm probably gonna
;; have similar logic or a similar statement that checks to see if the
;; team app exists and if not.

(use-package hydra
  :ensure (:wait t)
  :demand t
  :init
  (defun zetta-hydra-init (name)
    "Function used to instantiate a hydra following a special
template.  This template handles setting up a generic docstring, C-g
for quitting, and s-x for hide-showing the hint."
    ;; define the hydra
    (eval
     `(defhydra ,(intern name) ()
        (format "%s: " ,name) ;; docstring
        ("C-g" (hydra-set-property (intern ,name) :verbosity 0)
         "exit" :exit t)
        ;; show-hide
        ("s-x"
         (cond
          ((eq 0 (hydra-get-property (intern ,name) :verbosity))
           (hydra-set-property (intern ,name) :verbosity 1))
          ((eq 1 (hydra-get-property (intern ,name) :verbosity))
           (hydra-set-property (intern ,name) :verbosity 0))))))
    ;; set the verbosity to 0 (eg don't show the docstrinig)
    (eval `(hydra-set-property (intern ,name) :verbosity 0))
    ;; add the name to the hydra registry (useful for introspection)
    (push name hydra-registry))
  (zetta-hydra-init "hydra-window")

  :config
  ;; redefining macro from hydra.el
  (defmacro defhydra+ (name body &optional docstring &rest heads)
    "Redefine an existing hydra by adding new heads.
Arguments are same as of `defhydra'."
    (unless (and (fboundp (intern (concat (symbol-name name) "/body"))))
      (zetta-hydra-init (symbol-name name)))
    (declare (indent defun) (doc-string 3))
    (unless (stringp docstring)
      (setq heads (cons docstring heads))
      (setq docstring nil))
    `(defhydra ,name ,(or body (hydra--prop name "/params"))
       ,(or docstring (hydra--prop name "/docstring"))
       ,@(cl-delete-duplicates
          (append (hydra--prop name "/heads") heads)
          :key #'car
          :test #'equal)))

  :brushup
  (add-to-list 'brushup-styles
               '(progn
                  (set-face-attribute 'hydra-face-red nil
                                      :foreground brushup-fg
                                      :underline t)
                  (set-face-attribute 'hydra-face-blue nil
                                      :foreground brushup-fg-3)))

  ;;:general
  ;;(
   ;;:keymaps 'launch-map
   ;;;;"w" 'hydra-window/body
   ;;"p" 'hydra-project/body
   ;;)
  ;;(
   ;;:keymaps '(evil-insert-state-map)
   ;;;;(general-chord ",w") 'hydra-window/body
   ;;(general-chord ",p") 'hydra-project/body
   ;;)
  ;;(
   ;;:keymaps 'override
   ;;:states '(normal visual)
   ;;:prefix ","
   ;;;;"w" 'hydra-window/body
   ;;"p" 'hydra-project/body
   ;;)

  :hook (use-package--hydra--post-config . zetta-brushup)
  )

(defalias 'use-package-handler/:hydra 'use-package-handle-forms)
(defalias 'use-package-normalize/:hydra 'use-package-normalize-forms)
(add-to-list 'use-package-keywords :hydra t)

(provide 'bootstrap-hydra)
;;; bootstrap-hydra.el ends here
