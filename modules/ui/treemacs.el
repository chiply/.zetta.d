;; NOTE this package in general is very buggy, try not to rely on it
;; treemacs-add-project has a bug -- this is like the most basic thing, if not an entry point!
(use-package treemacs
  :ensure (treemacs
           :files ("src/elisp/*.el"
                   "src/extra/*.el"))
  :commands (treemacs treemacs-select-window treemacs-add-project
             zetta-soda-drink-treemacs zetta-refresh-treemacs)

  ;;(setq treemacs-persist-file
  ;;(expand-file-name ".data/treemacs/.cache/treemacs-persist"
  ;;user-emacs-directory))

  
  :config
  ;; TODO factor out
  ;; NOTE tried with all the icons -- issue is that I use the svg
  ;; branch of all-the-icons and this is not compatible with treemacs
  ;; implementation of the all-the-icons theme.  better to simply
  ;; avoid having icons for now... if I revert to the master branch of
  ;; all the icons, I get an issue which is that the icons are not
  ;; rendered properly in many of the places I use them in emacs,
  ;; specifically the mode line, tab-line.  I don't really need the
  ;; icons in treemacs, so I'm leaving them out for now

  ;; NOTE also observed that many themes are broken.  For example,
  ;; Iconless doesn't work, default has numerous issues and also looks
  ;; terrible.

  ;; NOTE Idea probably comes with icons but they aren't rendering.
  ;; This is a hacky config because I'm targeting the goal of having
  ;; no icons, but I'm using a theme that has icons...
  (treemacs-load-theme "Idea")



  (treemacs-resize-icons
   ;; NOTE setting to nil allows to be arbitrarly small, otherwise
   ;; they can ;; only shrink to the minimum size of the icon
   nil
  ;; NOTE set to the initial default font size (note this is set 1
   ;;time, so altering the text scale wont cause the icons to change
   ;;size) (font-get (face-attribute 'default :font) :size)
   )

  (setq aw-ignored-buffers '("*Calc Trail*" " *LV*"))

  (setq-default
   treemacs-file-follow-delay 0.25
   treemacs-file-event-delay 1000
   treemacs-tag-follow-delay 0.25
   ;; makes it take up more screen realestate and based on treemacs
   ;; defauults of 1 buffer per frame this bahaves a lot like
   ;; frame-level contruct
   treemacs-display-in-side-window t
   treemacs-width 35
   treemacs-width-is-initially-locked nil)

  ;; very odd.. order matters here..., esp when it comes to files that
  ;; lack tags in the other order, there is an issue with the
  ;; followign of files without tags
  (treemacs-follow-mode t)
  (treemacs-project-follow-mode t)
  (treemacs-tag-follow-mode t)

  (treemacs-filewatch-mode t)

  (defun zetta-refresh-treemacs ()
    (interactive)
    (let ((treemacs-buf (nth 0 (zetta-soda-mode-displayed-p "treemacs-mode")))
          (win (selected-window)))
      (when treemacs-buf
        (progn
          (kill-buffer treemacs-buf)
          (treemacs)
          (select-window win)))))

  ;; TODO update as this also jumps to other buffers displaying
  ;; treemacs like lsp symbols or lsp error list
  (defun zetta-soda-drink-treemacs ()
    (interactive)
    (let* ((bufnm (current-buffer))
           (win (get-buffer-window bufnm))
           (treemacs-buf (nth 0 (zetta-soda-mode-displayed-p "treemacs-mode")))
           )
      (if treemacs-buf
          (select-window (get-buffer-window treemacs-buf))
        (progn
          (treemacs)
          (select-window win)
          )
        )))

  (defun zetta-soda-toggle-treemacs-follow-mode ()
    (interactive)
    (if treemacs-tag-follow-mode
        (progn
          (treemacs-tag-follow-mode -1)
          ;; need this as treemacs tag follow mode -1 affects
          ;; follow mode SO STRANGE.. but this seems to sovle
          ;; the issie of not having proper tracking to to
          ;; lack of tags in a file.  I can get file based
          ;; following in the files where I run this
          ;; function.  Not expectetd, but works!
          (treemacs-follow-mode 1))
      (treemacs-tag-follow-mode 1)))

  (general-define-key
   :keymaps 'menu-run-map
   "t" (** zetta-soda-drink-treemacs)
   "T" (** treemacs)
   "C-t" (** zetta-refresh-treemacs)
   "M-t" (** zetta-soda-toggle-treemacs-follow-mode))

  ;;:brushup
  ;;(add-to-list 'brushup-styles
  ;;'(progn
  ;;(set-face-attribute 'treemacs-root-face nil
  ;;:height 1.2
  ;;:foreground brushup-fg-2
  ;;)
  ;;(setq treemacs-width (floor (* 0.10 (frame-total-cols))))))

  :general
  (
   :keymaps '(treemacs-mode-map)
   "o" 'treemacs-visit-node-ace
   "h" 'treemacs-visit-node-ace-horizontal-split
   "v" 'treemacs-visit-node-ace-vertical-split
   "d" 'treemacs-delete-file
   )

  :hook ((use-package--treemacs--post-config . zetta-brushup)
         (treemacs-mode . (lambda ()
                            (text-scale-set -2)
                            (toggle-truncate-lines -1)))))

(use-package treemacs-magit
  :after (treemacs magit))

