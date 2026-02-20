;;; space-tree.el --- Tree-based workspace management -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Charlie Holland

;; Author: Charlie Holland <mister.chiply@gmail.com>
;; Maintainer: Charlie Holland <mister.chiply@gmail.com>
;; URL: https://github.com/chiply/space-tree
;; x-release-please-start-version
;; Version: 0.1.0
;; x-release-please-end
;; Package-Requires: ((emacs "28.1") (ht "2.3") (dash "2.19"))
;; Keywords: convenience, frames

;;; Commentary:

;; space-tree is a library for managing spaces in Emacs.  It is inspired
;; by the concept of "workspaces" supported in the most major
;; operating systems' window managers, and is intended to be a
;; lightweight, but flexible alternative to packages tab-bar-mode and
;; eyebrowse.

;; The main features of space-tree are:

;; - A tree-based structure (AKA the space-tree) for organizing
;;   spaces, with branches of mixed and arbitrary depth
;; - A modeline indicator(s) for the current space and context in the
;;   space-tree
;; - Commands for creating and managing spaces

;;; Code:

;; Dependencies
(require 'ht)
(require 'dash)


;;; Customization

(defgroup space-tree nil
  "Tree-based workspace management."
  :group 'convenience
  :prefix "space-tree-")

(defcustom space-tree-start-at-0 nil
  "If non-nil, the first space will be numbered 0.
Otherwise, the first space will be numbered 1."
  :type 'boolean
  :group 'space-tree)


;;; State

(defvar space-tree-tree (ht-create)
  "A nested hashtable that represents the structural layout of the
spaces in a hierarchy (aka a tree).")

(defvar space-tree-current-address '()
  "A list of numbers that represents the address of the current
existing-space in space-tree-tree.")

(defvar space-tree-address-wconf-tbl (ht-create)
  "A hashtable that stores window configurations for each space.
The keys are the addresses of the spaces and the values are the
window configurations.")

(defvar space-tree-recent-space-list '()
  "A list of the addresses of the most recently visited spaces.
The most recently visited existing-space is at the head of the list.")

(defvar space-tree-space-name-tbl (ht-create)
  "A hashtable that stores names for each space.
The keys are the addresses of the spaces and the values are the names.")

(defvar space-tree-copied-space nil
  "A variable to store copied window configurations.")


;;; Internal Utilities

(defun space-tree--window-state-put-safely (space)
  "Switch to workspace SPACE, ignoring `Selecting deleted buffer' error."
  (let ((result (condition-case _ (window-state-put space) (error _))))
    (when (string= "Selecting deleted buffer" (cadr result))
      (message "Space contains deleted buffers"))))

(defun space-tree--side-window-p ()
  "Return t if the current window is a side window, nil otherwise."
  (window-parameter (selected-window) 'window-slot))

(defun space-tree--select-non-side-window ()
  "Select a non-side window.
If there are no non-side windows, an error is thrown."
  (when (space-tree--side-window-p)
    (let ((num-windows (length (window-list))))
      (dotimes (i num-windows)
        (when (space-tree--side-window-p)
          (progn
            (other-window 1)
            (when (not (space-tree--side-window-p))
              (return)))))
      (when (space-tree--side-window-p) (error "No non-side windows found")))))

(defun space-tree--delete-other-windows-and-switch-to-scratch ()
  "Delete all windows except the current one and switch to *scratch* buffer.
This is a means of creating a clean slate, typically for a new space."
  (delete-other-windows)
  (switch-to-buffer (get-buffer-create "*scratch*")))

(defun space-tree--list-starts-with (lista listb)
  "Return t if LISTA starts with LISTB, nil otherwise.
For example, (space-tree--list-starts-with \\='(1 2 3) \\='(1 2)) returns t."
  (equal (butlast lista (- (length lista) (length listb))) listb))

(defun space-tree--remove-adjacent-duplicates (lst)
  "Remove adjacent duplicates from the list LST."
  (let ((result '()))
    (dolist (x lst)
      (if (not (equal x (car result)))
          (setq result (cons x result))))
    (nreverse result)))

(defun space-tree--win-buf-from-leaf (leaf)
  "Extract the clone-of parameter and buffer from LEAF.
LEAF is a window state structure."
  (let ((params (assoc 'parameters leaf))
        (buf (nth 1 (assoc 'buffer leaf))))
    (list (cdr (assoc 'clone-of params))
          buf)))


;;; Analyzing State

(defun space-tree--recent-space-on-path (sublist)
  "Return the first element of `space-tree-recent-space-list' that begins with SUBLIST.
If no such element exists, return nil."
  (let ((n (length sublist)))
    (car (-filter
          (lambda (x) (equal (butlast x (- (length x) n)) sublist))
          space-tree-recent-space-list))))

(defun space-tree--current-depth ()
  "Return the depth of the current space in the space-tree."
  (length space-tree-current-address))

(defun space-tree--number-of-spaces-current-level ()
  "Return the number of spaces at the current level of the space-tree."
  (length (ht-keys (space-tree--get-parent-ht-at space-tree-current-address))))

(defun space-tree--current-parent ()
  "Return the address of the parent of the current space."
  (butlast space-tree-current-address))

(defun space-tree--space-exists-p (address)
  "Return t if the space at the given ADDRESS exists, nil otherwise."
  (member address (ht-keys space-tree-address-wconf-tbl)))


;;; State Mutation

(defun space-tree--get (address)
  "Return the existing-space at the ADDRESS in the space-tree.
Return nil if the existing-space doesn't exist."
  (eval (append '(ht-get* space-tree-tree "space-tree") address)))

(defun space-tree--get-parent-ht-at (address)
  "Return the parent of the existing-space at the ADDRESS."
  ;; the filter accounts for the fact that the address may be 1 level,
  ;; e.g. it may not have a parent
  (eval (-filter
         (lambda (x) x)
         (append '(ht-get* space-tree-tree "space-tree") (butlast address)))))

(defun space-tree--set (address)
  "Set the ADDRESS in the space-tree to a new hashtable."
  (eval (append
         '(ht-set)
         `(,(space-tree--get-parent-ht-at address))
         (last address)
         `(,(ht-create)))))

(defun space-tree--remove (address)
  "Remove the space at ADDRESS from the space-tree."
  (eval (append ;; remove the space from space-tree-tree
         '(ht-remove)
         `(,(space-tree--get-parent-ht-at address))
         (last address)))
  (ht-remove space-tree-space-name-tbl address)
  (ht-remove space-tree-address-wconf-tbl address)
  (setq
   space-tree-recent-space-list
   (-remove
    (lambda (x) (equal x address))
    space-tree-recent-space-list))
  (space-tree--process-history)
  (force-mode-line-update))

(defun space-tree--process-history ()
  "Remove any sublist in `space-tree-recent-space-list' that is the prefix of another."
  (setq space-tree-recent-space-list
        (space-tree--remove-adjacent-duplicates
         (-remove
          (lambda (sublista)
            (-filter
             (lambda (sublistb)
               (and
                (> (length sublistb) (length sublista))
                (space-tree--list-starts-with sublistb sublista)))
             space-tree-recent-space-list))
          space-tree-recent-space-list))))

(defun space-tree--create-space-at (address)
  "Add a existing-space to the space-tree at the ADDRESS."
  (space-tree--select-non-side-window)
  (space-tree--set address)
  (setq space-tree-current-address address)
  (ht-set space-tree-address-wconf-tbl address (window-state-get))
  (setq space-tree-recent-space-list (cons space-tree-current-address space-tree-recent-space-list))
  ;; process list -- remove duplicates and branch nodes
  (space-tree--process-history)
  (when (> (space-tree--number-of-spaces-current-level) 1)
    (space-tree--delete-other-windows-and-switch-to-scratch)))


;;; Modeline

(defun space-tree--modeline-string-for-level (parent-address level spaces-this-level-ht)
  "Return a string for the modeline for the given level of space-tree.
PARENT-ADDRESS is the address of the parent.
LEVEL is the current level number.
SPACES-THIS-LEVEL-HT is the hashtable of spaces at this level."
  (mapconcat
   (lambda (space-number)
     (let ((space-name-or-number (or (ht-get
                                      space-tree-space-name-tbl
                                      (append parent-address `(,space-number)))
                                     (number-to-string space-number))))
       (concat ""
               (if (equal space-number level)
                   ;; need to change text to update modeline
                   (propertize (concat space-name-or-number "' ") 'face 'bold)
                 (concat space-name-or-number " "))
               )))
   (sort (ht-keys spaces-this-level-ht) (lambda (a b) (< a b)))
   ""))

(defun space-tree-modeline-lighter ()
  "Return a string to be used as the modeline lighter for space-tree.
This is a critical UI element for space-tree, as it provides a visual
indication of the current space in space-tree, which can grow to be quite
large."
  (setq modeline-string "")
  (dotimes (i (space-tree--current-depth))
    (let* ((parent-address (butlast space-tree-current-address (- (space-tree--current-depth) i)))
           (selected-space-this-level (nth i space-tree-current-address))
           (spaces-this-level-ht (space-tree--get parent-address))
           ;; spaces-this-level-ht should be non-empty
           ;; TODO -- the let vars can go into the helper function above
           (modeline-string-this-node (space-tree--modeline-string-for-level
                                       parent-address
                                       selected-space-this-level
                                       spaces-this-level-ht))
           (modeline-string-to-this-level (concat
                                           modeline-string
                                           modeline-string-this-node
                                           "| ")))
      (setq modeline-string modeline-string-to-this-level)))
  (concat "{ " (substring modeline-string 0 -2) "}"))


;;; Public API

;;;###autoload
(defun space-tree-init ()
  "Initialize space-tree.  Can also be used to reset space-tree."
  (interactive)
  (let ((first-space-number (if space-tree-start-at-0 0 1)))
    (setq space-tree-tree (ht-create)
          space-tree-address-wconf-tbl (ht-create)
          space-tree-space-name-tbl (ht-create)
          space-tree-recent-space-list '())
    (ht-set space-tree-tree "space-tree" (ht-create))
    (space-tree--create-space-at `(,first-space-number)))
  (force-mode-line-update))

(defun space-tree-save-current-space ()
  "Save the current window configuration in `space-tree-address-wconf-tbl'."
  (ht-set space-tree-address-wconf-tbl space-tree-current-address (window-state-get)))

(defun space-tree-switch (address &optional no-update-wconf)
  "Switch to the existing-space at the ADDRESS.
If NO-UPDATE-WCONF is non-nil, don't update the window configuration."
  (space-tree--select-non-side-window)
  (let ((recent-space (ht-get space-tree-address-wconf-tbl address)))
    (unless no-update-wconf
      (space-tree--window-state-put-safely recent-space))
    (setq space-tree-current-address address
          space-tree-recent-space-list (cons space-tree-current-address space-tree-recent-space-list))))

;;;###autoload
(defun space-tree-switch-or-create (new-address)
  "Switch to the existing space indicated by NEW-ADDRESS, or create it.
This is the workhorse for navigating the space-tree."
  (interactive)
  (let* ((existing-space (ht-get space-tree-address-wconf-tbl new-address))
         (space-tree-recent-space-address (space-tree--recent-space-on-path new-address)))
    ;; save the current window configuration, the one being switched from
    (space-tree-save-current-space)
    ;; switch to the new existing-space
    (cond
     ;; IF new-address hasn't been visited yet, THEN create it
     ((not existing-space) (space-tree--create-space-at new-address))
     ;; IF new-address points to a recent space or parent, THEN switch to it
     (space-tree-recent-space-address (space-tree-switch space-tree-recent-space-address))))
  ;; update the modeline
  (force-mode-line-update))

;;;###autoload
(defun space-tree-create-space-current-level ()
  "Add a new space at the current level of the space-tree."
  (interactive)
  (let* ((parent (space-tree--current-parent))
         (tbl (space-tree--get parent))
         (next-level-number (+ 1 (apply 'max (ht-keys tbl)))))
    (space-tree--create-space-at (append parent `(,next-level-number)))))

;;;###autoload
(defun space-tree-create-space-top-level ()
  "Add a new space at the top level of the space-tree."
  (interactive)
  (space-tree--create-space-at
   `(,(+ 1 (apply 'max (ht-keys (ht-get space-tree-tree "space-tree")))))))

;;;###autoload
(defun space-tree-delete-space (address)
  "Delete the space at the given ADDRESS.
If the space is the only space at its level, it is deleted and the parent
space is selected.  Otherwise, the space is deleted and the next space at
the same level is selected."
  (interactive (list space-tree-current-address))
  (let ((n-spaces (space-tree--number-of-spaces-current-level)))
    (cond ((> n-spaces 1) (space-tree-go-left) (space-tree--remove address))
          ((and (= 1 n-spaces) (= (space-tree--current-depth) 1))
           (error "Cannot delete the only space"))
          ((= 1 n-spaces)
           (space-tree-switch (butlast address) t)
           (space-tree--remove address)))))

;;;###autoload
(defun space-tree-copy-workspace ()
  "Copy the current workspace to the clipboard."
  (interactive)
  (setq space-tree-copied-space (window-state-get)))

;;;###autoload
(defun space-tree-paste-workspace (&optional inplace)
  "Paste the copied workspace to the current space.
If INPLACE is non-nil, the current space is overwritten with the copied space.
If INPLACE is nil, a new space is created and the copied space is pasted there.
If no space has been copied, an error is raised."
  (interactive)
  (when (not space-tree-copied-space) (error "No copied space"))
  (when inplace (space-tree-create-space-current-level))
  (space-tree--window-state-put-safely space-tree-copied-space))

;;;###autoload
(defun space-tree-switch-current-level (arg)
  "Switch to the ith space at the current level of the space-tree.
ARG specifies which space to switch to."
  (interactive "P")
  (let ((n (when (not arg)
             (string-to-number
              (read-from-minibuffer "Switch to space: ")))))
    (if n
        (space-tree-switch-or-create (append (space-tree--current-parent) `(,n)))
      (space-tree-switch-or-create (append (space-tree--current-parent) `(,arg))))))

;;;###autoload
(defun space-tree-switch-space-by-digit-arg (arg)
  "Switch to a space using a multi-digit address ARG.
Digits are separated by 0 for multi-level addresses."
  (interactive "P")
  (let* ((arg-string (if (not arg)
                         (read-from-minibuffer "Switch to space: ")
                       (number-to-string arg)))
         (address (if (string-match-p "0" arg-string)
                      (split-string arg-string "0")
                    (-filter
                     (lambda (x) (> (length x) 0))
                     (string-split arg-string ""))))
         (address (-map (lambda (x) (string-to-number x)) address)))
    (space-tree-switch-or-create address)))

;;;###autoload
(defun space-tree-switch-space-by-name ()
  "Switch to a named space.
Prompt the user to select from a list of named spaces."
  (interactive)
  (let* ((space-tree-named-spaces-reversed
          (-map
           (lambda (x) `(,(cdr x) . (,(car x))))
           (ht-to-alist space-tree-space-name-tbl)))
         (name (completing-read
                "Select a named space: "
                space-tree-named-spaces-reversed))
         (address (car
                   (ht-get
                    (ht-from-alist space-tree-named-spaces-reversed)
                    name))))
    (space-tree-switch-or-create address)))

;;;###autoload
(defun space-tree-go-to-last-space ()
  "Switch to the most recently visited space."
  (interactive)
  (space-tree-switch-or-create (nth 1 space-tree-recent-space-list)))

;;;###autoload
(defun space-tree-go-right ()
  "Switch to the next space to the right at the current level."
  (interactive)
  (let* ((spaces-current-level (sort
                                (ht-keys (space-tree--get (butlast space-tree-current-address)))
                                (lambda (a b) (< a b))))
         (current-position (-elem-index
                            (car (last space-tree-current-address))
                            spaces-current-level))
         (target-position (+ 1 current-position)))
    (if (>= target-position (space-tree--number-of-spaces-current-level))
        (space-tree-switch-current-level (car spaces-current-level))
      (space-tree-switch-current-level (nth target-position spaces-current-level)))))

;;;###autoload
(defun space-tree-go-left ()
  "Switch to the next space to the left at the current level."
  (interactive)
  (let* ((spaces-current-level (sort
                                (ht-keys (space-tree--get (butlast space-tree-current-address)))
                                (lambda (a b) (< a b))))
         (current-position (-elem-index
                            (car (last space-tree-current-address))
                            spaces-current-level))
         (target-position (- current-position 1)))
    (if (< target-position 0)
        (space-tree-switch-current-level (car (last spaces-current-level)))
      (space-tree-switch-current-level (nth target-position spaces-current-level)))))

;;;###autoload
(defun space-tree-name-current-space (name)
  "Name the current space, prompting the user for NAME."
  (interactive "sName: ")
  (ht-set space-tree-space-name-tbl space-tree-current-address name)
  (force-mode-line-update))

;;;###autoload
(defun space-tree-name-space-by-digit-arg (arg)
  "Name a space specified by digit ARG, prompting the user for a name."
  (interactive "P")
  (let* ((arg-string (number-to-string arg))
         (address (if (string-match-p "0" arg-string)
                      (split-string arg-string "0")
                    (-filter
                     (lambda (x) (> (length x) 0))
                     (string-split arg-string ""))))
         (address (-map (lambda (x) (string-to-number x)) address)))
    (ht-set space-tree-space-name-tbl address (completing-read "Name: " nil)))
  (force-mode-line-update))

(provide 'space-tree)

;;; space-tree.el ends here
