;;; bootstrap-elpaca.el --- Configure elpaca package manager -*- lexical-binding: t; -*-

(defvar elpaca-installer-version 0.11)
(defvar elpaca-directory (expand-file-name "elpaca/" user-emacs-directory))
(defvar elpaca-builds-directory (expand-file-name "builds/" elpaca-directory))
(defvar elpaca-repos-directory (expand-file-name "repos/" elpaca-directory))
(defvar elpaca-order '(elpaca :repo "https://github.com/progfolio/elpaca.git"
                              :ref nil :depth 1 :inherit ignore
                              :files (:defaults "elpaca-test.el" (:exclude "extensions"))
                              :build (:not elpaca--activate-package)))
(let* ((repo  (expand-file-name "elpaca/" elpaca-repos-directory))
       (build (expand-file-name "elpaca/" elpaca-builds-directory))
       (order (cdr elpaca-order))
       (default-directory repo))
  (add-to-list 'load-path (if (file-exists-p build) build repo))
  (unless (file-exists-p repo)
    (make-directory repo t)
    (when (<= emacs-major-version 28) (require 'subr-x))
    (condition-case-unless-debug err
        (if-let* ((buffer (pop-to-buffer-same-window "*elpaca-bootstrap*"))
                  ((zerop (apply #'call-process `("git" nil ,buffer t "clone"
                                                  ,@(when-let* ((depth (plist-get order :depth)))
                                                      (list (format "--depth=%d" depth) "--no-single-branch"))
                                                  ,(plist-get order :repo) ,repo))))
                  ((zerop (call-process "git" nil buffer t "checkout"
                                        (or (plist-get order :ref) "--"))))
                  (emacs (concat invocation-directory invocation-name))
                  ((zerop (call-process emacs nil buffer nil "-Q" "-L" "." "--batch"
                                        "--eval" "(byte-recompile-directory \".\" 0 'force)")))
                  ((require 'elpaca))
                  ((elpaca-generate-autoloads "elpaca" repo)))
            (progn (message "%s" (buffer-string)) (kill-buffer buffer))
          (error "%s" (with-current-buffer buffer (buffer-string))))
      ((error) (warn "%s" err) (delete-directory repo 'recursive))))
  (unless (require 'elpaca-autoloads nil t)
    (require 'elpaca)
    (elpaca-generate-autoloads "elpaca" repo)
    (let ((load-source-file-function nil)) (load "./elpaca-autoloads"))))
(add-hook 'elpaca-after-init-hook #'elpaca-process-queues)
(elpaca `(,@elpaca-order))

;; Install use-package support
;; Use :wait to ensure elpaca-use-package-mode is active before subsequent use-package calls
(elpaca elpaca-use-package
  (elpaca-use-package-mode))
(elpaca-wait)  ;; Block until elpaca-use-package is ready

;; Configure use-package to use Elpaca by default
(setq elpaca-use-package-by-default t)
(setq elpaca-queue-limit 8)

;; Enable lockfile for reproducible builds.
;; The lockfile pins all packages to exact commits.
;; Set `zetta-use-lockfile' to nil in ~/.zetta.el to use latest versions.
(setq elpaca-lock-file (expand-file-name "elpaca-lock.el" user-emacs-directory))

;; use-package is built-in in Emacs 29+, but we configure it after elpaca-use-package is ready
(setq use-package-always-ensure t)
(setq use-package-inject-hooks t)

(defun use-package-handle-forms (name _keyword arg rest state)
  (let* ((body (use-package-process-keywords name rest state))
         (name-symbol (use-package-as-symbol name)))
    (use-package-concat
     (when use-package-compute-statistics
       `((use-package-statistics-gather :config ',name nil)))
     (if (and (or (null arg) (equal arg '(t))) (not use-package-inject-hooks))
         body
       (use-package-with-elapsed-timer
           (format "Configuring package %s" name-symbol)
         (funcall use-package--hush-function :config
                  (use-package-concat
                   (use-package-hook-injector
                    (symbol-name name-symbol) :config arg)
                   body
                   (list t)))))
     (when use-package-compute-statistics
       `((use-package-statistics-gather :config ',name t))))))

(global-set-key (kbd "s-u") 'elpaca-fetch-all)
(global-set-key (kbd "s-U") 'elpaca-pull-all)

(provide 'bootstrap-elpaca)
;;; bootstrap-elpaca.el ends here
