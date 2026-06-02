;;; treesit-tap-embark.el --- Embark integration for treesit-tap -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <charliebkr707@gmail.com>
;; URL: https://github.com/<TBD>/treesit-tap
;; Version: 0.1.0
;; Package-Requires: ((emacs "30.1") (embark "1.0"))
;; Keywords: convenience, tools, languages

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Optional embark sub-extension for `treesit-tap'.  Adds a target
;; finder that walks every tree-sitter ancestor at point and surfaces
;; each whose node-type is in `treesit-tap-embark-types' as an embark
;; target named `ts-<node-type>'.
;;
;; Registration runs at load time (require this file from the user's
;; config -- there is no `;;;###autoload' since the registration is the
;; whole point of loading).  Mirrors `embark-consult' / `embark-org'
;; pattern of "require to enable, no global mode".
;;
;; Ships two tiny defvar-keymaps -- `treesit-tap-embark-string-map' and
;; `treesit-tap-embark-call-map' -- that wire useful actions
;; (browse-url / find-file / xref-find-definitions / kill-new) onto
;; common AST types (`ts-string' / `ts-string_literal' / `ts-call' /
;; `ts-call_expression').  A `treesit-tap-embark-defun-map' covers
;; function/method/class AST types with eval / narrow / mark.
;;
;; Usage:
;;
;;   (require 'treesit-tap-embark)
;;
;; That's it.  After load, `embark-act' on any point inside a treesit
;; buffer offers the surrounding AST ancestors as actionable targets,
;; innermost first.

;;; Code:

(require 'embark)
(require 'treesit-tap)
(require 'treesit)

(defgroup treesit-tap-embark nil
  "Embark integration for `treesit-tap'."
  :group 'treesit-tap
  :prefix "treesit-tap-embark-")

(defcustom treesit-tap-embark-types
  '("function_definition" "function_declaration"
    "class_definition" "class_declaration"
    "method_definition" "method_declaration"
    "call" "call_expression"
    "string" "string_literal"
    "comment"
    "decorator"
    "argument_list" "parameter_list" "parameters"
    "if_statement" "for_statement" "while_statement"
    "import_statement" "import_from_statement")
  "Tree-sitter node-type names surfaced to embark as targets.

Each entry becomes a target of embark type `ts-<NAME>'.  Bind actions
in `embark-keymap-alist' under that symbol; the ones this file
installs are documented in the Commentary.

Node-type names vary by language (e.g. python `call' vs javascript
`call_expression') -- include both spellings of any construct you
want to target across languages."
  :type '(repeat string)
  :options '("function_definition" "call" "string" "class_definition"
             "if_statement" "for_statement" "argument_list" "comment")
  :group 'treesit-tap-embark)

(defun treesit-tap-embark-target-node-at-point ()
  "Embark target finder: every recognised tree-sitter ancestor at point.

Walks up from `treesit-node-at' and returns one bounded target per
ancestor whose type is in `treesit-tap-embark-types', innermost
first.  Returning all ancestors lets `embark-act' cycle through
structural scopes the way `er/expand-region' does."
  (when (and (fboundp 'treesit-parser-list) (treesit-parser-list))
    (let ((node (treesit-node-at (point)))
          targets)
      (while node
        (when (member (treesit-node-type node)
                      treesit-tap-embark-types)
          (let ((start (treesit-node-start node))
                (end (treesit-node-end node)))
            (push (cons (intern (concat "ts-" (treesit-node-type node)))
                        (cons (buffer-substring-no-properties start end)
                              (cons start end)))
                  targets)))
        (setq node (treesit-node-parent node)))
      (nreverse targets))))


;;;; Per-type keymaps + dispatch
;; ----------------------------------------------------------------

;; Defun-shaped AST types (function / method / class): treat as
;; standard defun targets -- eval / narrow / mark.  Embark itself
;; ships no defun-specific keymap, so we define one here rather than
;; aliasing to an external `embark-defun-map' that may not exist.
(defvar-keymap treesit-tap-embark-defun-map
  :doc "Embark actions for ts-function / ts-class / ts-method targets."
  :parent embark-general-map
  "e" #'eval-defun
  "n" #'narrow-to-defun
  "m" #'mark-defun)

;; String literal: treat the node text as URL / path / kill-ring entry.
(defvar-keymap treesit-tap-embark-string-map
  :doc "Embark actions for `ts-string' / `ts-string_literal' targets."
  :parent embark-general-map
  "u" #'browse-url
  "f" #'find-file
  "w" #'kill-new)

;; Call expression: jump-to-definition uses point (the call site),
;; so xref / lsp / eglot variants all just work.
(defvar-keymap treesit-tap-embark-call-map
  :doc "Embark actions for `ts-call' / `ts-call_expression' targets."
  :parent embark-general-map
  "d" #'xref-find-definitions
  "r" #'xref-find-references
  "w" #'kill-new)


;;;; Load-time registration
;; ----------------------------------------------------------------
;; By design: requiring this file installs everything.  Mirrors the
;; embark-consult / embark-org convention.

(add-to-list 'embark-target-finders
             #'treesit-tap-embark-target-node-at-point)

(dolist (sym '(ts-function_definition ts-function_declaration
               ts-method_definition ts-method_declaration
               ts-class_definition ts-class_declaration))
  (setf (alist-get sym embark-keymap-alist) 'treesit-tap-embark-defun-map))

(dolist (sym '(ts-string ts-string_literal))
  (setf (alist-get sym embark-keymap-alist) 'treesit-tap-embark-string-map))

(dolist (sym '(ts-call ts-call_expression))
  (setf (alist-get sym embark-keymap-alist) 'treesit-tap-embark-call-map))


(provide 'treesit-tap-embark)
;;; treesit-tap-embark.el ends here
