;;; mw-thesaurus.el --- Configure mw-thesaurus -*- lexical-binding: t; -*-

(use-package mw-thesaurus
  :general
  (
   :keymaps 'menu-lookup-map
   "s" 'mw-thesaurus-lookup-at-point
   "S" 'mw-thesaurus-lookup
   )
  )
;;; mw-thesaurus.el ends here
