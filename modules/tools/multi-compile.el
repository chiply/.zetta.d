;;; multi-compile.el --- Configure multi-compile -*- lexical-binding: t; -*-

;;;;;;;;;;;;;;;; DEPENDENCIES
(use-package templatel)
(use-package compile-multi
  :ensure (:files (:defaults "extensions/*/*.el"))
  :commands compile-multi)
(use-package consult-compile-multi :ensure nil :after compile-multi :config (consult-compile-multi-mode))
(use-package all-the-icons-completion
  :hook (elpaca-after-init . all-the-icons-completion-mode)
  :config
  (add-hook 'marginalia-mode-hook #'all-the-icons-completion-marginalia-setup))
(use-package compile-multi-all-the-icons :ensure nil :after compile-multi)
(use-package compile-multi-embark :ensure nil :after (compile-multi embark) :config (compile-multi-embark-mode +1))
(use-package projection
  :ensure (:files (:defaults "src/*.el" "src/projection-multi/*.el" "src/projection-multi-embark/*.el"))
  :commands projection-mode)
(use-package projection-multi
  :ensure nil
  :after projection
  :config
  (require 'projection-multi-make))
(use-package projection-multi-embark :ensure nil :after (projection embark))

;; VARIABLES
(defvar zmc-extra-project-paths '())
(defvar zmc-cache nil)
(defvar zmc-async-shell-command-spinners-enable nil)

;;;;;;;;;;;;;;;;;; HELPERS
(defun zmc-get-hashtbl (args)
  (ht<-alist
   (-map
    (lambda (e)
      (let* ((kv (split-string e "="))
             (k (string-replace "--" "" (car kv)))
             (v (string-join (cdr kv) "=")))
        `(,k . ,v)))
    args)))

(defun zmc-compute-bufnm ()
  (or (when (boundp 'local-transient) local-transient) latest-transient))

;;;;;;;;;;;;;;;;;;;;;; ACTION
(defun zmc-transient-act (&optional args)
  (interactive
   (list (transient-args
          (intern (or
                   (when (boundp 'local-transient)
                     local-transient)
                   latest-transient)))))
  (let* ((target (zmc-get-hashtbl args))
         (program (ht-get target "program"))
         (command-template (ht-get target "template"))
         (cmd (templatel-render-string command-template (ht->alist target)))
         (_ (ht-set! target "target" cmd))
         (directory (ht-get target "directory"))
         (default-directory (or
                             (and
                              directory
                              (expand-file-name (eval-expression directory)))
                             default-directory))
         (bufnm (ht-get target "bufnm"))
         (side (intern (or (ht-get target "side") "top")))
         (slot (or (ht-get target "slot") 1))
         (select (or (ht-get target "select") "no"))
         (buffer-replace-policy (or (ht-get target "buffer-replace-policy")
                                    "default-buffer-replace-policy"))
         (transient-name (string-replace " " "-" (ht-get target "key"))))
    (setq latest-cmd cmd)
    (set (make-local-variable 'local-cmd) cmd)
    (apply 'zmc-run `(,program ,cmd ,bufnm ,side ,slot ,select ,buffer-replace-policy ,transient-name))))

;;;;;;;;;;;;;;;;;;;;;; TRANSIENT
(defun zmc-define-transient (name htbl)
  (eval
   `(transient-define-prefix ,(intern name) ()
      :value
      (quote
       ,(ht-map (lambda (k v) (concat "--" (string-replace " " "-" k) "=" v)) htbl))
      ,(vconcat
        (vector "Arguments")
        (apply
         'vector
         (ht-map
          (lambda (k v)
            `(,(concat "-" (substring k 0 1)) ,k ,(concat "--" (string-replace " " "-" k) "=")))
          htbl)))
      ["Actions"
       ("<return>" "run" zmc-transient-act)])))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; INTERACTIVE FUNCTION
(defun zmc (&optional arg)
  "Choice target and start compile.
CACHE: 1. latest/local transient 2. ~/.zmc-cache)"
  (interactive "P")
  (cond
   ((and arg (not (equal arg '(64))) (boundp 'local-transient))
    (progn
      (setq latest-transient local-transient)
      (funcall (intern local-transient))
      (unless (equal arg '(16))
        (execute-kbd-macro (kbd "<return>")))))
   ((and arg (not (equal arg '(64))) latest-transient)
    (progn
      (setq-local local-transient latest-transient)
      (funcall (intern latest-transient))
      (unless (equal arg '(16))
        (execute-kbd-macro (kbd "<return>")))))
   (t (let* ((targets
              (if (and (not (equal arg '(64)))
                       (file-exists-p "~/.zmc-cache.yaml")
                       (or zmc-cache
                           (setq zmc-cache
                                 (condition-case nil
                                     (yaml-parse-string
                                      (with-temp-buffer
                                        (insert-file-contents "~/.zmc-cache.yaml")
                                        (buffer-string))
                                      :object-key-type 'string)
                                   ;; a corrupt cache falls through to a
                                   ;; refresh instead of bricking zmc
                                   (error (message "zmc cache unparsable; refreshing") nil)))))
                  (progn
                    (message "using cache")
                    zmc-cache)
                (let* ((_ (message "refreshing cache targets"))
                       (detected-targets (eval (append
                                                '(ht-merge)
                                                (ht-map
                                                 (lambda (k v)
                                                   (zmc-detect-targets
                                                    (ht-get v "build-file-type")
                                                    (ht-get v "build-file-regexp")))
                                                 zmc-config)
                                                (zmc-get-targets "~/" "history" ".zsh_history"))))
                       (config-raw (with-temp-buffer
                                     (insert-file-contents "~/.cmds.yaml")
                                     (buffer-string)))
                       (targets (yaml-parse-string config-raw :object-key-type 'string))
                       (targets (ht-merge detected-targets targets))
                       (_ (progn
                            (setq zmc-cache targets)
                            (with-temp-buffer
                              (insert "-*- coding: raw-text;-*-\n")
                              (insert (yaml-encode targets))
                              (write-file "~/.zmc-cache.yaml")))))
                  targets)))
             (target-keys (ht-keys (ht-select
                                    (lambda (k v) (if t t (eval (ht-get v "if"))))
                                    targets)))
             (key (completing-read "target " target-keys))
             (target (ht-get targets key))
             (_ (ht-set! target "key" key))
             (transient-name (string-replace " " "-" key))
             (_ (zmc-define-transient transient-name target)))
        (setq latest-transient transient-name)
        (set (make-local-variable 'local-transient) transient-name)
        (funcall (intern transient-name))))))

(general-define-key
 :keymaps (append zetta-modal-states-insert zetta-modal-states-non-insert '(override))
 "s-<return>" 'zmc
 "s-r" '(lambda () (interactive)
          (setq current-prefix-arg '(4))
          (call-interactively 'zmc))
 "s-R" '(lambda () (interactive)
          (setq current-prefix-arg '(16))
          (call-interactively 'zmc))
 "C-S-s-r" '(lambda () (interactive)
              (setq current-prefix-arg '(64))
              (call-interactively 'zmc)))

;;;;;;;;;; CONFIG
(setq
 zmc-config
 (ht
  ("make-targets"
   (ht
    ("build-file-type" "make")
    ("build-file-regexp" "makefile\\|Makefile")
    ("template" "make -f ${build-file-name} ${target}")
    ("program" "async-shell-command+")))
  ("python-lsp-targets"
   (ht
    ("build-file-type" "install-python-project-and-lsp-deps")
    ("build-file-regexp" "nx.json")
    ("template" "install_all_lsp_servers \"$(pwd)\"")
    ("program" "async-shell-command+")))
  ("python-lsp-targets-1"
   (ht
    ("build-file-type" "install-python-project-and-lsp-deps")
    ("build-file-regexp" "pyproject.toml")
    ("template" "install_all_lsp_servers \"$(pwd)\"")
    ("program" "async-shell-command+")))
  ("nx-targets"
   (ht
    ("build-file-type" "nx")
    ("build-file-regexp" "project.json")
    ("template" "nx run -t ${target}")
    ("program" "async-shell-command+")))
  ("nx-many-targets"
   (ht
    ("build-file-type" "nx-run-many")
    ("build-file-regexp" "project.json")
    ("template" "nx run-many -t ${target}")
    ("program" "async-shell-command+")))
  ("pytest-targets"
   (ht
    ("build-file-type" "pytest")
    ("build-file-regexp" "pyproject.toml")
    ("template" "poetry run pytest -vvv ${target}")
    ("program" "async-shell-command+")))
  ("python-test-targets"
   (ht
    ("build-file-type" "python-test")
    ("build-file-regexp" "pyproject.toml")
    ("template" "poetry run pytest -vvv")
    ("program" "async-shell-command+")))
  ("ipython-targets"
   (ht
    ("build-file-type" "ipython")
    ("build-file-regexp" "pyproject.toml")
    ("template" "poetry run ipython")
    ("program" "vterm")))
  ("python-targets"
   (ht
    ("build-file-type" "python")
    ("build-file-regexp" "pyproject.toml")
    ("template" "poetry run python")
    ("program" "vterm")))
  ("tmuxinator-targets"
   (ht
    ("build-file-type" "tmuxinator")
    ("build-file-regexp" "\\.tmuxinator\\.yaml")
    ("template" "tmuxinator start --suppress-tmux-version-warning -p ${build-file-name}")
    ("program" "vterm")))
  ("bash-script-targets"
   (ht
    ("build-file-type" "shell script")
    ("build-file-regexp" "\\.sh")
    ("template" "./${build-file-name}")
    ("program" "vterm")))))
;;; multi-compile.el ends here
