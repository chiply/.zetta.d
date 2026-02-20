(use-package ibuffer
  :ensure nil
  :commands ibuffer

  :init
  (defun zetta-soda-create-and-display-ibuffer (&optional buf-or-mode-name)
    (interactive)
    (ibuffer nil buf-or-mode-name nil []))

  (defun zetta-soda-drink-ibuffer ()
    (interactive)
    (zetta-soda-drink (quote zetta-soda-create-and-display-ibuffer) "*Ibuffer*"))

  (defun zetta-soda-cap-ibuffer ()
    (interactive)
    (zetta-soda-cap "*Ibuffer*"))

  (general-define-key
   :keymaps 'menu-run-map
   "b" (** zetta-soda-drink-ibuffer)
   "B" (** zetta-soda-cap-ibuffer))

  :hook (
         (ibuffer-mode . (lambda () (visual-line-mode -1)))
         (ibuffer-mode . (lambda () (text-scale-set -2)))
         (ibuffer-mode . (lambda () (ibuffer-auto-mode 1)))
         )
  )
