;;; vterm.el --- Configure vterm -*- lexical-binding: t; -*-

;; vterm requires compiling a native C module (libvterm via CMake).
;; Skip in batch mode where terminals are unusable and the build hangs CI.
(unless noninteractive
(use-package vterm
  :commands (vterm vterm-mode vterm-other-window)
  :init
  (setq vterm-always-compile-module t)

  (defun zetta-soda-prompt-term-buffer ()
    (let ((mode-buffers (-map
                         (lambda (x) (buffer-name x))
                         (zetta-soda-list-mode-buffers "\\term-mode*"))))
      (completing-read "Proces Buffer: " mode-buffers)
      ))

  (defun zetta-soda-create-and-display-term (buf-or-mode-name)
    (interactive)
    (let* ((buf (current-buffer))
           (program (completing-read
                     "Choose a program: "
                     '("python3" "sqlite3" "zsh" "bash" "ipython")))
           (nm (concat "*"
                       program
                       "-"
                       (if (4mn-get-tramp-context--hostname)
                           (concat "[r: " (4mn-get-tramp-context--hostname) "]")
                         "")
                       (if (4mn-get-tramp-context--containername)
                           (concat "[d:" (4mn-get-tramp-context--containername) "]")
                         "")
                       "--"
                       buf-or-mode-name "*"))
           (filepath (if (string-match ":" (or (project-root (project-current nil default-directory)) default-directory))
                         (nth 0 (last (split-string (or (project-root (project-current nil default-directory)) default-directory) ":")))
                       (or (project-root (project-current nil default-directory)) default-directory)))
           )
      (let ((container (4mn-get-tramp-context--containername))
            (host (4mn-get-tramp-context--hostname)))
        (cond
         ;; needs to be first as it is more specific than the below
         ((and (member "ssh" (4mn-get-tramp-hop-types))
               (member "docker" (4mn-get-tramp-hop-types)))
          ;; then create the buffer on local and docker exec into container
          (let ((default-directory "~/"))
            (with-current-buffer (get-buffer-create nm)
              (vterm-mode)
              (setq-local foreman-ssh t)
              (setq-local foreman-docker t))
            (process-send-string
             nm
             (format "ssh %s \n" host))
            (process-send-string
             nm
             (format "docker exec -it %s bash\n" container))
            (process-send-string
             nm
             (format "cd %s \n" filepath))
            ))
         ((member "docker" (4mn-get-tramp-hop-types))
          ;; then create the buffer on local and docker exec into container
          (let ((default-directory "~/"))
            (with-current-buffer (get-buffer-create nm)
              (vterm-mode)
              (setq-local foreman-docker t)
              (setq-local foreman-ssh nil)
              )
            (process-send-string
             nm
             (format "docker exec -it %s bash\n" container))
            (process-send-string
             nm
             (format "cd %s \n" filepath))
            ))
         ((member "ssh" (4mn-get-tramp-hop-types))
          ;; then create the buffer on local and docker exec into container
          (let ((default-directory "~/"))
            (with-current-buffer (get-buffer-create nm)
              (vterm-mode)
              (setq-local foreman-docker nil)
              (setq-local foreman-ssh t))
            (process-send-string
             nm
             (format "ssh %s \n" host))
            (process-send-string
             nm
             (format "cd %s \n" filepath))))

         ;; then just create the buffer as usual
         (t
          (with-current-buffer (get-buffer-create nm)
            (vterm-mode)
            (setq-local foreman-docker nil)
            (setq-local foreman-ssh nil)))
         )
        )

      (process-send-string nm (concat "clear\n" program "\n"))

      (switch-to-buffer buf)
      (display-buffer nm)
      )
    )

  :config
  (setq vterm-shell "zsh")

  ;; NOTE written by GPT-4
  (defun send-to-vterm (start end)
    "Send the selected region to a vterm buffer for execution.
Prompt for a vterm buffer and store it as a buffer-local variable."
    (interactive "r")
    (let ((text (buffer-substring-no-properties start end))
          (vterm-buffer (read-buffer "Vterm buffer: " "*vterm*")))
      (with-current-buffer vterm-buffer
        (unless (get 'current-vterm-buffer 'local-variable)
          (make-variable-buffer-local 'current-vterm-buffer)
          (setq current-vterm-buffer vterm-buffer))
        (vterm-send-string text)
        (vterm-send-final))))

  ;; project.el
  ;; todo replace with vterm in project
  (keymap-substitute project-prefix-map #'project-eshell #'vterm)
  (cl-nsubstitute-if
   '(vterm "vterm")
   (pcase-lambda (`(,cmd _)) (eq cmd #'project-eshell))
   project-switch-commands)

  ;; fixes unreadable situation -- comes out brown by default
  ;; note this is dependent on the terminal that launches emacs, I'm
  ;; using iterm2
  (add-to-list 'brushup-styles
               '(progn
                  (set-face-attribute 'vterm-color-yellow nil
                                      :foreground brushup-fg
                                      :background brushup-bg-3)))


  (defun zetta-soda-drink-term ()
    (interactive)
    (zetta-soda-drink (quote zetta-soda-create-and-display-term) (zetta-soda-prompt-term-buffer)))

  (defun zetta-soda-cap-term ()
    (interactive)
    (zetta-soda-cap "\\term-mode*" 1))

  (general-define-key
   :keymaps 'menu-run-map
   "s" (repeatable-lite-wrap zetta-soda-drink-term)
   "S" (repeatable-lite-wrap zetta-soda-cap-term))

  :display
  ;;(zetta-side "^\\*zsh*" 'bottom)
  ;;(zetta-side "^\\*bash*" 'bottom)
  ;;(zetta-side "^\\*python3*" 'bottom 1)
  ;;(zetta-side "^\\*ipython*" 'bottom 1)
  ;;(zetta-side "^\\*ssh*" 'bottom 1)
  ;;(zetta-side "^\\*sqlite3*" 'bottom 2)

  :general
  (
   :states '(insert)
   :keymaps '(vterm-mode-map)
   "C-s" 'vterm-send-C-s
   "C-x" 'vterm-send-C-x
   "<escape>" 'vterm-send-escape
   "C-u" 'universal-argument
   )

  (
   :states '(normal)
   :keymaps '(vterm-mode-map)
   "C-b" 'vterm-send-C-b
   "C-k" 'vterm-send-up
   "C-j" 'vterm-send-down
   )

  :hook ((vterm-mode . (lambda ()
                         (setq global-hl-line-mode nil)
                         (toggle-truncate-lines 1) (display-line-numbers-mode 1)))
         ((vterm-mode shell-command-mode) . tab-line-mode))

  ))
;;; vterm.el ends here
