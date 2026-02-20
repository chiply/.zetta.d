;;; hl-block.el --- Highlight logical block at point -*- lexical-binding: t -*-

;; Copyright (C) 2025 Nicolas P. Rougier

;; Maintainer: Nicolas P. Rougier <Nicolas.Rougier@inria.fr>
;; Package-Requires: ((emacs "27.1"))
;; Keywords: convenience

;; This file is not part of GNU Emacs.

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.


;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; For a full copy of the GNU General Public License
;; see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Highlight the logical block at point using treesitter.

;;; Usage

;; (hl-block-mode)  ; Toogle hl-block mode in the current buffer.

(use-package nano-theme)

;;; Code
(require 'hl-line)
(require 'treesit)

(defface hl-block-header-face
  `((t :background ,brushup-bg-1
       :overline nil
       :extend t))
  "Face for header (first line)")

(defface hl-block-body-face
  `((t :background ,brushup-bg-1_0
       :extend t))
  "Face for body")

(defface hl-block-symbol-face
  `((t :background ,brushup-bg-1_0
       :extend t))
  "Face for symbol (top right)")

(defface hl-block-footer-face
  `((t :background ,brushup-bg-1_0
       :underline nil
       :extend t))
  "Face for footer (last line)")

(defvar hl-block-types '(("function_definition" . "F")
                         ("class_definition"    . "C")
                         ("if_statement"        . "I")
                         ("for_statement"       . "L")
                         ("while_statement"     . "L"))
  "List of node types to be highlighted")

(defvar-local hl-block--overlays nil
  "Local overlays to highlight buffer.")

(defvar-local hl-block--current-node nil
  "Current node.")


(defun hl-block--highlight (&optional node)
  "Highlight given NODE using overlays."

  (let* ((type (treesit-node-type node))
         ;; NOTE disabling the symbol as it causes alignment issues at
         ;; certain font sizes. and with certain other features like
         ;; side-line mode
         ;;(symbol (format " %s"
         ;;(or (cdr (assoc type hl-block-types)) "-")))
         (symbol "")
         (header-start (save-excursion
                         (goto-char (treesit-node-start node))
                         (line-beginning-position)))
         (header-end (save-excursion
                       (goto-char (treesit-node-start node))
                       (+ 0 (line-end-position))))
         (symbol-start header-end)
         (symbol-end (1+ header-end))
         (body-start symbol-end)
         (body-end (save-excursion
                     (goto-char (treesit-node-end node))
                     (line-beginning-position)))
         (footer-start body-end)
         (footer-end (save-excursion
                       (goto-char (treesit-node-end node))
                       (min (point-max) (1+ (line-end-position))))))
    (move-overlay (cdr (assoc 'header hl-block--overlays))
                  header-start header-end)
    (move-overlay (cdr (assoc 'symbol hl-block--overlays))
                  symbol-start symbol-end)
    (move-overlay (cdr (assoc 'body hl-block--overlays))
                  body-start body-end)
    (move-overlay (cdr (assoc 'footer hl-block--overlays))
                  footer-start footer-end)
    (overlay-put (cdr (assoc 'header hl-block--overlays))
                 'after-string (concat
                                (propertize " " 'display
                                            `(space :align-to
                                                    (- right
                                                       ,(length symbol)
                                                       ;; NOTE tested
                                                       ;; with
                                                       ;; terminus,
                                                       ;; not sure
                                                       ;; about other
                                                       ;; fonts
                                                       ,(cond
                                                         ;; NOTE anything larger probably doesn't make sense
                                                         ((> text-scale-mode-amount 19) 12)
                                                         ((> text-scale-mode-amount 18) 11)
                                                         ((> text-scale-mode-amount 17) 10)
                                                         ((> text-scale-mode-amount 16) 9)
                                                         ((> text-scale-mode-amount 15) 8)
                                                         ((> text-scale-mode-amount 14) 7)
                                                         ((> text-scale-mode-amount 13) 6)
                                                         ((> text-scale-mode-amount 11) 5)
                                                         ((> text-scale-mode-amount 9) 4)
                                                         ((> text-scale-mode-amount 7) 3)
                                                         ((> text-scale-mode-amount 4) 2)
                                                         (t 1))
                                                       ))
                                            'face (if (and hl-line-mode
                                                           (>= (point) header-start)
                                                           (< (point) header-end))
                                                      'hl-line
                                                    'face 'hl-block-header-face))
                                (propertize symbol
                                            'face 'hl-block-symbol-face)))))

(defun hl-block--search (&optional node)
  "Search for the smallest node of allowed type and enclosing NODE."

  (let* ((node (or node (treesit-node-at (point))))
         (type (treesit-node-type node))
         (types (mapcar #'car hl-block-types)))
    (if (member type types)
        node
      (when-let ((parent (treesit-node-parent node)))
        (hl-block--search parent)))))


(defun hl-block--update (&optional node)
  "Highlight the closest typed block that surround NODE (default to node at
point). Available types are registered in hl-block-types."

  (interactive)
  (if-let ((node (hl-block--search)))
      (hl-block--highlight node)
    (remove-overlays (point-min) (point-max) 'hl-block t)))

(defun hl-block--enable ()
  "Enable hl-block mode"

  (setq-local overline-margin 0)
  (unless hl-block--overlays
    (setq hl-block--overlays
          (list (cons 'header (make-overlay (point-min) (point-min)))
                (cons 'symbol (make-overlay (point-min) (point-min)))
                (cons 'body   (make-overlay (point-min) (point-min)))
                (cons 'footer (make-overlay (point-min) (point-min)))))
    (dolist (name '(header symbol body footer))
      (overlay-put (cdr (assoc name hl-block--overlays))
                   'hl-block t))

    (overlay-put (cdr (assoc 'header hl-block--overlays))
                 'font-lock-face 'hl-block-header-face)
    (overlay-put (cdr (assoc 'header hl-block--overlays))
                 'priority -100)

    (overlay-put (cdr (assoc 'symbol hl-block--overlays))
                 'font-lock-face 'hl-block-symbol-face)
    (overlay-put (cdr (assoc 'symbol hl-block--overlays))
                 'priority (1+ hl-line-overlay-priority))
    ;;                 'priority -100)

    (overlay-put (cdr (assoc 'body hl-block--overlays))
                 'font-lock-face 'hl-block-body-face)
    (overlay-put (cdr (assoc 'body hl-block--overlays))
                 'priority -100)

    (overlay-put (cdr (assoc 'footer hl-block--overlays))
                 'font-lock-face 'hl-block-footer-face)
    (overlay-put (cdr (assoc 'footer hl-block--overlays))
                 'priority -100))

  (add-hook 'post-command-hook #'hl-block--update nil t))

(defun hl-block--disable ()
  "Disable hl-block mode"

  (remove-overlays (point-min) (point-max) 'hl-block t)
  (remove-hook 'post-command-hook #'hl-block--update t))


;;###autoload
(define-minor-mode hl-block-mode
  "Highlight logical block at point"
  :global nil

  (if hl-block-mode
      (hl-block--enable)
    (hl-block--disable)))

(add-hook 'python-ts-mode-hook #'hl-block-mode)

(add-to-list
 'brushup-styles
 '(progn
    (set-face-attribute 'hl-block-header-face nil
                        :background brushup-bg-1
                        :overline nil
                        :extend t)
    (set-face-attribute 'hl-block-body-face nil
                        :background brushup-bg-1_0
                        :extend t)
    (set-face-attribute 'hl-block-symbol-face nil
                        :background brushup-bg-1_0
                        :extend t)
    (set-face-attribute 'hl-block-footer-face nil
                        :background brushup-bg-1_0
                        :underline nil
                        :extend t)))


(provide 'hl-block)
;;; hl-block.el ends here
