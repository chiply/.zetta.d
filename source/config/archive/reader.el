;; NOTE can't get this to install, maybe there's something wrong with
;; the recipe?  also under very active development as of <2025-09-22
;; Mon>, so probbaly not a good idea to start using now anyway
(use-package reader
  :ensure '(reader :type git
                   :host codeberg
                   :repo "divyaranjan/emacs-reader"
                   :files ("*.el" "render-core.so")
                   :pre-build ("make" "all"))
  :commands reader-mode)
