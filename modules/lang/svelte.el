;;; svelte.el --- Configure svelte-mode -*- lexical-binding: t; -*-

(use-package svelte-mode
  :mode "\\.svelte\\'"
  :general
  (:keymaps 'svelte-mode-map
            :states '(normal visual)
            "s-i" 'lsp-format-buffer))

;; NOTE not ready for primetime yet -- issues getting it to activate
;; and issues installing the svelte grammar... probably an hour taskt
;; o get this complet, so using the older svelte-mode for now without
;; treesitter
;;(use-package svelte-ts-mode
;;:ensure (svelte-ts-mode :type git :host github :repo "leafOfTree/svelte-ts-mode")
;;:config
;;(add-to-list 'treesit-language-source-alist svelte-ts-mode-language-source-alist)
;;(add-to-list 'auto-mode-alist '("\\.svelte\\'" . svelte-ts-mode)))
;;; svelte.el ends here
