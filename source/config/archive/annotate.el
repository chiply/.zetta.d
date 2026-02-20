;; TODO consider using org-remark instead -- main difference is that
;; it doesn't show annotations inline, which is probably okay
;; TODO use colors reserved for annotations -- okay to have just to to distringuish between proximal locations, but should be possible to visually distinguish between annotations and other syntax highlighting / overlays
(use-package annotate
  :init
  ;; This must be in the `:init` NOTE needs to be done to prevent
  ;; conflicts with other packages' keybindings
  (defvar annotate-mode-map
    (make-sparse-keymap))

  :config
  ;; NOTE annotations could be on possibly private data, but would be
  ;; ideal to sync annotations for things like `.files` (via github)
  ;; or personal notes (via logseq).  To accomplish this, need to set
  ;; `annotation-file` variable per directory (can be done via
  ;; dir-locals.el - note logseq doesn't sync the dir-locals or
  ;; annotations flie.  Need to explicitly set the .dir-locals on each
  ;; machine and to make annotations havea .org suffix for annotations
  ;; to get synced)


  ;; NOTE This solves the problem of syncing public vs private... keep
  ;; in mind the alternative .dir-locals + annotations approach was
  ;; not working!
  (setq annotate-file-buffer-local t)
  (setq annotate-buffer-local-database-extension "annotations.org")
  ;; otherwise you get alignment issues
  (setq annotate-annotation-column 0)
  ;; NOTE doesn't seem to use all colors
  ;;(setq
  ;;annotate-highlight-faces
  ;;'((:background "#EEF192")
  ;;(:background "#92EEF1")
  ;;(:background "#F192EE")
  ;;(:background "#F19292")
  ;;(:background "#92F192")
  ;;(:background "#9292F1")
  ;;(:background "#F1F192")
  ;;(:background "#F192F1")
  ;;(:background "#92F1F1")
  ;;(:background "#F1F1F1")
  ;;))
  ;;(setq
  ;;annotate-annotation-text-faces
  ;;`((:background "#EEF192" :underline t) 
  ;;(:background "#92EEF1" :underline t) 
  ;;(:background "#F192EE" :underline t)
  ;;(:background "#F19292" :underline t)
  ;;(:background "#92F192" :underline t)
  ;;(:background "#9292F1" :underline t)
  ;;(:background "#F1F192" :underline t)
  ;;(:background "#F192F1" :underline t)
  ;;(:background "#92F1F1" :underline t)
  ;;(:background "#F1F1F1" :underline t)))

  ;; NOTE may be missing bindings for meow

  ;; NOTE when adding text, need to re-save annotations using
  ;; `annotate-save-annotations`, otherwise adding text corrupts the
  ;; data
  :general
  (
   :keymaps '(markdown-mode-map org-mode-map prog-mode-map)
   :states '(normal visual insert)
   "C-s" (lambda () (interactive)
           (when (bound-and-true-p annotate-mode)
             (annotate-save-annotations))
           (save-buffer))
   )
  (
   :keymaps 'menu-window-map
   "a" (** annotate-mode)
   )
  (
   :keymaps 'override
   "C-c !" 'annotate-annotate
   )
  (
   :keymaps 'embark-general-map
   ;; for some reason enters the selection as the annotation, see
   ;; separate keybinding above "N a" #'annotate-annotate
   "N d" #'annotate-delete-annotation
   "N p" #'annotate-change-annotation-text-position
   "N c" #'annotate-change-annotation-colors
   "N s" #'annotate-show-annotation-summary
   "N ]" #'annotate-goto-next-annotation
   "N [" #'annotate-goto-previous-annotation
   )

  ;; TODO add embark general binding for annotate

  ;; TODO add autosave hook to ensure annotations are being saved if
  ;; autosaved?

  ;; TODO something to ensure annotations are saved whenever an
  ;; annotation is added? or will i simply have to remember this

  ;; TODO disable in magit diff mode, or fix the filename that's
  ;; created, maybe create the file in the local directory, but not
  ;; named after the file?
  :hook ((markdown-mode org-mode prog-mode) . annotate-mode)
  )
