;;; consult-mu.el --- Configure consult-mu -*- lexical-binding: t; -*-

;; mu4e is set up in ~/.private.el (loaded eagerly before modules), so
;; :after mu4e fires here without needing further deferral.
;;
;; The extras/ subpackages (embark, contacts, compose) install their
;; integrations at `require' time — no minor-mode toggle exists.

(use-package consult-mu
  :if (executable-find "mu")
  :ensure (consult-mu
           :host github
           :repo "armindarvish/consult-mu"
           :branch "main"
           :files (:defaults "extras/*.el"))
  :after (mu4e consult)

  :config
  (setq consult-mu-maxnum 200
        consult-mu-search-sort-field :date
        consult-mu-search-sort-direction 'descending
        consult-mu-search-threads nil
        consult-mu-group-by :date
        consult-mu-mark-previewed-as-read nil
        consult-mu-mark-viewed-as-read nil
        consult-mu-use-wide-reply nil
        consult-mu-preview-key "C-="
        consult-mu-action #'consult-mu--view-action)

  (with-eval-after-load 'embark
    (require 'consult-mu-embark))

  (require 'consult-mu-contacts)
  (setq consult-mu-contacts-action #'consult-mu-contacts--list-messages-action)
  (with-eval-after-load 'embark
    (require 'consult-mu-contacts-embark))

  (require 'consult-mu-compose)
  (setq consult-mu-compose-use-dired-attachment 'in-mu4e)
  (with-eval-after-load 'embark
    (require 'consult-mu-compose-embark))

  (general-define-key
   :keymaps 'launch-map
   "m" 'consult-mu))

;;; consult-mu.el ends here
