(use-package vertico-posframe :config (vertico-posframe-mode 1))

(use-package nova
  :ensure (:host github :repo "thisisran/nova")
  :config
  (nova-vertico-mode -1)
  (nova-corfu-mode -1)
  (nova-corfu-popupinfo-mode -1)
  )

(use-package nova-vertico
  :after (nova vertico)
  )


