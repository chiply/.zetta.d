;; -*- lexical-binding: t; -*-
;;
;; ~/.zetta.el — WORK profile for Zetta Emacs
;;
;; The full GUI config for an employer-managed Mac, minus everything that
;; reads or writes a personal account, moves data to personal
;; infrastructure, or is a toy: mail (mu4e and its four satellites), feeds
;; and read-later, social and chat (mastodon, bluesky, reddit, irc,
;; signal), music, the ~/kb sync and retrieval stack (chiply-isr, irs,
;; llm-convo, yt-transcript, pdfnote), web search on personal API keys
;; (consult-omni), weather, dictation and the games.  Kept, by the owner's
;; decision of 2026-09-13: the AI stack (on work keys), the org task system
;; and hyperbole/hywiki (on a work-local kb), Jira and Slack (parameterised
;; so nothing employer-specific ever lives in a module).  The reasoning
;; per module is work-profile.org Part 2; the audit that precedes this
;; file is work-security-audit.org.
;;
;; Install it as ~/.zetta.el BEFORE the first `bin/zetta install': the
;; installer copies the full-profile example into place when the file is
;; missing, and the full profile builds and starts the personal apps.
;; The .files work profile does this copy (work-profile.org Part 6).
;;
;; Parser rule (bootstrap-modules.el): within one category the list is
;; either all inclusions or all exclusions, never both.  :app has more out
;; than in, so it is an inclusion list, written in the default load order.

;;; ————————————————————————————————————————————————
;;; Which machine this is
;;; ————————————————————————————————————————————————

;; Informational today; `bin/zetta doctor' reports it after WP-Z10 and
;; modules may test it, though none should need to: policy lives here,
;; in the module lists, not in the modules.
(setq zetta-profile 'work)

;;; ————————————————————————————————————————————————
;;; The kb: a local tree, never synced
;;; ————————————————————————————————————————————————

;; The org task system, hyperbole's rolo and hywiki, org-remark and the
;; eww downloads all read `~/kb/...' (measured 2026-09-13: 40 literal
;; references across 20 files, ten of them in modules/app/hyperbole.el;
;; work-profile.org Part 3).  Day one keeps the path and makes it a WORK
;; tree: local, unsynced, never registered with Syncthing, never touched
;; by hub-deploy.  Phase 2 (task WP-Z9) turns the root into one variable.
;; `zetta-logseq-dir' is the (todo) corpus; its default is already this.
(setq zetta-logseq-dir "~/kb/todo/")

;; The skeleton the kept modules expect, created once and idempotently:
;; the capture templates append to inbox.org (modules/org/org.el), the
;; agenda reads (todo)*.org from todo/, hywiki lives in wiki/, org-remark
;; keeps its notes in org-remark/.  hyrolo drops missing entries from its
;; file list on its own (hyperbole.el, `seq-filter #'file-exists-p'), so
;; nothing else needs to exist.  A starter routine table for org-routine
;; is testdata/routine.org: copy it to ~/kb/notes/schedule.org when the
;; queue first asks for one.
(let ((kb (expand-file-name "~/kb/")))
  (dolist (dir '("todo/" "notes/" "wiki/" "org-remark/"))
    (make-directory (concat kb dir) t))
  (let ((inbox (concat kb "inbox.org")))
    (unless (file-exists-p inbox)
      (with-temp-file inbox (insert "#+title: Inbox\n")))))

;;; ————————————————————————————————————————————————
;;; Keep per-machine state out of the checkout
;;; ————————————————————————————————————————————————

;; Customize writes to init.el when `custom-file' is unset, and tramp
;; saves its connection-local profiles through Customize on its own --
;; which is how a previous laptop's hostname ended up in the tracked
;; init.el (work-security-audit.org S3).  init.el now defaults the file
;; to this path and loads it after the modules; the line stays here so
;; the choice is explicit on a work machine.  Saves land here, gitignored.
(setq custom-file (expand-file-name ".data/custom.el" user-emacs-directory))

;; Backups and auto-saves out of the work trees (most repos gitignore
;; `*~' anyway; this keeps them from being written there at all).
(let ((backups (expand-file-name ".data/backups/" user-emacs-directory))
      (autosaves (expand-file-name ".data/autosaves/" user-emacs-directory)))
  (make-directory backups t)
  (make-directory autosaves t)
  (setq backup-directory-alist `(("." . ,backups))
        auto-save-file-name-transforms `((".*" ,autosaves t))
        backup-by-copying t
        delete-old-versions t))

;;; ————————————————————————————————————————————————
;;; Secrets: no personal vault on this machine
;;; ————————————————————————————————————————————————

;; The personal 1Password service-account token never comes here; nothing
;; below resolves an item from the Dev vault.  Work credentials (a GitHub
;; token, an LLM key if the employer allows one) go in ~/.authinfo.gpg,
;; or in whatever vault the employer issues -- work-profile.org Part 4
;; describes how that plugs in without editing init.el.
;;
;; Until the backend switch lands (task WP-Z2), init.el turns the
;; 1Password backend on whenever an `op' binary exists and this file
;; cannot veto it, so if the employer installs 1Password CLI the work
;; ~/.private.el must set `auth-sources' itself (draft in work-profile.org
;; Part 3).  After WP-Z2 this line is the whole decision:
(setq zetta-secrets-backend 'authinfo)

;;; ————————————————————————————————————————————————
;;; AI: work backends only
;;; ————————————————————————————————————————————————

;; modules/tools/ai.el registers the personal OpenRouter backend (keyed
;; from the 1Password cache or ~/source_code/my-ai/.env) and the local
;; router proxy on :8765, and makes OpenRouter the default.  Neither
;; exists here.  After task WP-Z6 this keeps both unregistered and leaves
;; the default backend to ~/.private.el (Claude via auth-source, or the
;; employer's gateway); before it, they are registered but unusable and
;; the private file's `with-eval-after-load' picks the default.
(setq zetta-ai-personal-backends nil)

;;; ————————————————————————————————————————————————
;;; Appearance
;;; ————————————————————————————————————————————————

;; Same chrome font as the personal machine; the Brewfile's font casks
;; install it on both.  Falls back to `zetta-svg-line-font' if absent.
(setq zetta-svg-line-fonts '(:tab-bar "Monaspace Krypton NF"))

;;; ————————————————————————————————————————————————
;;; Modules
;;; ————————————————————————————————————————————————

(zetta-modules!
 :core
 ;; chiply-isr auto-indexes ~/org and ~/src into a local vector DB from
 ;; emacs-startup-hook and starts its FastAPI server; consult-mu is mail;
 ;; consult-omni is web search on personal Google/Brave/YouTube/
 ;; StackExchange keys.  copilot-isr stays: it drives the Copilot
 ;; language server, which a work seat provides.
 :completion (-chiply-isr -consult-mu -consult-omni)
 :ui
 :editor
 :lang
 ;; gnus is a news reader; irs spawns the personal retrieval backend from
 ;; a personal checkout; signel starts a Signal daemon at load and keeps
 ;; plaintext message history under the config directory.  jira and
 ;; slack stay, on the parameterised modules (tasks WP-Z3/WP-Z4): the
 ;; instance URL, JQLs and workspace registrations come from
 ;; ~/.private.el, never from a module.
 :tools (-gnus -irs -signel)
 ;; Inclusion list, in the default load order.  Reference lookups first
 ;; (network, no account), then bookmarks and places, prose width,
 ;; workspaces, the browser, the editor-code-assistant, and hyperbole with
 ;; its two hywiki helpers.  Out: anki, bluesky, elfeed, erc, flappy-fish,
 ;; key-quiz, llm-convo, mastodon, md4rd, mu4e-dashboard, nano-mu4e, nov,
 ;; org-msg, pocket-reader, reddigg, say, speed-type, spot, spot4e, spray,
 ;; touchtype, whisper, wombag, wttrin, yt-transcript.
 :app (unidecode define-word mw-thesaurus sx pubmed helm-wikipedia
       bookmark-view bookmark bookmark-in-project dogears
       olivetti activities eww eca-emacs
       hyperbole hywiki-alias hywiki-graph)
 ;; pdfnote is the iPad-annotations -> Logseq sync.  pdf-tools itself
 ;; stays (a PDF viewer is a PDF viewer); so do the literature modules,
 ;; which read `zetta-literature-dir' and are inert without a bibliography.
 :org (-pdfnote)
 :term)

;;; ————————————————————————————————————————————————
;;; User packages
;;; ————————————————————————————————————————————————

;; Work-only use-package declarations go here, after the distro modules.

;;; ————————————————————————————————————————————————
;;; Keybinding overrides
;;; ————————————————————————————————————————————————

;; (general-define-key
;;  :keymaps 'launch-map
;;  "x" 'my-work-command)
