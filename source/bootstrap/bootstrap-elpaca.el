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
;; In batch mode (e.g. `zetta install`), after-init-time is already set before
;; init.el loads, which causes elpaca--unprocess to reset builtp on all packages.
;; With builtp=nil, queue throttling applies.  The unthrottle code path in
;; elpaca--finalize can trigger synchronous dependency processing that grows the
;; queue, but elpaca--finalize's stale snapshot of the queue length causes a
;; premature finalize-queue call before all packages are activated, resulting in
;; "Cannot load" errors for tail-end packages.  Disabling the queue limit in
;; batch mode avoids the throttle code path entirely.
(setq elpaca-queue-limit (unless noninteractive 8))

;; Enable lockfile for reproducible builds.
;; The lockfile pins all packages to exact commits.
;; Set `zetta-use-lockfile' to nil in ~/.zetta.el to use latest versions.
(setq elpaca-lock-file (expand-file-name "elpaca-lock.el" user-emacs-directory))

;; use-package is built-in in Emacs 29+, but we configure it after elpaca-use-package is ready
(setq use-package-always-ensure t)
(setq use-package-inject-hooks t)

(global-set-key (kbd "s-u") 'elpaca-fetch-all)
(global-set-key (kbd "s-U") 'elpaca-pull-all)

(provide 'bootstrap-elpaca)
;;; bootstrap-elpaca.el ends here
