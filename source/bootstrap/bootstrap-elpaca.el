;;; bootstrap-elpaca.el --- Configure elpaca package manager -*- lexical-binding: t; -*-

(defvar elpaca-installer-version 0.12)
(defvar elpaca-directory (expand-file-name "elpaca/" user-emacs-directory))
(defvar elpaca-builds-directory (expand-file-name "builds/" elpaca-directory))
;; The bootstrap clone MUST land in elpaca-repos-directory/elpaca -- the
;; location elpaca itself reads (elpaca.el `elpaca-repos-directory'): the
;; self-order reuses a repo found there, and every package build's
;; autoload subprocess loads repos/elpaca/elpaca.el.  The previous
;; config-invented "sources/" directory was invisible to elpaca, so the
;; self-order re-cloned the repo asynchronously and every early cold
;; build raced that clone (measured 2026-07-22: compile-angel's autoload
;; step died file-missing on repos/elpaca/elpaca.el, and
;; elpaca-use-package sat "waiting on monorepo" forever).
(defvar elpaca-repos-directory (expand-file-name "repos/" elpaca-directory))
;; elpaca is the one package the lockfile cannot pin -- this installer
;; clones it before any lockfile is read -- so it MUST be pinned here.
;; With :ref nil every fresh install got that day's master, whose internal
;; API had drifted from everything written against it (measured 2026-07-22:
;; master had dropped `elpaca--status', and cold installs hung in the
;; tools-category elpaca-wait on CI and on a reader's machine alike, while
;; warm checkouts kept working from their old builds).  Bump this SHA
;; deliberately, together with `zetta freeze', never implicitly.
(defvar elpaca-order '(elpaca :repo "https://github.com/progfolio/elpaca.git"
                              :ref "1508298c1ed19c81fa4ebc5d22d945322e9e4c52"
                              :depth nil :inherit ignore
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
;; Load elpaca NOW, not lazily via the `elpaca' macro's autoload.  When
;; this file is byte-compiled (`zetta install'/`zetta sync' compile the
;; bootstrap), the macro calls below are already expanded into direct
;; calls to elpaca internals (`elpaca--expand-declaration'), so loading
;; the .elc crashes void-function before any autoload can fire.  That
;; broke every interactive startup after the 2026-07-23 cold install,
;; while CI and the installer never noticed -- both always load the
;; bootstrap from source (install deletes .elc first; compile-angel
;; excludes the bootstrap dir).  `require' is idempotent, and elpaca
;; would be resident moments later anyway.
(require 'elpaca)
(add-hook 'elpaca-after-init-hook #'elpaca-process-queues)
(elpaca `(,@elpaca-order))

;; Install use-package support -- activated directly from the bootstrap
;; clone, NOT as an `(elpaca elpaca-use-package ...)' order.  That order is
;; a monorepo partner of the `elpaca' order itself, and with a pinned :ref
;; its dependency scan reads repos/elpaca/extensions/elpaca-use-package.el
;; before the pinned checkout materialises it (measured cold, 2026-07-22:
;; the order fails file-missing, elpaca-wait returns, use-package silently
;; falls back to package.el -- which cannot parse elpaca recipes, so
;; `general' never installs and the first `general-define-key' crashes
;; init).  The installer has already cloned AND byte-compiled the extension
;; at the pinned ref; requiring it from there is the same file with no
;; network and no monorepo coordination.
(add-to-list 'load-path (expand-file-name "elpaca/extensions"
                                          elpaca-repos-directory))
(require 'elpaca-use-package)
(elpaca-use-package-mode)

;; Elpaca-manage compat and track-changes explicitly, before any module can
;; resolve them as "satisfied by builtin".  Emacs 30.x is the middle-child
;; trap: new enough to carry builtin equivalents (track-changes 1.2;
;; compat-as-builtin 30.2.x), old enough that they sit below what current
;; packages require (elfeed 4.0.1 wants compat>=31, copilot wants
;; track-changes>=1.4) -- and once a first dependent accepts the builtin,
;; a later, stricter dependent hard-fails instead of fetching (measured:
;; run 29961031175/30.2, elfeed and copilot both failed
;; elpaca--check-version while 29.4 -- no builtins, fresh fetch -- and
;; Emacs 31 -- new-enough builtins -- both passed).  Explicit early orders
;; make the ELPA versions the installed truth on every Emacs.
(elpaca compat)
(elpaca track-changes)
(elpaca-wait)

;; Fix elpaca bug: when a package is re-declared after being queued as a
;; transitive dependency, elpaca--enqueue returns the `warn' string instead of
;; the existing elpaca struct, causing elpaca--expand-declaration to crash
;; with (wrong-type-argument listp ...) when it tries to access struct fields.
;; Renamed from elpaca--queue to elpaca--enqueue in elpaca 0.12.
(define-advice elpaca--enqueue (:around (fn order &optional queue) fix-duplicate-return)
  "Return existing elpaca struct for duplicate packages instead of warn string."
  (if-let* ((id (elpaca--first (or order (signal 'wrong-type-argument
                                                 '((or symbolp listp) nil)))))
            ((not after-init-time))
            (e (elpaca-get id)))
      (progn
        (if-let* ((dependents (elpaca<-dependents e)))
            (warn "%S previously queued as dependency of: %S" id dependents)
          (warn "Duplicate item ID queued: %S" id))
        e)
    (funcall fn order queue)))

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
