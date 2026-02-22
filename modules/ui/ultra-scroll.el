;;; ultra-scroll.el --- Configure ultra-scroll -*- lexical-binding: t; -*-

(use-package ultra-scroll
  ;:load-path "~/code/emacs/ultra-scroll" ; if you git clone'd instead of package-vc-install
  :ensure (ultra-scroll :type git :host github :repo "jdtsmith/ultra-scroll")
  :init
  (setq scroll-conservatively 101 ; important!
        scroll-margin 0)
  :config
  (ultra-scroll-mode 1))
;;; ultra-scroll.el ends here
