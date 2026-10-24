;;; early-init.el --- Configure early initialization -*- lexical-binding: t; -*-

;; Disable built-in package manager (using Elpaca instead)
(setq package-enable-at-startup nil)

;; Disable UI elements early (before frame creation - faster than doing it later)
(push '(tool-bar-lines . 0) default-frame-alist)
(push '(menu-bar-lines . 0) default-frame-alist)
(push '(vertical-scroll-bars) default-frame-alist)

;; Defer garbage collection during init (huge speedup)
(setq gc-cons-threshold most-positive-fixnum
      gc-cons-percentage 0.6)

;; Restore reasonable GC settings after init.
(defun zetta--restore-gc ()
  "Restore GC settings after init."
  (setq gc-cons-threshold (* 16 1024 1024)  ; 16MB
        gc-cons-percentage 0.1))
(add-hook 'emacs-startup-hook #'zetta--restore-gc)

;; Bypass file-name-handler-alist during init (~90-120ms savings).
;; Every require/load checks this regex list for TRAMP, compression, etc.
;; None of that is needed during startup.
(defvar zetta--file-name-handler-alist file-name-handler-alist)
(setq file-name-handler-alist nil)
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq file-name-handler-alist zetta--file-name-handler-alist)))

;; Skip source vs bytecode mtime checks during init.
;; Safe because we control when bytecode is compiled via `zetta install`.
(setq load-prefer-newer nil)

;; Library lookup.  `load' tries FILE + every suffix in every directory of
;; `load-path', one `stat' each.  With elpaca the path is ~400 entries
;; long and the 354 package directories come FIRST -- Emacs's own lisp
;; starts at position 373 -- so every `require' of a built-in library (433
;; of them at init, ~1550 loads in all) walks the whole package list: ~4.5 ms
;; a hit, ~10 ms a miss, measured live 2026-10-23.  Emacs 31 added
;; `load-path-filter-function', a hook that drops the directories which
;; cannot hold FILE.  The bundled `load-path-filter-cache-directory-files'
;; halved the cost in a batch A/B over 70 built-in libraries (2.4-2.9 s ->
;; 1.9-2.1 s); it keeps each listing as a list, matches with
;; `try-completion', and declines to filter when "" is among the suffixes
;; (a plain `load', no must-suffix).  This one keeps a hash set per
;; directory and filters every call: 1.0-1.2 s on the same A/B.  See
;; OPTIMIZATIONS.org, round 2.
;;
;; The cache is a snapshot.  A file ADDED to a directory already listed is
;; invisible to `load' until `zetta-load-path-filter-reset' runs; a new
;; directory is simply read on first use.  The reset runs after every
;; elpaca queue (a rebuild changes files in place).  compile-angel writes
;; beside module files, which are loaded by path, not through `load-path'.
;; Nothing in the filter may call an AUTOLOADED function: it runs inside
;; `load', and an autoload from there recurses (`cl-some' did, in the A/B).
(defvar zetta-load-path-filter--cache (make-hash-table :test #'equal)
  "Directory name -> hash set of the file names in it.")

(defun zetta-load-path-filter-reset (&rest _)
  "Forget the directory listings cached by `zetta-load-path-filter'."
  (clrhash zetta-load-path-filter--cache))

(defun zetta-load-path-filter (path file suffixes)
  "The directories of PATH that hold FILE with one of SUFFIXES.
A nil entry (the current directory) is kept unexamined."
  (if (or (file-name-absolute-p file) (file-name-directory file))
      path
    (let (keep)
      (dolist (dir path)
        (if (null dir)
            (push dir keep)
          (let ((files (gethash dir zetta-load-path-filter--cache 'miss)))
            (when (eq files 'miss)
              (setq files (make-hash-table :test #'equal))
              (dolist (f (condition-case nil (directory-files dir nil nil t) (error nil)))
                (puthash f t files))
              (puthash dir files zetta-load-path-filter--cache))
            (let ((ss suffixes) hit)
              (while (and ss (not hit))
                (setq hit (gethash (concat file (car ss)) files)
                      ss (cdr ss)))
              (when hit (push dir keep))))))
      (nreverse keep))))

(when (boundp 'load-path-filter-function)   ; Emacs 31+
  (setq load-path-filter-function #'zetta-load-path-filter)
  ;; The defcustom keeps a value already set by `add-hook'.
  (add-hook 'elpaca-post-queue-hook #'zetta-load-path-filter-reset))

;; Never let Emacs's deferred native compilation touch the bootstrap.
;; When a bootstrap .elc is loaded with no .eln beside it, Emacs queues
;; the SOURCE for compilation in a bare `emacs -Q --batch' worker.  That
;; worker has stock use-package and no elpaca, so `:ensure (:wait t)'
;; expands to package.el semantics, and the resulting .eln, which Emacs
;; prefers over the .elc at the NEXT start, aborts in bootstrap-keys
;; ("Cannot load key-chord", then void-function general-define-key)
;; before ~/.zetta.el is read -- a daemon with the default module list
;; and none of it loaded.  Measured on the hub 2026-09-11 (second
;; restart after a build), and it is why a batch `-l init.el' fails on
;; any machine whose eln-cache carries these files.  The phase-2 .elc
;; from `bin/zetta' is compiled inside an Emacs that has init.el loaded
;; and is fine.  compile-angel already excludes this directory; this is
;; the same exclusion for the built-in JIT.  Emacs 29 and 30+ names.
(setq native-comp-deferred-compilation-deny-list '("/source/bootstrap/" "/source/init-data/")
      native-comp-jit-compilation-deny-list '("/source/bootstrap/" "/source/init-data/"))

;; Emacs 31: no new background native compilations while on battery.  The
;; .eln is compiled the next time the file loads on mains power.
(when (boundp 'native-comp-async-on-battery-power)
  (setq native-comp-async-on-battery-power nil))

;; Suppress all rendering during init (restored automatically on frame creation)
;; Don't suppress messages in daemon mode — there's no frame, so
;; window-setup-hook never fires to restore them, and we want to see
;; startup progress in the terminal.
(setq inhibit-redisplay t)
(unless (daemonp)
  (setq inhibit-message t))
(add-hook 'window-setup-hook
          (lambda ()
            (setq inhibit-redisplay nil
                  inhibit-message nil)
            (redisplay)))

;; Use fundamental-mode for *scratch* (avoids loading text-mode machinery)
(setq initial-major-mode 'fundamental-mode
      initial-scratch-message nil)

;; Faster subprocess I/O (default 4KB; benefits LSP, compilation, etc.)
(setq read-process-output-max (* 4 1024 1024))  ; 4MB

;; Prevent flash of unstyled modeline at startup
(setq-default mode-line-format nil)

;; Don't resize frame at startup
(setq frame-inhibit-implied-resize t)

;; Disable bidirectional text scanning for performance
(setq-default bidi-display-reordering 'left-to-right
              bidi-paragraph-direction 'left-to-right)
(setq bidi-inhibit-bpa t)

;; Don't compact font caches during GC (expensive, especially with icon fonts)
(setq inhibit-compacting-font-caches t)

;; Skip rendering cursors/highlights in unfocused windows
(setq-default cursor-in-non-selected-windows nil)
(setq highlight-nonselected-windows nil)

;; Not `fast-but-imprecise-scrolling': it lets a long scroll skip
;; fontification, so text is painted in the body face and reshaped once its
;; faces arrive -- a visible jitter under any preset whose faces carry
;; different families.  See "Fontification stays INSIDE redisplay" in
;; modules/core/interface.el.
(setq fast-but-imprecise-scrolling nil)

;; Reduce idle UI refresh frequency (default 0.5s)
(setq idle-update-delay 1.0)

;; Don't attempt DNS lookups on strings that look like hostnames
(setq ffap-machine-p-known 'reject)

;; `set-auto-mode' runs the whole of `auto-mode-alist' a second time,
;; case-insensitively, when the case-sensitive pass finds nothing.  No file
;; here depends on that.  (Doom, minimal-emacs.d.)
(setq auto-mode-case-fold nil)
;;; early-init.el ends here
