;; change make process to make repl

;; pkg imports
(require 's)

;;local imports

(require 'convention-docker)
(require 'convention-utils)
(require 'convention-lang-info)
(require 'convention-layers)
(require 'convention-image)
(require 'convention-container)
(require 'convention-start-container)
(require 'convention-connect-container)
(require 'convention-execute)

;; config
(defvar convention-dir (expand-file-name "source/zettapkg/convention/" user-emacs-directory)
  "Absolute path of the directory containing convention code on the end user's machine")

;;;;;;;;;;;;;; display
(add-to-list 'display-buffer-alist
             `("^\\*convention*"
               (display-buffer-in-side-window)
               (window-height . 0.20)
               (side . bottom)
               (slot . 2)
               (window-parameters . ((no-delete-other-windows . 1)))
               ))

;; provide
(provide 'convention)
