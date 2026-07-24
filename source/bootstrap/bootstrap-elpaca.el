;;; bootstrap-elpaca.el --- Configure elpaca package manager -*- lexical-binding: t; -*-

;; MUST match the version the pinned elpaca expects (its doc/installer.el;
;; elpaca.el lwarns "installer version does not match" otherwise).  The
;; pinned 7484867 declares 0.12 -- bump this together with the :ref below,
;; never independently.
(defvar elpaca-installer-version 0.12)
(defvar elpaca-directory (expand-file-name "elpaca/" user-emacs-directory))
(defvar elpaca-builds-directory (expand-file-name "builds/" elpaca-directory))
;; The bootstrap clone MUST land in elpaca-sources-directory/elpaca -- the
;; location elpaca itself reads (elpaca.el `elpaca-sources-directory'): the
;; self-order reuses a repo found there, and every package build's
;; autoload subprocess loads sources/elpaca/elpaca.el.  This variable was
;; `elpaca-repos-directory' (dir "repos/") before upstream's 2026 struct
;; redesign; the name here must be the one THE PINNED elpaca.el reads.
;; Getting this wrong is invisible on warm machines and breaks every cold
;; install: a config-invented "sources/" against the old repos-reading
;; elpaca made the self-order re-clone asynchronously and every early
;; cold build raced that clone (measured 2026-07-22: compile-angel's
;; autoload step died file-missing on the elpaca clone, and
;; elpaca-use-package sat "waiting on monorepo" forever).  When flipping
;; the pin across the rename in EITHER direction, re-check this name
;; against the pinned elpaca.el first.
(defvar elpaca-sources-directory (expand-file-name "sources/" elpaca-directory))
;; elpaca is the one package the lockfile cannot pin -- this installer
;; clones it before any lockfile is read -- so it MUST be pinned here.
;; With :ref nil every fresh install got that day's master, whose internal
;; API had drifted from everything written against it (measured 2026-07-22:
;; master had dropped `elpaca--status', and cold installs hung in the
;; tools-category elpaca-wait on CI and on a reader's machine alike, while
;; warm checkouts kept working from their old builds).  Bump this SHA
;; deliberately, together with `zetta freeze', never implicitly.
;; Pinned: master 7484867 (2026-07-21, "elpaca-menu--build: add autoload
;; cookie"); upgraded from 1508298 (2026-01-01) on 2026-07-23.
(defvar elpaca-order '(elpaca :repo "https://github.com/progfolio/elpaca.git"
                              :ref "74848674bfca8590e9286309d11e9645c8425400"
                              :depth nil :inherit ignore
                              :files (:defaults "elpaca-test.el" (:exclude "extensions"))
                              :build (:not elpaca-activate)))
(let* ((repo  (expand-file-name "elpaca/" elpaca-sources-directory))
       (build (expand-file-name "elpaca/" elpaca-builds-directory))
       (order (cdr elpaca-order))
       (default-directory repo))
  ;; Pin self-enforcement: the clone branch below only runs when the repo
  ;; is ABSENT, so a bumped :ref would be silently ignored wherever a
  ;; clone already exists -- warm CI caches (restore-keys prefix-restores
  ;; an older cache into the run) and every local machine alike would
  ;; keep running the old elpaca after a pin flip.  Verify the existing
  ;; checkout against the pin; on mismatch fetch + checkout + recompile,
  ;; drop the stale generated autoloads, and invalidate the stale build
  ;; dir so the re-pinned source is what actually loads.  If convergence
  ;; fails, delete the clone and fall through to a fresh clone below.
  (let ((ref (plist-get order :ref)))
    (when (and ref (file-exists-p (expand-file-name ".git" repo)))
      (let ((head (with-temp-buffer
                    (when (zerop (call-process "git" nil t nil "rev-parse" "HEAD"))
                      (car (split-string (buffer-string)))))))
        (unless (equal head ref)
          (message "elpaca: clone at %s is %s, pin is %s; converging"
                   repo (or head "unreadable") ref)
          (if (with-temp-buffer
                (and (zerop (call-process "git" nil t nil "fetch" "origin"))
                     (zerop (call-process "git" nil t nil "checkout" ref))
                     (zerop (call-process (concat invocation-directory invocation-name)
                                          nil t nil "-Q" "-L" "." "--batch" "--eval"
                                          "(byte-recompile-directory \".\" 0 'force)"))))
              (dolist (stale '("elpaca-autoloads.el" "elpaca-autoloads.elc"))
                (when (file-exists-p (expand-file-name stale repo))
                  (delete-file (expand-file-name stale repo))))
            (warn "elpaca: pin convergence failed; re-cloning at the pin")
            (delete-directory repo 'recursive))
          (when (file-exists-p build) (delete-directory build 'recursive))))))
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
;; would be resident moments later anyway.  (Upstream's installer now
;; ships a `no-byte-compile: t' file-local instead; we compile the
;; bootstrap deliberately, so the eager require stays.)
(require 'elpaca)
;; Matches the upstream installer.  (Until the 2026-07 pin bump this
;; added to `elpaca-after-init-hook' -- an undocumented deviation; both
;; the old and new upstream installers use `after-init-hook'.)
(add-hook 'after-init-hook #'elpaca-process-queues)
(elpaca `(,@elpaca-order))

;; Install use-package support -- activated directly from the bootstrap
;; clone, NOT as an `(elpaca elpaca-use-package ...)' order.  The
;; installer has already cloned AND byte-compiled the extension at the
;; pinned ref; requiring it from there is the same file with no network
;; and no queue coordination, so it is categorically race-free.  History:
;; under the old 1508298 pin the order was a mono-repo partner of the
;; `elpaca' order itself, and its dependency scan read
;; extensions/elpaca-use-package.el before the pinned checkout
;; materialised it (measured cold, 2026-07-22: the order failed
;; file-missing, elpaca-wait returned, use-package silently fell back to
;; package.el -- which cannot parse elpaca recipes, so `general' never
;; installed and the first `general-define-key' crashed init).  Upstream
;; has since fixed the mono-repo deadlock and ships a first-class
;; extensions menu (`elpaca-menu-extensions'), so the standard order is a
;; candidate cleanup -- flip it in its own change, cold-verified, not as
;; part of a pin bump.
(add-to-list 'load-path (expand-file-name "elpaca/extensions"
                                          elpaca-sources-directory))
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
;; Same trap, opposite direction: peg and editorconfig are builtin on
;; Emacs 30+/31 but NOT on 29.4, where they queue as real transitive
;; dependencies -- which a `zetta freeze' run on a newer Emacs can never
;; see, so the LOCK-MISSING gate fired on 29.4 the moment it became
;; enforcing (run 30024877208).  Managing them explicitly queues them on
;; every Emacs, so one freeze covers all supported versions.
;; ...and they must ALSO leave `elpaca-ignored-dependencies', which
;; defaults to the RUNNING Emacs's builtin list -- on Emacs 31 that
;; includes peg and editorconfig, and the old pinned elpaca silently
;; dropped even explicit orders for ignored ids (measured: (elpaca peg)
;; produced no order at all, so `zetta freeze' could never pin them).
;; Newer elpacas auto-un-ignore explicitly ordered ids, but the
;; set-difference is kept: it is harmless and preserves pin-rollback
;; safety.
(setq elpaca-ignored-dependencies
      (cl-set-difference elpaca-ignored-dependencies '(peg editorconfig)))
(elpaca peg)
(elpaca editorconfig)
;; yaml must be ordered here, not in lang/yaml.el: ~/.private.el loads
;; BEFORE the modules (init.el needs its API keys early) and declares
;; swagg, whose dependency scan queues yaml first — so the module's
;; explicit declaration always arrived second, tripping the
;; duplicate-queue warn path AND silently discarding the module's
;; zkry/yaml.el recipe in favor of the menu default.  Ordering it here
;; makes the recipe authoritative and lets every dependent (swagg,
;; consult-gh) resolve against a real order.  lang/yaml.el keeps the
;; config with :ensure nil.
(elpaca (yaml :host github :repo "zkry/yaml.el"))
(elpaca-wait)

;; Fix elpaca bug (verified still present at pin 7484867, elpaca.el
;; `elpaca--enqueue'): when a package is re-declared after being queued
;; as a transitive dependency, the duplicate branch returns the value of
;; `warn' instead of the existing elpaca struct (its own docstring says
;; "Return E.").  In a frameless daemon `warn' returns the rendered
;; warning string, which then crashes queue processing after init with
;; (wrong-type-argument listp ...) -- aborting daemon startup before the
;; server starts (measured 2026-07-23 at the old 1508298 pin: ace-window
;; re-declared after treemacs queued it; `--fg-daemon' exited after every
;; module had loaded).  The function is `elpaca--queue' at 1508298 and
;; `elpaca--enqueue' from 49db2a6 on, so advise BOTH names -- advice on
;; an undefined symbol is inert until the function is defined, which lets
;; the fix survive a pin flip in either direction.  Drop this once the
;; pin reaches an upstream where the duplicate branch returns the struct.
(defun zetta--elpaca-queue-return-struct (fn order &optional queue)
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
(advice-add 'elpaca--queue :around #'zetta--elpaca-queue-return-struct)
(advice-add 'elpaca--enqueue :around #'zetta--elpaca-queue-return-struct)

;; In batch mode (`zetta install'/CI), `after-init-time' is already set
;; before init.el loads, so every declaration runs `elpaca--unprocess',
;; which resets `builtp' -- and the throttle only exempts built packages,
;; so with a limit set EVERYTHING would throttle.  Batch therefore runs
;; unthrottled (nil).  Interactively the limit caps concurrent active
;; builds at 8.  (The old rationale here -- a stale queue-length snapshot
;; in `elpaca--finalize' finalizing the queue prematurely -- no longer
;; describes upstream: queue completion is subscriber-driven and always
;; re-checks the whole queue since the pub-sub redesign.)
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
