((ace-jump-mode :source "elpaca-menu-lock-file" :recipe
                (:package "ace-jump-mode" :repo
                          "winterTTr/ace-jump-mode" :fetcher github
                          :files
                          ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                           "*.texinfo" "doc/dir" "doc/*.info"
                           "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                           "docs/dir" "docs/*.info" "docs/*.texi"
                           "docs/*.texinfo"
                           (:exclude ".dir-locals.el" "test.el"
                                     "tests.el" "*-test.el"
                                     "*-tests.el" "LICENSE" "README*"
                                     "*-pkg.el"))
                          :source "MELPA" :protocol https :inherit t
                          :depth treeless :ref
                          "8351e2df4fbbeb2a4003f2fb39f46d33803f3dac"))
 (ace-mc :source "elpaca-menu-lock-file" :recipe
         (:package "ace-mc" :repo "mm--/ace-mc" :fetcher github :files
                   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                    "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                    "doc/*.texinfo" "lisp/*.el" "docs/dir"
                    "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                    (:exclude ".dir-locals.el" "test.el" "tests.el"
                              "*-test.el" "*-tests.el" "LICENSE"
                              "README*" "*-pkg.el"))
                   :source "MELPA" :protocol https :inherit t :depth
                   treeless :ref
                   "6877880efd99e177e4e9116a364576def3da391b"))
 (ace-window :source "elpaca-menu-lock-file" :recipe
             (:package "ace-window" :repo "abo-abo/ace-window"
                       :fetcher github :files
                       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                        "*.texinfo" "doc/dir" "doc/*.info"
                        "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                        "docs/dir" "docs/*.info" "docs/*.texi"
                        "docs/*.texinfo"
                        (:exclude ".dir-locals.el" "test.el"
                                  "tests.el" "*-test.el" "*-tests.el"
                                  "LICENSE" "README*" "*-pkg.el"))
                       :source "MELPA" :protocol https :inherit t
                       :depth treeless :ref
                       "77115afc1b0b9f633084cf7479c767988106c196"))
 (adaptive-wrap :source "elpaca-menu-lock-file" :recipe
                (:package "adaptive-wrap" :repo
                          ("https://github.com/emacsmirror/gnu_elpa"
                           . "adaptive-wrap")
                          :branch "externals/adaptive-wrap" :files
                          ("*" (:exclude ".git")) :source "GNU ELPA"
                          :protocol https :inherit t :depth treeless
                          :ref
                          "cb759c0ad5a3203464687c09dbe0e56464c2126e"))
 (ag :source "elpaca-menu-lock-file" :recipe
     (:package "ag" :repo "Wilfred/ag.el" :fetcher github :files
               ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
                "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
                "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
                "docs/*.texinfo"
                (:exclude ".dir-locals.el" "test.el" "tests.el"
                          "*-test.el" "*-tests.el" "LICENSE" "README*"
                          "*-pkg.el"))
               :source "MELPA" :protocol https :inherit t :depth
               treeless :ref
               "ed7e32064f92f1315cecbfc43f120bbc7508672c"))
 (aio :source "elpaca-menu-lock-file" :recipe
      (:package "aio" :fetcher github :repo "skeeto/emacs-aio" :files
                ("aio.el" "README.md" "UNLICENSE") :source "MELPA"
                :protocol https :inherit t :depth treeless :ref
                "0e94a06bb035953cbbb4242568b38ca15443ad4c"))
 (alert :source "elpaca-menu-lock-file" :recipe
        (:package "alert" :fetcher github :repo "jwiegley/alert"
                  :files
                  ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                   "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                   "doc/*.texinfo" "lisp/*.el" "docs/dir"
                   "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                   (:exclude ".dir-locals.el" "test.el" "tests.el"
                             "*-test.el" "*-tests.el" "LICENSE"
                             "README*" "*-pkg.el"))
                  :source "MELPA" :protocol https :inherit t :depth
                  treeless :ref
                  "79f6936ab4d85227530959811143429347a6971b"))
 (all-the-icons :source "elpaca-menu-lock-file" :recipe
                (:package "all-the-icons" :repo
                          "domtronn/all-the-icons.el" :fetcher github
                          :files (:defaults "svg") :source "MELPA"
                          :protocol https :inherit t :depth treeless
                          :host github :branch "svg" :ref
                          "77a0ab1594447984a2fb576aac2c6a15b518f9b1"))
 (all-the-icons-completion :source "elpaca-menu-lock-file" :recipe
                           (:package "all-the-icons-completion" :repo
                                     "iyefrat/all-the-icons-completion"
                                     :fetcher github :files
                                     ("*.el" "*.el.in" "dir" "*.info"
                                      "*.texi" "*.texinfo" "doc/dir"
                                      "doc/*.info" "doc/*.texi"
                                      "doc/*.texinfo" "lisp/*.el"
                                      "docs/dir" "docs/*.info"
                                      "docs/*.texi" "docs/*.texinfo"
                                      (:exclude ".dir-locals.el"
                                                "test.el" "tests.el"
                                                "*-test.el"
                                                "*-tests.el" "LICENSE"
                                                "README*" "*-pkg.el"))
                                     :source "MELPA" :protocol https
                                     :inherit t :depth treeless :ref
                                     "4c8bcad8033f5d0868ce82ea3807c6cd46c4a198"))
 (all-the-icons-dired :source "elpaca-menu-lock-file" :recipe
                      (:package "all-the-icons-dired" :repo
                                "wyuenho/all-the-icons-dired" :fetcher
                                github :files
                                ("*.el" "*.el.in" "dir" "*.info"
                                 "*.texi" "*.texinfo" "doc/dir"
                                 "doc/*.info" "doc/*.texi"
                                 "doc/*.texinfo" "lisp/*.el"
                                 "docs/dir" "docs/*.info"
                                 "docs/*.texi" "docs/*.texinfo"
                                 (:exclude ".dir-locals.el" "test.el"
                                           "tests.el" "*-test.el"
                                           "*-tests.el" "LICENSE"
                                           "README*" "*-pkg.el"))
                                :source "MELPA" :protocol https
                                :inherit t :depth treeless :ref
                                "e157f0668f22ed586aebe0a2c0186ab07702986c"))
 (all-the-icons-ibuffer :source "elpaca-menu-lock-file" :recipe
                        (:package "all-the-icons-ibuffer" :repo
                                  "seagle0128/all-the-icons-ibuffer"
                                  :fetcher github :files
                                  ("*.el" "*.el.in" "dir" "*.info"
                                   "*.texi" "*.texinfo" "doc/dir"
                                   "doc/*.info" "doc/*.texi"
                                   "doc/*.texinfo" "lisp/*.el"
                                   "docs/dir" "docs/*.info"
                                   "docs/*.texi" "docs/*.texinfo"
                                   (:exclude ".dir-locals.el"
                                             "test.el" "tests.el"
                                             "*-test.el" "*-tests.el"
                                             "LICENSE" "README*"
                                             "*-pkg.el"))
                                  :source "MELPA" :protocol https
                                  :inherit t :depth treeless :ref
                                  "5357ab96f4dc9d0940d5a1e2e43302e1a04a14b2"))
 (anaphora :source "elpaca-menu-lock-file" :recipe
           (:package "anaphora" :repo "rolandwalker/anaphora" :fetcher
                     github :files
                     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                      "doc/*.texinfo" "lisp/*.el" "docs/dir"
                      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                      (:exclude ".dir-locals.el" "test.el" "tests.el"
                                "*-test.el" "*-tests.el" "LICENSE"
                                "README*" "*-pkg.el"))
                     :source "MELPA" :protocol https :inherit t :depth
                     treeless :ref
                     "a755afa7db7f3fa515f8dd2c0518113be0b027f6"))
 (annalist :source "elpaca-menu-lock-file" :recipe
           (:package "annalist" :fetcher github :repo
                     "noctuid/annalist.el" :files
                     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                      "doc/*.texinfo" "lisp/*.el" "docs/dir"
                      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                      (:exclude ".dir-locals.el" "test.el" "tests.el"
                                "*-test.el" "*-tests.el" "LICENSE"
                                "README*" "*-pkg.el"))
                     :source "MELPA" :protocol https :inherit t :depth
                     treeless :ref
                     "e1ef5dad75fa502d761f70d9ddf1aeb1c423f41d"))
 (anzu :source "elpaca-menu-lock-file" :recipe
       (:package "anzu" :fetcher github :repo "emacsorphanage/anzu"
                 :files
                 ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
                  "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
                  "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
                  "docs/*.texinfo"
                  (:exclude ".dir-locals.el" "test.el" "tests.el"
                            "*-test.el" "*-tests.el" "LICENSE"
                            "README*" "*-pkg.el"))
                 :source "MELPA" :protocol https :inherit t :depth
                 treeless :ref
                 "21cb5ab2295614372cb9f1a21429381e49a6255f"))
 (apheleia :source "elpaca-menu-lock-file" :recipe
           (:package "apheleia" :fetcher github :repo
                     "radian-software/apheleia" :files
                     (:defaults ("scripts" "scripts/formatters"))
                     :source "MELPA" :protocol https :inherit t :depth
                     treeless :ref
                     "2bc2bb4cc2caad111e6f2f1b9daf20ec388101ff"))
 (async :source "elpaca-menu-lock-file" :recipe
        (:package "async" :repo "jwiegley/emacs-async" :fetcher github
                  :files
                  ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                   "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                   "doc/*.texinfo" "lisp/*.el" "docs/dir"
                   "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                   (:exclude ".dir-locals.el" "test.el" "tests.el"
                             "*-test.el" "*-tests.el" "LICENSE"
                             "README*" "*-pkg.el"))
                  :source "MELPA" :protocol https :inherit t :depth
                  treeless :ref
                  "31cb2fea8f4bc7a593acd76187a89075d8075500"))
 (autothemer :source "elpaca-menu-lock-file" :recipe
             (:package "autothemer" :fetcher github :repo
                       "jasonm23/autothemer" :files
                       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                        "*.texinfo" "doc/dir" "doc/*.info"
                        "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                        "docs/dir" "docs/*.info" "docs/*.texi"
                        "docs/*.texinfo"
                        (:exclude ".dir-locals.el" "test.el"
                                  "tests.el" "*-test.el" "*-tests.el"
                                  "LICENSE" "README*" "*-pkg.el"))
                       :source "MELPA" :protocol https :inherit t
                       :depth treeless :ref
                       "e62bf83414abd8b1cefafb7480612faa30ed7878"))
 (avy :source "elpaca-menu-lock-file" :recipe
      (:package "avy" :repo "abo-abo/avy" :fetcher github :files
                ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
                 "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
                 "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
                 "docs/*.texinfo"
                 (:exclude ".dir-locals.el" "test.el" "tests.el"
                           "*-test.el" "*-tests.el" "LICENSE"
                           "README*" "*-pkg.el"))
                :source "MELPA" :protocol https :inherit t :depth
                treeless :ref
                "933d1f36cca0f71e4acb5fac707e9ae26c536264"))
 (awesome-tray :source "elpaca-menu-lock-file" :recipe
               (:source nil :protocol https :inherit t :depth treeless
                        :type git :host github :repo
                        "manateelazycat/awesome-tray" :package
                        "awesome-tray" :ref
                        "448366baf76a46bfa280c49c4a57c7a5e53ebbe5"))
 (bash-completion :source "elpaca-menu-lock-file" :recipe
                  (:package "bash-completion" :repo
                            "szermatt/emacs-bash-completion" :fetcher
                            github :files
                            ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                             "*.texinfo" "doc/dir" "doc/*.info"
                             "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                             "docs/dir" "docs/*.info" "docs/*.texi"
                             "docs/*.texinfo"
                             (:exclude ".dir-locals.el" "test.el"
                                       "tests.el" "*-test.el"
                                       "*-tests.el" "LICENSE"
                                       "README*" "*-pkg.el"))
                            :source "MELPA" :protocol https :inherit t
                            :depth treeless :ref
                            "5b621db96efc549c64436011a81fd658c6dcf6a0"))
 (beacon :source "elpaca-menu-lock-file" :recipe
         (:package "beacon" :fetcher github :repo "Malabarba/beacon"
                   :files
                   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                    "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                    "doc/*.texinfo" "lisp/*.el" "docs/dir"
                    "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                    (:exclude ".dir-locals.el" "test.el" "tests.el"
                              "*-test.el" "*-tests.el" "LICENSE"
                              "README*" "*-pkg.el"))
                   :source "MELPA" :protocol https :inherit t :depth
                   treeless :ref
                   "85261a928ae0ec3b41e639f05291ffd6bf7c231c"))
 (biblio :source "elpaca-menu-lock-file" :recipe
         (:package "biblio" :repo "cpitclaudel/biblio.el" :fetcher
                   github :files
                   (:defaults (:exclude "biblio-core.el")) :source
                   "MELPA" :protocol https :inherit t :depth treeless
                   :ref "bb9d6b4b962fb2a4e965d27888268b66d868766b"))
 (biblio-core :source "elpaca-menu-lock-file" :recipe
              (:package "biblio-core" :repo "cpitclaudel/biblio.el"
                        :fetcher github :files ("biblio-core.el")
                        :source "MELPA" :protocol https :inherit t
                        :depth treeless :ref
                        "bb9d6b4b962fb2a4e965d27888268b66d868766b"))
 (bibtex-completion :source "elpaca-menu-lock-file" :recipe
                    (:package "bibtex-completion" :fetcher github
                              :repo "tmalsburg/helm-bibtex" :files
                              ("bibtex-completion.el") :source "MELPA"
                              :protocol https :inherit t :depth
                              treeless :ref
                              "6064e8625b2958f34d6d40312903a85c173b5261"))
 (biome :source "elpaca-menu-lock-file" :recipe
        (:package "biome" :fetcher github :repo "SqrtMinusOne/biome"
                  :files
                  ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                   "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                   "doc/*.texinfo" "lisp/*.el" "docs/dir"
                   "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                   (:exclude ".dir-locals.el" "test.el" "tests.el"
                             "*-test.el" "*-tests.el" "LICENSE"
                             "README*" "*-pkg.el"))
                  :source "MELPA" :protocol https :inherit t :depth
                  treeless :ref
                  "b26c0a6ec533ba5c3524721af224708de9362979"))
 (blacken :source "elpaca-menu-lock-file" :recipe
          (:package "blacken" :fetcher github :repo
                    "pythonic-emacs/blacken" :files
                    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                     "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                     "doc/*.texinfo" "lisp/*.el" "docs/dir"
                     "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                     (:exclude ".dir-locals.el" "test.el" "tests.el"
                               "*-test.el" "*-tests.el" "LICENSE"
                               "README*" "*-pkg.el"))
                    :source "MELPA" :protocol https :inherit t :depth
                    treeless :ref
                    "cdd0cdb1e25f119d9347fd1c642760c6666a9180"))
 (blamer :source "elpaca-menu-lock-file" :recipe
         (:package "blamer" :repo "Artawower/blamer.el" :fetcher
                   github :files
                   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                    "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                    "doc/*.texinfo" "lisp/*.el" "docs/dir"
                    "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                    (:exclude ".dir-locals.el" "test.el" "tests.el"
                              "*-test.el" "*-tests.el" "LICENSE"
                              "README*" "*-pkg.el"))
                   :source "MELPA" :protocol https :inherit t :depth
                   treeless :ref
                   "aa9b22d4e847d15a5c4659c0407aa8bf4242cc94"))
 (bookmark+ :source "elpaca-menu-lock-file" :recipe
            (:source nil :protocol https :inherit t :depth treeless
                     :fetcher github :repo "emacsmirror/bookmark-plus"
                     :files (:defaults "*.el") :main "bookmark+.el"
                     :package "bookmark+" :ref
                     "892cc0a314ef353e800b6ff9da03b0bfd55e4763"))
 (bookmark-in-project :source "elpaca-menu-lock-file" :recipe
                      (:package "bookmark-in-project" :fetcher
                                codeberg :repo
                                "ideasman42/emacs-bookmark-in-project"
                                :files
                                ("*.el" "*.el.in" "dir" "*.info"
                                 "*.texi" "*.texinfo" "doc/dir"
                                 "doc/*.info" "doc/*.texi"
                                 "doc/*.texinfo" "lisp/*.el"
                                 "docs/dir" "docs/*.info"
                                 "docs/*.texi" "docs/*.texinfo"
                                 (:exclude ".dir-locals.el" "test.el"
                                           "tests.el" "*-test.el"
                                           "*-tests.el" "LICENSE"
                                           "README*" "*-pkg.el"))
                                :source "MELPA" :protocol https
                                :inherit t :depth treeless :ref
                                "bf923ddd3e74fe99e086221e461a5fa7599d0644"))
 (bookmark-view :source "elpaca-menu-lock-file" :recipe
                (:source nil :protocol https :inherit t :depth
                         treeless :type git :host github :repo
                         "minad/bookmark-view" :package
                         "bookmark-view" :ref
                         "10552ae65191b914242824aa4f954d640d7a9b3d"))
 (breadcrumb :source "elpaca-menu-lock-file" :recipe
             (:package "breadcrumb" :repo
                       ("https://github.com/joaotavora/breadcrumb"
                        . "breadcrumb")
                       :files ("*" (:exclude ".git")) :source
                       "GNU ELPA" :protocol https :inherit t :depth
                       treeless :ref
                       "1d9dd90f77a594cd50b368e6efc85d44539ec209"))
 (browse-at-remote :source "elpaca-menu-lock-file" :recipe
                   (:package "browse-at-remote" :repo
                             "rmuslimov/browse-at-remote" :fetcher
                             github :files
                             ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                              "*.texinfo" "doc/dir" "doc/*.info"
                              "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                              "docs/dir" "docs/*.info" "docs/*.texi"
                              "docs/*.texinfo"
                              (:exclude ".dir-locals.el" "test.el"
                                        "tests.el" "*-test.el"
                                        "*-tests.el" "LICENSE"
                                        "README*" "*-pkg.el"))
                             :source "MELPA" :protocol https :inherit
                             t :depth treeless :ref
                             "38e5ffd77493c17c821fd88f938dbf42705a5158"))
 (brushup :source "elpaca-menu-lock-file" :recipe
          (:source nil :protocol https :inherit t :depth treeless
                   :host github :repo "chiply/brushup" :package
                   "brushup" :ref
                   "fab9544808c865bc773f02f8827b6c6855b7fa7f"))
 (bufler :source "elpaca-menu-lock-file" :recipe
         (:package "bufler" :fetcher github :repo
                   "alphapapa/bufler.el" :files
                   (:defaults (:exclude "helm-bufler.el")) :source
                   "MELPA" :protocol https :inherit t :depth treeless
                   :ref "b96822d2132fda6bd1dd86f017d7e76e3b990c82"))
 (bui :source "elpaca-menu-lock-file" :recipe
      (:package "bui" :repo "alezost/bui.el" :fetcher github :files
                ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
                 "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
                 "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
                 "docs/*.texinfo"
                 (:exclude ".dir-locals.el" "test.el" "tests.el"
                           "*-test.el" "*-tests.el" "LICENSE"
                           "README*" "*-pkg.el"))
                :source "MELPA" :protocol https :inherit t :depth
                treeless :ref
                "f3a137628e112a91910fd33c0cff0948fa58d470"))
 (burly :source "elpaca-menu-lock-file" :recipe
        (:package "burly" :fetcher github :repo "alphapapa/burly.el"
                  :files
                  ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                   "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                   "doc/*.texinfo" "lisp/*.el" "docs/dir"
                   "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                   (:exclude ".dir-locals.el" "test.el" "tests.el"
                             "*-test.el" "*-tests.el" "LICENSE"
                             "README*" "*-pkg.el"))
                  :source "MELPA" :protocol https :inherit t :depth
                  treeless :ref
                  "d5b7133b5b629dd6bca29bb16660a9e472e82e25"))
 (cape :source "elpaca-menu-lock-file" :recipe
       (:package "cape" :repo "minad/cape" :fetcher github :files
                 ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
                  "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
                  "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
                  "docs/*.texinfo"
                  (:exclude ".dir-locals.el" "test.el" "tests.el"
                            "*-test.el" "*-tests.el" "LICENSE"
                            "README*" "*-pkg.el"))
                 :source "MELPA" :protocol https :inherit t :depth
                 treeless :ref
                 "2b2a5c5bef16eddcce507d9b5804e5a0cc9481ae"))
 (celestial-mode-line :source "elpaca-menu-lock-file" :recipe
                      (:package "celestial-mode-line" :fetcher github
                                :repo "ecraven/celestial-mode-line"
                                :files
                                ("*.el" "*.el.in" "dir" "*.info"
                                 "*.texi" "*.texinfo" "doc/dir"
                                 "doc/*.info" "doc/*.texi"
                                 "doc/*.texinfo" "lisp/*.el"
                                 "docs/dir" "docs/*.info"
                                 "docs/*.texi" "docs/*.texinfo"
                                 (:exclude ".dir-locals.el" "test.el"
                                           "tests.el" "*-test.el"
                                           "*-tests.el" "LICENSE"
                                           "README*" "*-pkg.el"))
                                :source "MELPA" :protocol https
                                :inherit t :depth treeless :ref
                                "90056322d6664e2e2b593912e4d5e68f1468cafc"))
 (cfrs :source "elpaca-menu-lock-file" :recipe
       (:package "cfrs" :repo "Alexander-Miller/cfrs" :fetcher github
                 :files
                 ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
                  "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
                  "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
                  "docs/*.texinfo"
                  (:exclude ".dir-locals.el" "test.el" "tests.el"
                            "*-test.el" "*-tests.el" "LICENSE"
                            "README*" "*-pkg.el"))
                 :source "MELPA" :protocol https :inherit t :depth
                 treeless :ref
                 "981bddb3fb9fd9c58aed182e352975bd10ad74c8"))
 (chocolate-theme :source "elpaca-menu-lock-file" :recipe
                  (:package "chocolate-theme" :repo
                            "SavchenkoValeriy/emacs-chocolate-theme"
                            :fetcher github :files
                            ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                             "*.texinfo" "doc/dir" "doc/*.info"
                             "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                             "docs/dir" "docs/*.info" "docs/*.texi"
                             "docs/*.texinfo"
                             (:exclude ".dir-locals.el" "test.el"
                                       "tests.el" "*-test.el"
                                       "*-tests.el" "LICENSE"
                                       "README*" "*-pkg.el"))
                            :source "MELPA" :protocol https :inherit t
                            :depth treeless :ref
                            "ccc05f7ad96d3d1332727689bf6250443adc7ec0"))
 (citar :source "elpaca-menu-lock-file" :recipe
        (:package "citar" :repo "emacs-citar/citar" :fetcher github
                  :files (:defaults) :old-names (bibtex-actions)
                  :source "MELPA" :protocol https :inherit t :depth
                  treeless :ref
                  "dc7018eb36fb3540cb5b7fc526d6747144437eef"))
 (citeproc :source "elpaca-menu-lock-file" :recipe
           (:package "citeproc" :fetcher github :repo
                     "andras-simonyi/citeproc-el" :files
                     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                      "doc/*.texinfo" "lisp/*.el" "docs/dir"
                      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                      (:exclude ".dir-locals.el" "test.el" "tests.el"
                                "*-test.el" "*-tests.el" "LICENSE"
                                "README*" "*-pkg.el"))
                     :source "MELPA" :protocol https :inherit t :depth
                     treeless :ref
                     "4bde999a41803fe519ea80eab8b813d53503eebd"))
 (closql :source "elpaca-menu-lock-file" :recipe
         (:package "closql" :fetcher github :repo "magit/closql"
                   :files
                   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                    "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                    "doc/*.texinfo" "lisp/*.el" "docs/dir"
                    "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                    (:exclude ".dir-locals.el" "test.el" "tests.el"
                              "*-test.el" "*-tests.el" "LICENSE"
                              "README*" "*-pkg.el"))
                   :source "MELPA" :protocol https :inherit t :depth
                   treeless :ref
                   "947426d0c93e5ad5374c464b2f121c36cdaf2132"))
 (color-identifiers-mode :source "elpaca-menu-lock-file" :recipe
                         (:package "color-identifiers-mode" :fetcher
                                   github :repo
                                   "ankurdave/color-identifiers-mode"
                                   :files
                                   ("*.el" "*.el.in" "dir" "*.info"
                                    "*.texi" "*.texinfo" "doc/dir"
                                    "doc/*.info" "doc/*.texi"
                                    "doc/*.texinfo" "lisp/*.el"
                                    "docs/dir" "docs/*.info"
                                    "docs/*.texi" "docs/*.texinfo"
                                    (:exclude ".dir-locals.el"
                                              "test.el" "tests.el"
                                              "*-test.el" "*-tests.el"
                                              "LICENSE" "README*"
                                              "*-pkg.el"))
                                   :source "MELPA" :protocol https
                                   :inherit t :depth treeless :ref
                                   "adcdbbe9c69edeb207f2b066db071057f3f612d6"))
 (color-rg :source "elpaca-menu-lock-file" :recipe
           (:source nil :protocol https :inherit t :depth treeless
                    :type git :host github :repo
                    "manateelazycat/color-rg" :package "color-rg" :ref
                    "41ad8fda5b6579a841889b2395c26cd642a006de"))
 (combobulate :source "elpaca-menu-lock-file" :recipe
              (:source nil :protocol https :inherit t :depth treeless
                       :host github :repo "mickeynp/combobulate"
                       :package "combobulate" :ref
                       "38773810b5e532f25d11c6d1af02c3a8dffeacd7"))
 (compile-multi :source "elpaca-menu-lock-file" :recipe
                (:package "compile-multi" :fetcher github :repo
                          "mohkale/compile-multi" :files
                          (:defaults "extensions/*/*.el") :source
                          "MELPA" :protocol https :inherit t :depth
                          treeless :ref
                          "d111f99303ceb0354e37e2a5cd7f504d19f105f7"))
 (cond-let
   :source "elpaca-menu-lock-file" :recipe
   (:package "cond-let" :fetcher github :repo "tarsius/cond-let"
             :files
             ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
              "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
              "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
              "docs/*.texinfo"
              (:exclude ".dir-locals.el" "test.el" "tests.el"
                        "*-test.el" "*-tests.el" "LICENSE" "README*"
                        "*-pkg.el"))
             :source "MELPA" :protocol https :inherit t :depth
             treeless :ref "8bf87d45e169ebc091103b2aae325aece3aa804d"))
 (consult :source "elpaca-menu-lock-file" :recipe
          (:package "consult" :repo "minad/consult" :fetcher github
                    :files
                    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                     "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                     "doc/*.texinfo" "lisp/*.el" "docs/dir"
                     "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                     (:exclude ".dir-locals.el" "test.el" "tests.el"
                               "*-test.el" "*-tests.el" "LICENSE"
                               "README*" "*-pkg.el"))
                    :source "MELPA" :protocol https :inherit t :depth
                    treeless :ref
                    "d1d39d52151a10f7ca29aa291886e99534cc94db"))
 (consult-dash :source "elpaca-menu-lock-file" :recipe
               (:package "consult-dash" :fetcher codeberg :repo
                         "ravi/consult-dash" :files
                         ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                          "*.texinfo" "doc/dir" "doc/*.info"
                          "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                          "docs/dir" "docs/*.info" "docs/*.texi"
                          "docs/*.texinfo"
                          (:exclude ".dir-locals.el" "test.el"
                                    "tests.el" "*-test.el"
                                    "*-tests.el" "LICENSE" "README*"
                                    "*-pkg.el"))
                         :source "MELPA" :protocol https :inherit t
                         :depth treeless :ref
                         "edb57bf8cdbef422b88667fadc83e1bb046957a6"))
 (consult-dir :source "elpaca-menu-lock-file" :recipe
              (:package "consult-dir" :fetcher github :repo
                        "karthink/consult-dir" :files
                        ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                         "*.texinfo" "doc/dir" "doc/*.info"
                         "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                         "docs/dir" "docs/*.info" "docs/*.texi"
                         "docs/*.texinfo"
                         (:exclude ".dir-locals.el" "test.el"
                                   "tests.el" "*-test.el" "*-tests.el"
                                   "LICENSE" "README*" "*-pkg.el"))
                        :source "MELPA" :protocol https :inherit t
                        :depth treeless :ref
                        "1497b46d6f48da2d884296a1297e5ace1e050eb5"))
 (consult-gh :source "elpaca-menu-lock-file" :recipe
             (:package "consult-gh" :fetcher github :repo
                       "armindarvish/consult-gh" :files ("*.el")
                       :source "MELPA" :protocol https :inherit t
                       :depth treeless :host github :ref
                       "f078379a50ebace30252447ad4b4b7c4514b7f95"))
 (consult-ls-git :source "elpaca-menu-lock-file" :recipe
                 (:package "consult-ls-git" :repo "rcj/consult-ls-git"
                           :fetcher github :files
                           ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                            "*.texinfo" "doc/dir" "doc/*.info"
                            "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                            "docs/dir" "docs/*.info" "docs/*.texi"
                            "docs/*.texinfo"
                            (:exclude ".dir-locals.el" "test.el"
                                      "tests.el" "*-test.el"
                                      "*-tests.el" "LICENSE" "README*"
                                      "*-pkg.el"))
                           :source "MELPA" :protocol https :inherit t
                           :depth treeless :ref
                           "85882e4b7af9ad40160d985e42b36b0fd6400ead"))
 (consult-lsp :source "elpaca-menu-lock-file" :recipe
              (:package "consult-lsp" :fetcher github :repo
                        "gagbo/consult-lsp" :files
                        ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                         "*.texinfo" "doc/dir" "doc/*.info"
                         "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                         "docs/dir" "docs/*.info" "docs/*.texi"
                         "docs/*.texinfo"
                         (:exclude ".dir-locals.el" "test.el"
                                   "tests.el" "*-test.el" "*-tests.el"
                                   "LICENSE" "README*" "*-pkg.el"))
                        :source "MELPA" :protocol https :inherit t
                        :depth treeless :ref
                        "d11102c9db33c4ca7817296a2edafc3e26a61117"))
 (consult-project-extra :source "elpaca-menu-lock-file" :recipe
                        (:package "consult-project-extra" :fetcher
                                  github :repo
                                  "Qkessler/consult-project-extra"
                                  :files
                                  ("*.el" "*.el.in" "dir" "*.info"
                                   "*.texi" "*.texinfo" "doc/dir"
                                   "doc/*.info" "doc/*.texi"
                                   "doc/*.texinfo" "lisp/*.el"
                                   "docs/dir" "docs/*.info"
                                   "docs/*.texi" "docs/*.texinfo"
                                   (:exclude ".dir-locals.el"
                                             "test.el" "tests.el"
                                             "*-test.el" "*-tests.el"
                                             "LICENSE" "README*"
                                             "*-pkg.el"))
                                  :source "MELPA" :protocol https
                                  :inherit t :depth treeless :ref
                                  "2b3fa36fd3a14deacf594f4acd54d220d6890c55"))
 (consult-yasnippet :source "elpaca-menu-lock-file" :recipe
                    (:package "consult-yasnippet" :fetcher github
                              :repo "mohkale/consult-yasnippet" :files
                              ("*.el" "*.el.in" "dir" "*.info"
                               "*.texi" "*.texinfo" "doc/dir"
                               "doc/*.info" "doc/*.texi"
                               "doc/*.texinfo" "lisp/*.el" "docs/dir"
                               "docs/*.info" "docs/*.texi"
                               "docs/*.texinfo"
                               (:exclude ".dir-locals.el" "test.el"
                                         "tests.el" "*-test.el"
                                         "*-tests.el" "LICENSE"
                                         "README*" "*-pkg.el"))
                              :source "MELPA" :protocol https :inherit
                              t :depth treeless :ref
                              "a3482dfbdcbe487ba5ff934a1bb6047066ff2194"))
 (copilot-chat :source "elpaca-menu-lock-file" :recipe
               (:package "copilot-chat" :fetcher github :repo
                         "chep/copilot-chat.el" :files
                         ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                          "*.texinfo" "doc/dir" "doc/*.info"
                          "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                          "docs/dir" "docs/*.info" "docs/*.texi"
                          "docs/*.texinfo"
                          (:exclude ".dir-locals.el" "test.el"
                                    "tests.el" "*-test.el"
                                    "*-tests.el" "LICENSE" "README*"
                                    "*-pkg.el"))
                         :source "MELPA" :protocol https :inherit t
                         :depth treeless :ref
                         "753ebc4ae466c8716be8de0d169393f730c999f6"))
 (corfu :source "elpaca-menu-lock-file" :recipe
        (:package "corfu" :repo "minad/corfu" :files
                  (:defaults "extensions/corfu-*.el") :fetcher github
                  :source "MELPA" :protocol https :inherit t :depth
                  treeless :ref
                  "abfe0003d71b61ffdcf23fc6e546643486daeb69"))
 (counsel :source "elpaca-menu-lock-file" :recipe
          (:package "counsel" :repo "abo-abo/swiper" :fetcher github
                    :files ("counsel.el") :source "MELPA" :protocol
                    https :inherit t :depth treeless :ref
                    "ee79f68215ae7e2b8a38ba6bf7f82b3fe57dc16c"))
 (csv-mode :source "elpaca-menu-lock-file" :recipe
           (:package "csv-mode" :repo
                     ("https://github.com/emacsmirror/gnu_elpa"
                      . "csv-mode")
                     :branch "externals/csv-mode" :files
                     ("*" (:exclude ".git")) :source "GNU ELPA"
                     :protocol https :inherit t :depth treeless :ref
                     "ba5dc934b9dbdc2b57ab1917a669cdfd7d1838d3"))
 (ct :source "elpaca-menu-lock-file" :recipe
     (:package "ct" :fetcher github :repo "neeasade/ct.el" :files
               ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
                "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
                "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
                "docs/*.texinfo"
                (:exclude ".dir-locals.el" "test.el" "tests.el"
                          "*-test.el" "*-tests.el" "LICENSE" "README*"
                          "*-pkg.el"))
               :source "MELPA" :protocol https :inherit t :depth
               treeless :ref
               "66fb78baf83525ca068c3ddd156ef0989a65bf9d"))
 (dap-mode :source "elpaca-menu-lock-file" :recipe
           (:package "dap-mode" :repo "emacs-lsp/dap-mode" :fetcher
                     github :files (:defaults "icons") :source "MELPA"
                     :protocol https :inherit t :depth treeless :ref
                     "b77d9bdb15d89e354b8a20906bebe7789e19fc9b"))
 (dash :source "elpaca-menu-lock-file" :recipe
       (:package "dash" :fetcher github :repo "magnars/dash.el" :files
                 ("dash.el" "dash.texi") :source "MELPA" :protocol
                 https :inherit t :depth treeless :ref
                 "d3a84021dbe48dba63b52ef7665651e0cf02e915"))
 (dash-docs :source "elpaca-menu-lock-file" :recipe
            (:package "dash-docs" :repo "dash-docs-el/dash-docs"
                      :fetcher github :files
                      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                       "doc/*.texinfo" "lisp/*.el" "docs/dir"
                       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                       (:exclude ".dir-locals.el" "test.el" "tests.el"
                                 "*-test.el" "*-tests.el" "LICENSE"
                                 "README*" "*-pkg.el"))
                      :source "MELPA" :protocol https :inherit t
                      :depth treeless :wait t :ref
                      "29848b6b347ac520f7646c200ed2ec36cea3feda"))
 (dash-functional :source "elpaca-menu-lock-file" :recipe
                  (:package "dash-functional" :fetcher github :repo
                            "magnars/dash.el" :files
                            ("dash-functional.el") :source "MELPA"
                            :protocol https :inherit t :depth treeless
                            :ref
                            "d3a84021dbe48dba63b52ef7665651e0cf02e915"))
 (ddp :source "elpaca-menu-lock-file" :recipe
      (:package "ddp" :fetcher github :repo "eki3z/ddp.el" :files
                ("*.el") :source "MELPA" :protocol https :inherit t
                :depth treeless :type git :host github :branch
                "master" :ref
                "e09aafe6bcdfe3c972706cecd35480ce6424b8f9"))
 (default-text-scale :source "elpaca-menu-lock-file" :recipe
                     (:package "default-text-scale" :fetcher github
                               :repo "purcell/default-text-scale"
                               :files
                               ("*.el" "*.el.in" "dir" "*.info"
                                "*.texi" "*.texinfo" "doc/dir"
                                "doc/*.info" "doc/*.texi"
                                "doc/*.texinfo" "lisp/*.el" "docs/dir"
                                "docs/*.info" "docs/*.texi"
                                "docs/*.texinfo"
                                (:exclude ".dir-locals.el" "test.el"
                                          "tests.el" "*-test.el"
                                          "*-tests.el" "LICENSE"
                                          "README*" "*-pkg.el"))
                               :source "MELPA" :protocol https
                               :inherit t :depth treeless :ref
                               "e23b3f8d402dd3871ee5e6dacd10fda223128896"))
 (deferred :source "elpaca-menu-lock-file" :recipe
           (:package "deferred" :repo "kiwanami/emacs-deferred"
                     :fetcher github :files ("deferred.el") :source
                     "MELPA" :protocol https :inherit t :depth
                     treeless :ref
                     "2239671d94b38d92e9b28d4e12fd79814cfb9c16"))
 (define-word :source "elpaca-menu-lock-file" :recipe
              (:package "define-word" :repo "abo-abo/define-word"
                        :fetcher github :files
                        ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                         "*.texinfo" "doc/dir" "doc/*.info"
                         "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                         "docs/dir" "docs/*.info" "docs/*.texi"
                         "docs/*.texinfo"
                         (:exclude ".dir-locals.el" "test.el"
                                   "tests.el" "*-test.el" "*-tests.el"
                                   "LICENSE" "README*" "*-pkg.el"))
                        :source "MELPA" :protocol https :inherit t
                        :depth treeless :ref
                        "31a8c67405afa99d0e25e7c86a4ee7ef84a808fe"))
 (detached :source "elpaca-menu-lock-file" :recipe
           (:package "detached" :fetcher sourcehut :repo
                     "niklaseklund/detached.el" :old-names (dtache)
                     :files
                     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                      "doc/*.texinfo" "lisp/*.el" "docs/dir"
                      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                      (:exclude ".dir-locals.el" "test.el" "tests.el"
                                "*-test.el" "*-tests.el" "LICENSE"
                                "README*" "*-pkg.el"))
                     :source "MELPA" :protocol https :inherit t :depth
                     treeless :ref
                     "6b64d4d8064cee781e071e825857b442ea96c3d9"))
 (devdocs :source "elpaca-menu-lock-file" :recipe
          (:package "devdocs" :fetcher github :repo
                    "astoff/devdocs.el" :files
                    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                     "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                     "doc/*.texinfo" "lisp/*.el" "docs/dir"
                     "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                     (:exclude ".dir-locals.el" "test.el" "tests.el"
                               "*-test.el" "*-tests.el" "LICENSE"
                               "README*" "*-pkg.el"))
                    :source "MELPA" :protocol https :inherit t :depth
                    treeless :ref
                    "25c746024ddf73570195bf42b841f761a2fee10c"))
 (diff-hl :source "elpaca-menu-lock-file" :recipe
          (:package "diff-hl" :fetcher github :repo "dgutov/diff-hl"
                    :files
                    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                     "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                     "doc/*.texinfo" "lisp/*.el" "docs/dir"
                     "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                     (:exclude ".dir-locals.el" "test.el" "tests.el"
                               "*-test.el" "*-tests.el" "LICENSE"
                               "README*" "*-pkg.el"))
                    :source "MELPA" :protocol https :inherit t :depth
                    treeless :ref
                    "bb9af85441b0cbb3281268d30256d50f0595ebfe"))
 (dimmer :source "elpaca-menu-lock-file" :recipe
         (:package "dimmer" :fetcher github :repo
                   "gonewest818/dimmer.el" :files
                   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                    "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                    "doc/*.texinfo" "lisp/*.el" "docs/dir"
                    "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                    (:exclude ".dir-locals.el" "test.el" "tests.el"
                              "*-test.el" "*-tests.el" "LICENSE"
                              "README*" "*-pkg.el"))
                   :source "MELPA" :protocol https :inherit t :depth
                   treeless :ref
                   "a5b697580e5aed6168b571ae3d925753428284f8"))
 (dired-hacks :source "elpaca-menu-lock-file" :recipe
              (:source nil :protocol https :inherit t :depth treeless
                       :host github :repo "Fuco1/dired-hacks" :files
                       ("dired-hacks.el" "dired-hacks-utils.el"
                        "dired-subtree.el" "dired-ranger.el")
                       :package "dired-hacks" :ref
                       "de9336f4b47ef901799fe95315fa080fa6d77b48"))
 (docker :source "elpaca-menu-lock-file" :recipe
         (:package "docker" :fetcher github :repo "Silex/docker.el"
                   :files
                   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                    "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                    "doc/*.texinfo" "lisp/*.el" "docs/dir"
                    "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                    (:exclude ".dir-locals.el" "test.el" "tests.el"
                              "*-test.el" "*-tests.el" "LICENSE"
                              "README*" "*-pkg.el"))
                   :source "MELPA" :protocol https :inherit t :depth
                   treeless :ref
                   "916686b86e83a3bd2281fbc5e6f98962aa747429"))
 (docker-compose-mode :source "elpaca-menu-lock-file" :recipe
                      (:package "docker-compose-mode" :repo
                                "meqif/docker-compose-mode" :fetcher
                                github :files
                                (:defaults
                                 (:exclude
                                  "docker-compose-mode-helpers.el"))
                                :source "MELPA" :protocol https
                                :inherit t :depth treeless :ref
                                "abaa4f3aeb5c62d7d16e186dd7d77f4e846e126a"))
 (dockerfile-mode :source "elpaca-menu-lock-file" :recipe
                  (:package "dockerfile-mode" :fetcher github :repo
                            "spotify/dockerfile-mode" :files
                            ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                             "*.texinfo" "doc/dir" "doc/*.info"
                             "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                             "docs/dir" "docs/*.info" "docs/*.texi"
                             "docs/*.texinfo"
                             (:exclude ".dir-locals.el" "test.el"
                                       "tests.el" "*-test.el"
                                       "*-tests.el" "LICENSE"
                                       "README*" "*-pkg.el"))
                            :source "MELPA" :protocol https :inherit t
                            :depth treeless :ref
                            "97733ce074b1252c1270fd5e8a53d178b66668ed"))
 (dogears :source "elpaca-menu-lock-file" :recipe
          (:package "dogears" :fetcher github :repo
                    "alphapapa/dogears.el" :files
                    (:defaults (:exclude "helm-dogears.el")) :source
                    "MELPA" :protocol https :inherit t :depth treeless
                    :ref "162671e66cac601f1cfd5d22f7da2671af2e9866"))
 (doric-themes :source "elpaca-menu-lock-file" :recipe
               (:package "doric-themes" :repo
                         "emacsmirror/doric-themes" :files
                         ("*" (:exclude ".git")) :source "GNU ELPA"
                         :protocol https :inherit t :depth treeless
                         :type git :host github :ref
                         "4575e6478ab9e927aba7bc024458f729af4ec890"))
 (dumb-jump :source "elpaca-menu-lock-file" :recipe
            (:package "dumb-jump" :repo "jacktasia/dumb-jump" :fetcher
                      github :files
                      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                       "doc/*.texinfo" "lisp/*.el" "docs/dir"
                       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                       (:exclude ".dir-locals.el" "test.el" "tests.el"
                                 "*-test.el" "*-tests.el" "LICENSE"
                                 "README*" "*-pkg.el"))
                      :source "MELPA" :protocol https :inherit t
                      :depth treeless :ref
                      "8c97b2afc2c7940f377a192dbcff51f6a44f664e"))
 (eca :source "elpaca-menu-lock-file" :recipe
      (:package "eca" :fetcher github :repo
                "editor-code-assistant/eca-emacs" :files ("*.el")
                :source "MELPA" :protocol https :inherit t :depth
                treeless :host github :ref
                "78dafe64014ac5cdaa0325b2d5d90d2bf8b0cc51"))
 (ef-themes :source "elpaca-menu-lock-file" :recipe
            (:package "ef-themes" :repo
                      ("https://github.com/protesilaos/ef-themes"
                       . "ef-themes")
                      :files
                      ("*"
                       (:exclude ".git" "COPYING" "doclicense.texi"
                                 "contrast-ratios.org"))
                      :source "GNU ELPA" :protocol https :inherit t
                      :depth treeless :ref
                      "9f68c1be9d35958a0679d5855ac6ec10b2c46e1b"))
 (ein :source "elpaca-menu-lock-file" :recipe
      (:package "ein" :repo "millejoh/emacs-ipython-notebook" :fetcher
                github :files
                ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
                 "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
                 "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
                 "docs/*.texinfo"
                 (:exclude ".dir-locals.el" "test.el" "tests.el"
                           "*-test.el" "*-tests.el" "LICENSE"
                           "README*" "*-pkg.el"))
                :source "MELPA" :protocol https :inherit t :depth
                treeless :ref
                "8fa836fcd1c22f45d36249b09590b32a890f2b9e"))
 (elfeed :source "elpaca-menu-lock-file" :recipe
         (:package "elfeed" :repo "skeeto/elfeed" :fetcher github
                   :files (:defaults "README.md") :source "MELPA"
                   :protocol https :inherit t :depth treeless :ref
                   "bbb3cac27b0412d80b327b5cfaab83683c96a2a1"))
 (elfeed-org :source "elpaca-menu-lock-file" :recipe
             (:package "elfeed-org" :repo "remyhonig/elfeed-org"
                       :fetcher github :files
                       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                        "*.texinfo" "doc/dir" "doc/*.info"
                        "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                        "docs/dir" "docs/*.info" "docs/*.texi"
                        "docs/*.texinfo"
                        (:exclude ".dir-locals.el" "test.el"
                                  "tests.el" "*-test.el" "*-tests.el"
                                  "LICENSE" "README*" "*-pkg.el"))
                       :source "MELPA" :protocol https :inherit t
                       :depth treeless :ref
                       "34c0b4d758942822e01a5dbe66b236e49a960583"))
 (elfeed-protocol :source "elpaca-menu-lock-file" :recipe
                  (:package "elfeed-protocol" :repo
                            "fasheng/elfeed-protocol" :fetcher github
                            :files
                            ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                             "*.texinfo" "doc/dir" "doc/*.info"
                             "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                             "docs/dir" "docs/*.info" "docs/*.texi"
                             "docs/*.texinfo"
                             (:exclude ".dir-locals.el" "test.el"
                                       "tests.el" "*-test.el"
                                       "*-tests.el" "LICENSE"
                                       "README*" "*-pkg.el"))
                            :source "MELPA" :protocol https :inherit t
                            :depth treeless :host github :ref
                            "4f5e77a28c501db686ac06a2ea250a7b37d5420c"))
 (elfeed-score :source "elpaca-menu-lock-file" :recipe
               (:package "elfeed-score" :fetcher github :repo
                         "sp1ff/elfeed-score" :files
                         ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                          "*.texinfo" "doc/dir" "doc/*.info"
                          "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                          "docs/dir" "docs/*.info" "docs/*.texi"
                          "docs/*.texinfo"
                          (:exclude ".dir-locals.el" "test.el"
                                    "tests.el" "*-test.el"
                                    "*-tests.el" "LICENSE" "README*"
                                    "*-pkg.el"))
                         :source "MELPA" :protocol https :inherit t
                         :depth treeless :type git :host github :ref
                         "f6ef83c472e6f01d0f60130ecac768462c5a20b7"))
 (elisp-refs :source "elpaca-menu-lock-file" :recipe
             (:package "elisp-refs" :repo "Wilfred/elisp-refs"
                       :fetcher github :files
                       (:defaults (:exclude "elisp-refs-bench.el"))
                       :source "MELPA" :protocol https :inherit t
                       :depth treeless :ref
                       "541a064c3ce27867872cf708354a65d83baf2a6d"))
 (elpaca :source
   "elpaca-menu-lock-file" :recipe
   (:source nil :protocol https :inherit ignore :depth 1 :repo
            "https://github.com/progfolio/elpaca.git" :ref
            "a7fee1f17e5f9a6aac6ff6abc5e834fab12e3488" :files
            (:defaults "elpaca-test.el" (:exclude "extensions"))
            :build (:not elpaca--activate-package) :package "elpaca"))
 (elpaca-use-package :source "elpaca-menu-lock-file" :recipe
                     (:package "elpaca-use-package" :wait t :repo
                               "https://github.com/progfolio/elpaca.git"
                               :files
                               ("extensions/elpaca-use-package.el")
                               :main
                               "extensions/elpaca-use-package.el"
                               :build (:not elpaca--compile-info)
                               :source "Elpaca extensions" :protocol
                               https :inherit t :depth treeless :ref
                               "a7fee1f17e5f9a6aac6ff6abc5e834fab12e3488"))
 (elysium :source "elpaca-menu-lock-file" :recipe
          (:package "elysium" :fetcher github :repo
                    "lanceberge/elysium" :files
                    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                     "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                     "doc/*.texinfo" "lisp/*.el" "docs/dir"
                     "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                     (:exclude ".dir-locals.el" "test.el" "tests.el"
                               "*-test.el" "*-tests.el" "LICENSE"
                               "README*" "*-pkg.el"))
                    :source "MELPA" :protocol https :inherit t :depth
                    treeless :ref
                    "049ad3091baf3ce578791187c5e5e4f932c26044"))
 (emacsql :source "elpaca-menu-lock-file" :recipe
          (:package "emacsql" :fetcher github :repo "magit/emacsql"
                    :files (:defaults "README.md" "sqlite") :source
                    "MELPA" :protocol https :inherit t :depth treeless
                    :ref "6ef7473248fce048c7daa00c3b2ae75af987c89c"))
 (embark :source "elpaca-menu-lock-file" :recipe
         (:package "embark" :repo "oantolin/embark" :fetcher github
                   :files ("embark.el" "embark-org.el" "embark.texi")
                   :source "MELPA" :protocol https :inherit t :depth
                   treeless :wait t :ref
                   "e0238889b1c946514fd967d21d70599af9c4e887"))
 (embark-consult :source "elpaca-menu-lock-file" :recipe
                 (:package "embark-consult" :repo "oantolin/embark"
                           :fetcher github :files
                           ("embark-consult.el") :source "MELPA"
                           :protocol https :inherit t :depth treeless
                           :ref
                           "e0238889b1c946514fd967d21d70599af9c4e887"))
 (embark-vc :source "elpaca-menu-lock-file" :recipe
            (:package "embark-vc" :fetcher github :repo
                      "elken/embark-vc" :files
                      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                       "doc/*.texinfo" "lisp/*.el" "docs/dir"
                       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                       (:exclude ".dir-locals.el" "test.el" "tests.el"
                                 "*-test.el" "*-tests.el" "LICENSE"
                                 "README*" "*-pkg.el"))
                      :source "MELPA" :protocol https :inherit t
                      :depth treeless :ref
                      "2bc2b3a3e610c217a61355a33b7e6c73b3b3ad44"))
 (emmet-mode :source "elpaca-menu-lock-file" :recipe
             (:package "emmet-mode" :fetcher github :repo
                       "smihica/emmet-mode" :files
                       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                        "*.texinfo" "doc/dir" "doc/*.info"
                        "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                        "docs/dir" "docs/*.info" "docs/*.texi"
                        "docs/*.texinfo"
                        (:exclude ".dir-locals.el" "test.el"
                                  "tests.el" "*-test.el" "*-tests.el"
                                  "LICENSE" "README*" "*-pkg.el"))
                       :source "MELPA" :protocol https :inherit t
                       :depth treeless :ref
                       "322d3bb112fced57d63b44863357f7a0b7eee1e3"))
 (epresent :source "elpaca-menu-lock-file" :recipe
           (:package "epresent" :fetcher github :repo
                     "dakrone/epresent" :files
                     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                      "doc/*.texinfo" "lisp/*.el" "docs/dir"
                      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                      (:exclude ".dir-locals.el" "test.el" "tests.el"
                                "*-test.el" "*-tests.el" "LICENSE"
                                "README*" "*-pkg.el"))
                     :source "MELPA" :protocol https :inherit t :depth
                     treeless :ref
                     "6c8abedcf46ff08091fa2bba52eb905c6290057d"))
 (esxml :source "elpaca-menu-lock-file" :recipe
        (:package "esxml" :fetcher github :repo "tali713/esxml" :files
                  ("esxml.el" "esxml-query.el") :source "MELPA"
                  :protocol https :inherit t :depth treeless :ref
                  "affada143fed7e2da08f2b3d927a027f26ad4a8f"))
 (evil :source "elpaca-menu-lock-file" :recipe
       (:package "evil" :repo "emacs-evil/evil" :fetcher github :files
                 (:defaults "doc/build/texinfo/evil.texi"
                            (:exclude "evil-test-helpers.el"))
                 :source "MELPA" :protocol https :inherit t :depth
                 treeless :wait t :ref
                 "729d9a58b387704011a115c9200614e32da3cefc"))
 (evil-anzu :source "elpaca-menu-lock-file" :recipe
            (:package "evil-anzu" :fetcher github :repo
                      "emacsorphanage/evil-anzu" :files
                      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                       "doc/*.texinfo" "lisp/*.el" "docs/dir"
                       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                       (:exclude ".dir-locals.el" "test.el" "tests.el"
                                 "*-test.el" "*-tests.el" "LICENSE"
                                 "README*" "*-pkg.el"))
                      :source "MELPA" :protocol https :inherit t
                      :depth treeless :ref
                      "7309650425797420944075c9c1556c7c1ff960b3"))
 (evil-collection :source "elpaca-menu-lock-file" :recipe
                  (:package "evil-collection" :fetcher github :repo
                            "emacs-evil/evil-collection" :files
                            (:defaults "modes") :source "MELPA"
                            :protocol https :inherit t :depth treeless
                            :ref
                            "d052ad2ec1f6a4b101f873f01517b295cd7dc4a9"))
 (evil-exchange :source "elpaca-menu-lock-file" :recipe
                (:package "evil-exchange" :fetcher github :repo
                          "Dewdrops/evil-exchange" :files
                          ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                           "*.texinfo" "doc/dir" "doc/*.info"
                           "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                           "docs/dir" "docs/*.info" "docs/*.texi"
                           "docs/*.texinfo"
                           (:exclude ".dir-locals.el" "test.el"
                                     "tests.el" "*-test.el"
                                     "*-tests.el" "LICENSE" "README*"
                                     "*-pkg.el"))
                          :source "MELPA" :protocol https :inherit t
                          :depth treeless :ref
                          "5f0a2d41434c17c6fb02e4f744043775de1c63a2"))
 (evil-fringe-mark :source "elpaca-menu-lock-file" :recipe
                   (:package "evil-fringe-mark" :fetcher github :repo
                             "Andrew-William-Smith/evil-fringe-mark"
                             :files
                             ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                              "*.texinfo" "doc/dir" "doc/*.info"
                              "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                              "docs/dir" "docs/*.info" "docs/*.texi"
                              "docs/*.texinfo"
                              (:exclude ".dir-locals.el" "test.el"
                                        "tests.el" "*-test.el"
                                        "*-tests.el" "LICENSE"
                                        "README*" "*-pkg.el"))
                             :source "MELPA" :protocol https :inherit
                             t :depth treeless :ref
                             "a1689fddb7ee79aaa720a77aada1208b8afd5c20"))
 (evil-indent-plus :source "elpaca-menu-lock-file" :recipe
                   (:package "evil-indent-plus" :fetcher github :repo
                             "TheBB/evil-indent-plus" :files
                             ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                              "*.texinfo" "doc/dir" "doc/*.info"
                              "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                              "docs/dir" "docs/*.info" "docs/*.texi"
                              "docs/*.texinfo"
                              (:exclude ".dir-locals.el" "test.el"
                                        "tests.el" "*-test.el"
                                        "*-tests.el" "LICENSE"
                                        "README*" "*-pkg.el"))
                             :source "MELPA" :protocol https :inherit
                             t :depth treeless :ref
                             "f392696e4813f1d3a92c7eeed333248914ba6dae"))
 (evil-surround :source "elpaca-menu-lock-file" :recipe
                (:package "evil-surround" :repo
                          "emacs-evil/evil-surround" :fetcher github
                          :old-names (surround) :files
                          ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                           "*.texinfo" "doc/dir" "doc/*.info"
                           "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                           "docs/dir" "docs/*.info" "docs/*.texi"
                           "docs/*.texinfo"
                           (:exclude ".dir-locals.el" "test.el"
                                     "tests.el" "*-test.el"
                                     "*-tests.el" "LICENSE" "README*"
                                     "*-pkg.el"))
                          :source "MELPA" :protocol https :inherit t
                          :depth treeless :ref
                          "da05c60b0621cf33161bb4335153f75ff5c29d91"))
 (exec-path-from-shell :source "elpaca-menu-lock-file" :recipe
                       (:package "exec-path-from-shell" :fetcher
                                 github :repo
                                 "purcell/exec-path-from-shell" :files
                                 ("*.el" "*.el.in" "dir" "*.info"
                                  "*.texi" "*.texinfo" "doc/dir"
                                  "doc/*.info" "doc/*.texi"
                                  "doc/*.texinfo" "lisp/*.el"
                                  "docs/dir" "docs/*.info"
                                  "docs/*.texi" "docs/*.texinfo"
                                  (:exclude ".dir-locals.el" "test.el"
                                            "tests.el" "*-test.el"
                                            "*-tests.el" "LICENSE"
                                            "README*" "*-pkg.el"))
                                 :source "MELPA" :protocol https
                                 :inherit t :depth treeless :ref
                                 "7552abf032a383ff761e7d90e6b5cbb4658a728a"))
 (expand-region :source "elpaca-menu-lock-file" :recipe
                (:package "expand-region" :repo
                          "magnars/expand-region.el" :fetcher github
                          :files
                          ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                           "*.texinfo" "doc/dir" "doc/*.info"
                           "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                           "docs/dir" "docs/*.info" "docs/*.texi"
                           "docs/*.texinfo"
                           (:exclude ".dir-locals.el" "test.el"
                                     "tests.el" "*-test.el"
                                     "*-tests.el" "LICENSE" "README*"
                                     "*-pkg.el"))
                          :source "MELPA" :protocol https :inherit t
                          :depth treeless :ref
                          "351279272330cae6cecea941b0033a8dd8bcc4e8"))
 (explain-pause-mode :source "elpaca-menu-lock-file" :recipe
                     (:source nil :protocol https :inherit t :depth
                              treeless :host github :repo
                              "lastquestion/explain-pause-mode"
                              :package "explain-pause-mode" :ref
                              "ac3eb69f36f345506aad05a6d9bc3ef80d26914b"))
 (f :source "elpaca-menu-lock-file" :recipe
    (:package "f" :fetcher github :repo "rejeep/f.el" :files
              ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
               "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
               "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
               "docs/*.texinfo"
               (:exclude ".dir-locals.el" "test.el" "tests.el"
                         "*-test.el" "*-tests.el" "LICENSE" "README*"
                         "*-pkg.el"))
              :source "MELPA" :protocol https :inherit t :depth
              treeless :ref "931b6d0667fe03e7bf1c6c282d6d8d7006143c52"))
 (fancy-compilation :source "elpaca-menu-lock-file" :recipe
                    (:package "fancy-compilation" :fetcher codeberg
                              :repo
                              "ideasman42/emacs-fancy-compilation"
                              :files
                              ("*.el" "*.el.in" "dir" "*.info"
                               "*.texi" "*.texinfo" "doc/dir"
                               "doc/*.info" "doc/*.texi"
                               "doc/*.texinfo" "lisp/*.el" "docs/dir"
                               "docs/*.info" "docs/*.texi"
                               "docs/*.texinfo"
                               (:exclude ".dir-locals.el" "test.el"
                                         "tests.el" "*-test.el"
                                         "*-tests.el" "LICENSE"
                                         "README*" "*-pkg.el"))
                              :source "MELPA" :protocol https :inherit
                              t :depth treeless :ref
                              "502d36e0fb4c4daedc16ea5d732dcbc8285d6fb1"))
 (flycheck :source "elpaca-menu-lock-file" :recipe
           (:package "flycheck" :repo "flycheck/flycheck" :fetcher
                     github :files
                     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                      "doc/*.texinfo" "lisp/*.el" "docs/dir"
                      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                      (:exclude ".dir-locals.el" "test.el" "tests.el"
                                "*-test.el" "*-tests.el" "LICENSE"
                                "README*" "*-pkg.el"))
                     :source "MELPA" :protocol https :inherit t :depth
                     treeless :ref
                     "0e18f7fba13aa0436bdd952f06a0b7ab54ed1cd1"))
 (flycheck-aspell :source "elpaca-menu-lock-file" :recipe
                  (:package "flycheck-aspell" :fetcher github :repo
                            "leotaku/flycheck-aspell" :files
                            ("flycheck-aspell.el") :source "MELPA"
                            :protocol https :inherit t :depth treeless
                            :ref
                            "abbac0f6ccd94224f19c70d8545fddfe9c27351f"))
 (flycheck-indicator :source "elpaca-menu-lock-file" :recipe
                     (:package "flycheck-indicator" :fetcher github
                               :repo "gexplorer/flycheck-indicator"
                               :files
                               ("*.el" "*.el.in" "dir" "*.info"
                                "*.texi" "*.texinfo" "doc/dir"
                                "doc/*.info" "doc/*.texi"
                                "doc/*.texinfo" "lisp/*.el" "docs/dir"
                                "docs/*.info" "docs/*.texi"
                                "docs/*.texinfo"
                                (:exclude ".dir-locals.el" "test.el"
                                          "tests.el" "*-test.el"
                                          "*-tests.el" "LICENSE"
                                          "README*" "*-pkg.el"))
                               :source "MELPA" :protocol https
                               :inherit t :depth treeless :ref
                               "e00d9a20cbc21d6814c27cc9206296da394478e8"))
 (focus :source "elpaca-menu-lock-file" :recipe
        (:package "focus" :fetcher github :repo "larstvei/Focus"
                  :files
                  ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                   "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                   "doc/*.texinfo" "lisp/*.el" "docs/dir"
                   "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                   (:exclude ".dir-locals.el" "test.el" "tests.el"
                             "*-test.el" "*-tests.el" "LICENSE"
                             "README*" "*-pkg.el"))
                  :source "MELPA" :protocol https :inherit t :depth
                  treeless :ref
                  "a58e29e70948512dbcdbb24745e3fb0a59984925"))
 (font-utils :source "elpaca-menu-lock-file" :recipe
             (:package "font-utils" :repo "rolandwalker/font-utils"
                       :fetcher github :files
                       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                        "*.texinfo" "doc/dir" "doc/*.info"
                        "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                        "docs/dir" "docs/*.info" "docs/*.texi"
                        "docs/*.texinfo"
                        (:exclude ".dir-locals.el" "test.el"
                                  "tests.el" "*-test.el" "*-tests.el"
                                  "LICENSE" "README*" "*-pkg.el"))
                       :source "MELPA" :protocol https :inherit t
                       :depth treeless :ref
                       "abc572eb0dc30a26584c0058c3fe6c7273a10003"))
 (forge :source "elpaca-menu-lock-file" :recipe
        (:package "forge" :fetcher github :repo "magit/forge" :files
                  ("lisp/*.el" "docs/*.texi" ".dir-locals.el") :source
                  "MELPA" :protocol https :inherit t :depth treeless
                  :ref "86ed2978236d3f39a083e6a07f4819019c91ae5a"))
 (fringe-helper :source "elpaca-menu-lock-file" :recipe
                (:package "fringe-helper" :fetcher github :repo
                          "nschum/fringe-helper.el" :files
                          ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                           "*.texinfo" "doc/dir" "doc/*.info"
                           "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                           "docs/dir" "docs/*.info" "docs/*.texi"
                           "docs/*.texinfo"
                           (:exclude ".dir-locals.el" "test.el"
                                     "tests.el" "*-test.el"
                                     "*-tests.el" "LICENSE" "README*"
                                     "*-pkg.el"))
                          :source "MELPA" :protocol https :inherit t
                          :depth treeless :ref
                          "ef4a9c023bae18ec1ddd7265f1f2d6d2e775efdd"))
 (general :source "elpaca-menu-lock-file" :recipe
          (:package "general" :fetcher github :repo
                    "noctuid/general.el" :files
                    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                     "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                     "doc/*.texinfo" "lisp/*.el" "docs/dir"
                     "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                     (:exclude ".dir-locals.el" "test.el" "tests.el"
                               "*-test.el" "*-tests.el" "LICENSE"
                               "README*" "*-pkg.el"))
                    :source "MELPA" :protocol https :inherit t :depth
                    treeless :wait t :ref
                    "a48768f85a655fe77b5f45c2880b420da1b1b9c3"))
 (ghub :source "elpaca-menu-lock-file" :recipe
       (:package "ghub" :fetcher github :repo "magit/ghub" :files
                 ("lisp/*.el" "docs/*.texi" ".dir-locals.el") :source
                 "MELPA" :protocol https :inherit t :depth treeless
                 :ref "c22858596c1f5a1f5b439e475e7ba0e6a2e1718b"))
 (gif-screencast :source "elpaca-menu-lock-file" :recipe
                 (:package "gif-screencast" :repo
                           "Ambrevar/emacs-gif-screencast" :fetcher
                           gitlab :files
                           ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                            "*.texinfo" "doc/dir" "doc/*.info"
                            "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                            "docs/dir" "docs/*.info" "docs/*.texi"
                            "docs/*.texinfo"
                            (:exclude ".dir-locals.el" "test.el"
                                      "tests.el" "*-test.el"
                                      "*-tests.el" "LICENSE" "README*"
                                      "*-pkg.el"))
                           :source "MELPA" :protocol https :inherit t
                           :depth treeless :ref
                           "6798656d3d3107d16e30cc26bc3928b00e50c1ca"))
 (git-gutter :source "elpaca-menu-lock-file" :recipe
             (:package "git-gutter" :repo "emacsorphanage/git-gutter"
                       :fetcher github :files
                       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                        "*.texinfo" "doc/dir" "doc/*.info"
                        "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                        "docs/dir" "docs/*.info" "docs/*.texi"
                        "docs/*.texinfo"
                        (:exclude ".dir-locals.el" "test.el"
                                  "tests.el" "*-test.el" "*-tests.el"
                                  "LICENSE" "README*" "*-pkg.el"))
                       :source "MELPA" :protocol https :inherit t
                       :depth treeless :ref
                       "101b1e29ec4f4609b29a17877990f95993452188"))
 (git-link :source "elpaca-menu-lock-file" :recipe
           (:package "git-link" :fetcher github :repo "sshaw/git-link"
                     :files
                     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                      "doc/*.texinfo" "lisp/*.el" "docs/dir"
                      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                      (:exclude ".dir-locals.el" "test.el" "tests.el"
                                "*-test.el" "*-tests.el" "LICENSE"
                                "README*" "*-pkg.el"))
                     :source "MELPA" :protocol https :inherit t :depth
                     treeless :ref
                     "d9b375f79e6071a9926bf73bba64111adfc93bf5"))
 (git-timemachine :source "elpaca-menu-lock-file" :recipe
                  (:package "git-timemachine" :fetcher codeberg :repo
                            "pidu/git-timemachine" :files
                            ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                             "*.texinfo" "doc/dir" "doc/*.info"
                             "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                             "docs/dir" "docs/*.info" "docs/*.texi"
                             "docs/*.texinfo"
                             (:exclude ".dir-locals.el" "test.el"
                                       "tests.el" "*-test.el"
                                       "*-tests.el" "LICENSE"
                                       "README*" "*-pkg.el"))
                            :source "MELPA" :protocol https :inherit t
                            :depth treeless :ref
                            "d1346a76122595aeeb7ebb292765841c6cfd417b"))
 (gntp :source "elpaca-menu-lock-file" :recipe
       (:package "gntp" :repo "tekai/gntp.el" :fetcher github :files
                 ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
                  "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
                  "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
                  "docs/*.texinfo"
                  (:exclude ".dir-locals.el" "test.el" "tests.el"
                            "*-test.el" "*-tests.el" "LICENSE"
                            "README*" "*-pkg.el"))
                 :source "MELPA" :protocol https :inherit t :depth
                 treeless :ref
                 "767571135e2c0985944017dc59b0be79af222ef5"))
 (goto-chg :source "elpaca-menu-lock-file" :recipe
           (:package "goto-chg" :repo "emacs-evil/goto-chg" :fetcher
                     github :files
                     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                      "doc/*.texinfo" "lisp/*.el" "docs/dir"
                      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                      (:exclude ".dir-locals.el" "test.el" "tests.el"
                                "*-test.el" "*-tests.el" "LICENSE"
                                "README*" "*-pkg.el"))
                     :source "MELPA" :protocol https :inherit t :depth
                     treeless :ref
                     "72f556524b88e9d30dc7fc5b0dc32078c166fda7"))
 (gptel :source "elpaca-menu-lock-file" :recipe
        (:package "gptel" :repo "karthink/gptel" :fetcher github
                  :files
                  ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                   "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                   "doc/*.texinfo" "lisp/*.el" "docs/dir"
                   "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                   (:exclude ".dir-locals.el" "test.el" "tests.el"
                             "*-test.el" "*-tests.el" "LICENSE"
                             "README*" "*-pkg.el"))
                  :source "MELPA" :protocol https :inherit t :depth
                  treeless :ref
                  "63795dee75db49a04fd87842a1dcdef29c855f93"))
 (gptel-autocomplete :source "elpaca-menu-lock-file" :recipe
                     (:source nil :protocol https :inherit t :depth
                              treeless :type git :host github :repo
                              "JDNdeveloper/gptel-autocomplete"
                              :package "gptel-autocomplete" :ref
                              "8ace326a6e7b8a3a4df7a6e80272b472e7fbd167"))
 (gptel-prompts :source "elpaca-menu-lock-file" :recipe
                (:source nil :protocol https :inherit t :depth
                         treeless :type git :host github :repo
                         "jwiegley/gptel-prompts" :package
                         "gptel-prompts" :ref
                         "f1c29208c1f0b62918ac6682038da5db4184fc51"))
 (gptel-quick :source "elpaca-menu-lock-file" :recipe
              (:source nil :protocol https :inherit t :depth treeless
                       :type git :host github :repo
                       "karthink/gptel-quick" :package "gptel-quick"
                       :ref "018ff2be8f860a1e8fe3966eec418ad635620c38"))
 (graphviz-dot-mode :source "elpaca-menu-lock-file" :recipe
                    (:package "graphviz-dot-mode" :repo
                              "ppareit/graphviz-dot-mode" :fetcher
                              github :files
                              ("*.el" "*.el.in" "dir" "*.info"
                               "*.texi" "*.texinfo" "doc/dir"
                               "doc/*.info" "doc/*.texi"
                               "doc/*.texinfo" "lisp/*.el" "docs/dir"
                               "docs/*.info" "docs/*.texi"
                               "docs/*.texinfo"
                               (:exclude ".dir-locals.el" "test.el"
                                         "tests.el" "*-test.el"
                                         "*-tests.el" "LICENSE"
                                         "README*" "*-pkg.el"))
                              :source "MELPA" :protocol https :inherit
                              t :depth treeless :ref
                              "516c151b845a3eb2da73eb4ee648ad99172087ac"))
 (hcl-mode :source "elpaca-menu-lock-file" :recipe
           (:package "hcl-mode" :repo "hcl-emacs/hcl-mode" :fetcher
                     github :files
                     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                      "doc/*.texinfo" "lisp/*.el" "docs/dir"
                      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                      (:exclude ".dir-locals.el" "test.el" "tests.el"
                                "*-test.el" "*-tests.el" "LICENSE"
                                "README*" "*-pkg.el"))
                     :source "MELPA" :protocol https :inherit t :depth
                     treeless :ref
                     "1da895ed75d28d9f87cbf9b74f075d90ba31c0ed"))
 (helm :source "elpaca-menu-lock-file" :recipe
       (:package "helm" :fetcher github :repo "emacs-helm/helm" :files
                 (:defaults "emacs-helm.sh"
                            (:exclude "helm-lib.el" "helm-source.el"
                                      "helm-multi-match.el"
                                      "helm-core.el"))
                 :source "MELPA" :protocol https :inherit t :depth
                 treeless :ref
                 "9d8de1e0810ef5a5e1f3a46c9461b78b9e86167b"))
 (helm-core :source "elpaca-menu-lock-file" :recipe
            (:package "helm-core" :repo "emacs-helm/helm" :fetcher
                      github :files
                      ("helm-core.el" "helm-lib.el" "helm-source.el"
                       "helm-multi-match.el")
                      :source "MELPA" :protocol https :inherit t
                      :depth treeless :ref
                      "9d8de1e0810ef5a5e1f3a46c9461b78b9e86167b"))
 (helm-wikipedia :source "elpaca-menu-lock-file" :recipe
                 (:package "helm-wikipedia" :fetcher github :repo
                           "emacs-helm/helm-wikipedia" :files
                           ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                            "*.texinfo" "doc/dir" "doc/*.info"
                            "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                            "docs/dir" "docs/*.info" "docs/*.texi"
                            "docs/*.texinfo"
                            (:exclude ".dir-locals.el" "test.el"
                                      "tests.el" "*-test.el"
                                      "*-tests.el" "LICENSE" "README*"
                                      "*-pkg.el"))
                           :source "MELPA" :protocol https :inherit t
                           :depth treeless :ref
                           "e4b9434785e2a421af6e16ba50ea51eb54c7e490"))
 (helpful :source "elpaca-menu-lock-file" :recipe
          (:package "helpful" :repo "Wilfred/helpful" :fetcher github
                    :files
                    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                     "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                     "doc/*.texinfo" "lisp/*.el" "docs/dir"
                     "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                     (:exclude ".dir-locals.el" "test.el" "tests.el"
                               "*-test.el" "*-tests.el" "LICENSE"
                               "README*" "*-pkg.el"))
                    :source "MELPA" :protocol https :inherit t :depth
                    treeless :ref
                    "03756fa6ad4dcca5e0920622b1ee3f70abfc4e39"))
 (heroku-theme :source "elpaca-menu-lock-file" :recipe
               (:package "heroku-theme" :fetcher github :repo
                         "jonathanchu/heroku-theme" :files
                         ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                          "*.texinfo" "doc/dir" "doc/*.info"
                          "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                          "docs/dir" "docs/*.info" "docs/*.texi"
                          "docs/*.texinfo"
                          (:exclude ".dir-locals.el" "test.el"
                                    "tests.el" "*-test.el"
                                    "*-tests.el" "LICENSE" "README*"
                                    "*-pkg.el"))
                         :source "MELPA" :protocol https :inherit t
                         :depth treeless :ref
                         "8083643fe92ec3a1c3eb82f1b8dc2236c9c9691d"))
 (highlight :source "elpaca-menu-lock-file" :recipe
            (:package "highlight" :fetcher github :repo
                      "emacsmirror/highlight" :branch "melpa" :files
                      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                       "doc/*.texinfo" "lisp/*.el" "docs/dir"
                       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                       (:exclude ".dir-locals.el" "test.el" "tests.el"
                                 "*-test.el" "*-tests.el" "LICENSE"
                                 "README*" "*-pkg.el"))
                      :source "MELPA" :protocol https :inherit t
                      :depth treeless :ref
                      "28557cb8d99b96eb509aaec1334c7cdda162517f"))
 (highlight-indent-guides :source "elpaca-menu-lock-file" :recipe
                          (:package "highlight-indent-guides" :fetcher
                                    github :repo
                                    "DarthFennec/highlight-indent-guides"
                                    :files
                                    ("*.el" "*.el.in" "dir" "*.info"
                                     "*.texi" "*.texinfo" "doc/dir"
                                     "doc/*.info" "doc/*.texi"
                                     "doc/*.texinfo" "lisp/*.el"
                                     "docs/dir" "docs/*.info"
                                     "docs/*.texi" "docs/*.texinfo"
                                     (:exclude ".dir-locals.el"
                                               "test.el" "tests.el"
                                               "*-test.el"
                                               "*-tests.el" "LICENSE"
                                               "README*" "*-pkg.el"))
                                    :source "MELPA" :protocol https
                                    :inherit t :depth treeless :ref
                                    "802fb2eaf67ead730d7e3483b9a1e9639705f267"))
 (hl-todo :source "elpaca-menu-lock-file" :recipe
          (:package "hl-todo" :repo "tarsius/hl-todo" :fetcher github
                    :files
                    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                     "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                     "doc/*.texinfo" "lisp/*.el" "docs/dir"
                     "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                     (:exclude ".dir-locals.el" "test.el" "tests.el"
                               "*-test.el" "*-tests.el" "LICENSE"
                               "README*" "*-pkg.el"))
                    :source "MELPA" :protocol https :inherit t :depth
                    treeless :ref
                    "9540fc414014822dde00f0188b74e17ac99e916d"))
 (hsluv :source "elpaca-menu-lock-file" :recipe
        (:package "hsluv" :fetcher github :repo "hsluv/hsluv-emacs"
                  :files
                  ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                   "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                   "doc/*.texinfo" "lisp/*.el" "docs/dir"
                   "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                   (:exclude ".dir-locals.el" "test.el" "tests.el"
                             "*-test.el" "*-tests.el" "LICENSE"
                             "README*" "*-pkg.el"))
                  :source "MELPA" :protocol https :inherit t :depth
                  treeless :ref
                  "c3bc5228e30d66e7dee9ff1a0694c2b976862fc0"))
 (ht :source "elpaca-menu-lock-file" :recipe
     (:package "ht" :fetcher github :repo "Wilfred/ht.el" :files
               ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
                "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
                "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
                "docs/*.texinfo"
                (:exclude ".dir-locals.el" "test.el" "tests.el"
                          "*-test.el" "*-tests.el" "LICENSE" "README*"
                          "*-pkg.el"))
               :source "MELPA" :protocol https :inherit t :depth
               treeless :ref
               "1c49aad1c820c86f7ee35bf9fff8429502f60fef"))
 (htmlize :source "elpaca-menu-lock-file" :recipe
          (:package "htmlize" :fetcher github :repo
                    "emacsorphanage/htmlize" :files
                    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                     "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                     "doc/*.texinfo" "lisp/*.el" "docs/dir"
                     "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                     (:exclude ".dir-locals.el" "test.el" "tests.el"
                               "*-test.el" "*-tests.el" "LICENSE"
                               "README*" "*-pkg.el"))
                    :source "MELPA" :protocol https :inherit t :depth
                    treeless :ref
                    "fa644880699adea3770504f913e6dddbec90c076"))
 (hungry-delete :source "elpaca-menu-lock-file" :recipe
                (:package "hungry-delete" :fetcher github :repo
                          "nflath/hungry-delete" :files
                          ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                           "*.texinfo" "doc/dir" "doc/*.info"
                           "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                           "docs/dir" "docs/*.info" "docs/*.texi"
                           "docs/*.texinfo"
                           (:exclude ".dir-locals.el" "test.el"
                                     "tests.el" "*-test.el"
                                     "*-tests.el" "LICENSE" "README*"
                                     "*-pkg.el"))
                          :source "MELPA" :protocol https :inherit t
                          :depth treeless :ref
                          "d919e555e5c13a2edf4570f3ceec84f0ade71657"))
 (hydra :source "elpaca-menu-lock-file" :recipe
        (:package "hydra" :repo "abo-abo/hydra" :fetcher github :files
                  (:defaults (:exclude "lv.el")) :source "MELPA"
                  :protocol https :inherit t :depth treeless :ref
                  "59a2a45a35027948476d1d7751b0f0215b1e61aa"))
 (iedit :source "elpaca-menu-lock-file" :recipe
        (:package "iedit" :repo "victorhge/iedit" :fetcher github
                  :files
                  ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                   "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                   "doc/*.texinfo" "lisp/*.el" "docs/dir"
                   "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                   (:exclude ".dir-locals.el" "test.el" "tests.el"
                             "*-test.el" "*-tests.el" "LICENSE"
                             "README*" "*-pkg.el"))
                  :source "MELPA" :protocol https :inherit t :depth
                  treeless :ref
                  "14161daa295332a49dda92b97c00d62efd38acfe"))
 (ivy :source "elpaca-menu-lock-file" :recipe
      (:package "ivy" :repo "abo-abo/swiper" :fetcher github :files
                (:defaults "doc/ivy-help.org"
                           (:exclude "swiper.el" "counsel.el"
                                     "ivy-hydra.el" "ivy-avy.el"))
                :source "MELPA" :protocol https :inherit t :depth
                treeless :ref
                "ee79f68215ae7e2b8a38ba6bf7f82b3fe57dc16c"))
 (jbeans-theme :source "elpaca-menu-lock-file" :recipe
               (:package "jbeans-theme" :fetcher github :repo
                         "synic/jbeans-emacs" :files
                         ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                          "*.texinfo" "doc/dir" "doc/*.info"
                          "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                          "docs/dir" "docs/*.info" "docs/*.texi"
                          "docs/*.texinfo"
                          (:exclude ".dir-locals.el" "test.el"
                                    "tests.el" "*-test.el"
                                    "*-tests.el" "LICENSE" "README*"
                                    "*-pkg.el"))
                         :source "MELPA" :protocol https :inherit t
                         :depth treeless :ref
                         "a63916a928324c42bfbe3016972c2ecff598b1ae"))
 (js2-mode :source "elpaca-menu-lock-file" :recipe
           (:package "js2-mode" :repo "mooz/js2-mode" :fetcher github
                     :files
                     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                      "doc/*.texinfo" "lisp/*.el" "docs/dir"
                      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                      (:exclude ".dir-locals.el" "test.el" "tests.el"
                                "*-test.el" "*-tests.el" "LICENSE"
                                "README*" "*-pkg.el"))
                     :source "MELPA" :protocol https :inherit t :depth
                     treeless :ref
                     "e0c302872de4d26a9c1614fac8d6b94112b96307"))
 (json-mode :source "elpaca-menu-lock-file" :recipe
            (:package "json-mode" :fetcher github :repo
                      "json-emacs/json-mode" :files
                      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                       "doc/*.texinfo" "lisp/*.el" "docs/dir"
                       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                       (:exclude ".dir-locals.el" "test.el" "tests.el"
                                 "*-test.el" "*-tests.el" "LICENSE"
                                 "README*" "*-pkg.el"))
                      :source "MELPA" :protocol https :inherit t
                      :depth treeless :ref
                      "466d5b563721bbeffac3f610aefaac15a39d90a9"))
 (json-snatcher :source "elpaca-menu-lock-file" :recipe
                (:package "json-snatcher" :fetcher github :repo
                          "Sterlingg/json-snatcher" :files
                          ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                           "*.texinfo" "doc/dir" "doc/*.info"
                           "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                           "docs/dir" "docs/*.info" "docs/*.texi"
                           "docs/*.texinfo"
                           (:exclude ".dir-locals.el" "test.el"
                                     "tests.el" "*-test.el"
                                     "*-tests.el" "LICENSE" "README*"
                                     "*-pkg.el"))
                          :source "MELPA" :protocol https :inherit t
                          :depth treeless :ref
                          "b28d1c0670636da6db508d03872d96ffddbc10f2"))
 (jsonian :source "elpaca-menu-lock-file" :recipe
          (:package "jsonian" :fetcher github :repo "iwahbe/jsonian"
                    :files
                    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                     "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                     "doc/*.texinfo" "lisp/*.el" "docs/dir"
                     "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                     (:exclude ".dir-locals.el" "test.el" "tests.el"
                               "*-test.el" "*-tests.el" "LICENSE"
                               "README*" "*-pkg.el"))
                    :source "MELPA" :protocol https :inherit t :depth
                    treeless :ref
                    "513219ebb3ccdefc915715e4bf2dd6e718fabccd"))
 (key-chord :source "elpaca-menu-lock-file" :recipe
            (:package "key-chord" :fetcher github :repo
                      "emacsorphanage/key-chord" :files
                      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                       "doc/*.texinfo" "lisp/*.el" "docs/dir"
                       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                       (:exclude ".dir-locals.el" "test.el" "tests.el"
                                 "*-test.el" "*-tests.el" "LICENSE"
                                 "README*" "*-pkg.el"))
                      :source "MELPA" :protocol https :inherit t
                      :depth treeless :ref
                      "cb646e815c61f253ad9fdfbe058049dda4e2b32b"))
 (key-quiz :source "elpaca-menu-lock-file" :recipe
           (:package "key-quiz" :repo "federicotdn/key-quiz" :fetcher
                     github :files
                     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                      "doc/*.texinfo" "lisp/*.el" "docs/dir"
                      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                      (:exclude ".dir-locals.el" "test.el" "tests.el"
                                "*-test.el" "*-tests.el" "LICENSE"
                                "README*" "*-pkg.el"))
                     :source "MELPA" :protocol https :inherit t :depth
                     treeless :ref
                     "6d31fcf78a1ab1841f735dfb5cbd2bf6b2ed25db"))
 (keycast :source "elpaca-menu-lock-file" :recipe
          (:package "keycast" :fetcher github :repo "tarsius/keycast"
                    :files
                    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                     "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                     "doc/*.texinfo" "lisp/*.el" "docs/dir"
                     "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                     (:exclude ".dir-locals.el" "test.el" "tests.el"
                               "*-test.el" "*-tests.el" "LICENSE"
                               "README*" "*-pkg.el"))
                    :source "MELPA" :protocol https :inherit t :depth
                    treeless :ref
                    "b831e380c4deb1d51ce5db0a965b96427aec52e4"))
 (know-your-http-well :source "elpaca-menu-lock-file" :recipe
                      (:package "know-your-http-well" :fetcher github
                                :repo "for-GET/know-your-http-well"
                                :files ("emacs/*.el") :source "MELPA"
                                :protocol https :inherit t :depth
                                treeless :ref
                                "c916e825b0c75c2f2b6ff5ba79c981cff7de5797"))
 (kubel :source "elpaca-menu-lock-file" :recipe
        (:package "kubel" :fetcher github :repo "abrochard/kubel"
                  :files (:defaults (:exclude "kubel-evil.el"))
                  :source "MELPA" :protocol https :inherit t :depth
                  treeless :ref
                  "7b0a13704675f1bca7d951444c637d4c967e9303"))
 (kubernetes :source "elpaca-menu-lock-file" :recipe
             (:package "kubernetes" :repo
                       "kubernetes-el/kubernetes-el" :fetcher github
                       :files
                       (:defaults (:exclude "kubernetes-evil.el"))
                       :source "MELPA" :protocol https :inherit t
                       :depth treeless :ref
                       "036583995bfceb0231738f65dd09c029ad812b02"))
 (kv :source "elpaca-menu-lock-file" :recipe
     (:package "kv" :fetcher github :repo "nicferrier/emacs-kv" :files
               ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
                "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
                "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
                "docs/*.texinfo"
                (:exclude ".dir-locals.el" "test.el" "tests.el"
                          "*-test.el" "*-tests.el" "LICENSE" "README*"
                          "*-pkg.el"))
               :source "MELPA" :protocol https :inherit t :depth
               treeless :ref
               "721148475bce38a70e0b678ba8aa923652e8900e"))
 (lark-mode :source "elpaca-menu-lock-file" :recipe
            (:package "lark-mode" :repo "taquangtrung/lark-mode"
                      :fetcher github :files
                      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                       "doc/*.texinfo" "lisp/*.el" "docs/dir"
                       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                       (:exclude ".dir-locals.el" "test.el" "tests.el"
                                 "*-test.el" "*-tests.el" "LICENSE"
                                 "README*" "*-pkg.el"))
                      :source "MELPA" :protocol https :inherit t
                      :depth treeless :ref
                      "0a0724b0f64d433d81f90ba8f86e618f8c33522a"))
 (lavender-theme :source "elpaca-menu-lock-file" :recipe
                 (:package "lavender-theme" :fetcher github :repo
                           "emacsfodder/emacs-lavender-theme" :files
                           ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                            "*.texinfo" "doc/dir" "doc/*.info"
                            "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                            "docs/dir" "docs/*.info" "docs/*.texi"
                            "docs/*.texinfo"
                            (:exclude ".dir-locals.el" "test.el"
                                      "tests.el" "*-test.el"
                                      "*-tests.el" "LICENSE" "README*"
                                      "*-pkg.el"))
                           :source "MELPA" :protocol https :inherit t
                           :depth treeless :ref
                           "ef5e959b95d7fb8152137bc186c4c24e986c1e3c"))
 (leuven-theme :source "elpaca-menu-lock-file" :recipe
               (:package "leuven-theme" :fetcher github :repo
                         "fniessen/emacs-leuven-theme" :files
                         ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                          "*.texinfo" "doc/dir" "doc/*.info"
                          "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                          "docs/dir" "docs/*.info" "docs/*.texi"
                          "docs/*.texinfo"
                          (:exclude ".dir-locals.el" "test.el"
                                    "tests.el" "*-test.el"
                                    "*-tests.el" "LICENSE" "README*"
                                    "*-pkg.el"))
                         :source "MELPA" :protocol https :inherit t
                         :depth treeless :ref
                         "c3546e6a84c138fd8cdbd33998fefcf834c45018"))
 (list-utils :source "elpaca-menu-lock-file" :recipe
             (:package "list-utils" :repo "rolandwalker/list-utils"
                       :fetcher github :files
                       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                        "*.texinfo" "doc/dir" "doc/*.info"
                        "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                        "docs/dir" "docs/*.info" "docs/*.texi"
                        "docs/*.texinfo"
                        (:exclude ".dir-locals.el" "test.el"
                                  "tests.el" "*-test.el" "*-tests.el"
                                  "LICENSE" "README*" "*-pkg.el"))
                       :source "MELPA" :protocol https :inherit t
                       :depth treeless :ref
                       "bbea0e7cc7ab7d96e7f062014bde438aa8ffcd43"))
 (llama :source "elpaca-menu-lock-file" :recipe
        (:package "llama" :fetcher github :repo "tarsius/llama" :files
                  ("llama.el" ".dir-locals.el") :source "MELPA"
                  :protocol https :inherit t :depth treeless :ref
                  "d430d48e0b5afd2a34b5531f103dcb110c3539c4"))
 (log4e :source "elpaca-menu-lock-file" :recipe
        (:package "log4e" :repo "aki2o/log4e" :fetcher github :files
                  ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                   "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                   "doc/*.texinfo" "lisp/*.el" "docs/dir"
                   "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                   (:exclude ".dir-locals.el" "test.el" "tests.el"
                             "*-test.el" "*-tests.el" "LICENSE"
                             "README*" "*-pkg.el"))
                  :source "MELPA" :protocol https :inherit t :depth
                  treeless :ref
                  "6d71462df9bf595d3861bfb328377346aceed422"))
 (lsp-docker :source "elpaca-menu-lock-file" :recipe
             (:package "lsp-docker" :repo "emacs-lsp/lsp-docker"
                       :fetcher github :files
                       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                        "*.texinfo" "doc/dir" "doc/*.info"
                        "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                        "docs/dir" "docs/*.info" "docs/*.texi"
                        "docs/*.texinfo"
                        (:exclude ".dir-locals.el" "test.el"
                                  "tests.el" "*-test.el" "*-tests.el"
                                  "LICENSE" "README*" "*-pkg.el"))
                       :source "MELPA" :protocol https :inherit t
                       :depth treeless :ref
                       "ff41f4a76b640d39dc238bacba7f654c297827fa"))
 (lsp-mode :source "elpaca-menu-lock-file" :recipe
           (:package "lsp-mode" :repo "emacs-lsp/lsp-mode" :fetcher
                     github :files (:defaults "clients/*.*") :source
                     "MELPA" :protocol https :inherit t :depth
                     treeless :ref
                     "3e55ca80712d66f2fc38bad514b5e2521751433d"))
 (lsp-pyright :source "elpaca-menu-lock-file" :recipe
              (:package "lsp-pyright" :repo "emacs-lsp/lsp-pyright"
                        :fetcher github :files
                        ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                         "*.texinfo" "doc/dir" "doc/*.info"
                         "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                         "docs/dir" "docs/*.info" "docs/*.texi"
                         "docs/*.texinfo"
                         (:exclude ".dir-locals.el" "test.el"
                                   "tests.el" "*-test.el" "*-tests.el"
                                   "LICENSE" "README*" "*-pkg.el"))
                        :source "MELPA" :protocol https :inherit t
                        :depth treeless :ref
                        "21b8f487855feb08f7df669b8884fbd5861dca25"))
 (lsp-treemacs :source "elpaca-menu-lock-file" :recipe
               (:package "lsp-treemacs" :repo "emacs-lsp/lsp-treemacs"
                         :fetcher github :files (:defaults "icons")
                         :source "MELPA" :protocol https :inherit t
                         :depth treeless :ref
                         "49df7292c521b4bac058985ceeaf006607b497dd"))
 (lsp-ui :source "elpaca-menu-lock-file" :recipe
         (:package "lsp-ui" :repo "emacs-lsp/lsp-ui" :fetcher github
                   :files (:defaults "lsp-ui-doc.html" "resources")
                   :source "MELPA" :protocol https :inherit t :depth
                   treeless :ref
                   "ff349658ed69086bd18c336c8a071ba15f7fd574"))
 (lv :source "elpaca-menu-lock-file" :recipe
     (:package "lv" :repo "abo-abo/hydra" :fetcher github :files
               ("lv.el") :source "MELPA" :protocol https :inherit t
               :depth treeless :ref
               "59a2a45a35027948476d1d7751b0f0215b1e61aa"))
 (macrostep :source "elpaca-menu-lock-file" :recipe
            (:package "macrostep" :fetcher github :repo
                      "emacsorphanage/macrostep" :files
                      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                       "doc/*.texinfo" "lisp/*.el" "docs/dir"
                       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                       (:exclude ".dir-locals.el" "test.el" "tests.el"
                                 "*-test.el" "*-tests.el" "LICENSE"
                                 "README*" "*-pkg.el"))
                      :source "MELPA" :protocol https :inherit t
                      :depth treeless :ref
                      "d0928626b4711dcf9f8f90439d23701118724199"))
 (magit :source "elpaca-menu-lock-file" :recipe
        (:package "magit" :fetcher github :repo "magit/magit" :files
                  ("lisp/magit*.el" "lisp/git-*.el" "docs/magit.texi"
                   "docs/AUTHORS.md" "LICENSE" ".dir-locals.el"
                   ("git-hooks" "git-hooks/*")
                   (:exclude "lisp/magit-section.el"))
                  :source "MELPA" :protocol https :inherit t :depth
                  treeless :ref
                  "b9f19bae4d5e5c485d2d8d7bf52364eeb7d22a6b"))
 (magit-popup :source "elpaca-menu-lock-file" :recipe
              (:package "magit-popup" :fetcher github :repo
                        "magit/magit-popup" :files
                        ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                         "*.texinfo" "doc/dir" "doc/*.info"
                         "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                         "docs/dir" "docs/*.info" "docs/*.texi"
                         "docs/*.texinfo"
                         (:exclude ".dir-locals.el" "test.el"
                                   "tests.el" "*-test.el" "*-tests.el"
                                   "LICENSE" "README*" "*-pkg.el"))
                        :source "MELPA" :protocol https :inherit t
                        :depth treeless :ref
                        "d8585fa39f88956963d877b921322530257ba9f5"))
 (magit-section :source "elpaca-menu-lock-file" :recipe
                (:package "magit-section" :fetcher github :repo
                          "magit/magit" :files
                          ("lisp/magit-section.el"
                           "docs/magit-section.texi"
                           "magit-section-pkg.el")
                          :source "MELPA" :protocol https :inherit t
                          :depth treeless :ref
                          "b9f19bae4d5e5c485d2d8d7bf52364eeb7d22a6b"))
 (magneto :source "elpaca-menu-lock-file" :recipe
          (:source nil :protocol https :inherit t :depth treeless
                   :host github :repo "chiply/magneto" :package
                   "magneto" :ref
                   "5cec06bf79eecc0de6a1b186c11de2b1b532b48c"))
 (marginalia :source "elpaca-menu-lock-file" :recipe
             (:package "marginalia" :repo "minad/marginalia" :fetcher
                       github :files
                       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                        "*.texinfo" "doc/dir" "doc/*.info"
                        "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                        "docs/dir" "docs/*.info" "docs/*.texi"
                        "docs/*.texinfo"
                        (:exclude ".dir-locals.el" "test.el"
                                  "tests.el" "*-test.el" "*-tests.el"
                                  "LICENSE" "README*" "*-pkg.el"))
                       :source "MELPA" :protocol https :inherit t
                       :depth treeless :ref
                       "142e4da1bd76dc5bdbbfd15532571b8a271e680e"))
 (markdown-mode :source "elpaca-menu-lock-file" :recipe
                (:package "markdown-mode" :fetcher github :repo
                          "jrblevin/markdown-mode" :files
                          ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                           "*.texinfo" "doc/dir" "doc/*.info"
                           "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                           "docs/dir" "docs/*.info" "docs/*.texi"
                           "docs/*.texinfo"
                           (:exclude ".dir-locals.el" "test.el"
                                     "tests.el" "*-test.el"
                                     "*-tests.el" "LICENSE" "README*"
                                     "*-pkg.el"))
                          :source "MELPA" :protocol https :inherit t
                          :depth treeless :ref
                          "f8d1be7cd5dfd64c0e4f88c29a3f84408cde0b47"))
 (markdown-toc :source "elpaca-menu-lock-file" :recipe
               (:package "markdown-toc" :fetcher github :repo
                         "ardumont/markdown-toc" :files
                         ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                          "*.texinfo" "doc/dir" "doc/*.info"
                          "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                          "docs/dir" "docs/*.info" "docs/*.texi"
                          "docs/*.texinfo"
                          (:exclude ".dir-locals.el" "test.el"
                                    "tests.el" "*-test.el"
                                    "*-tests.el" "LICENSE" "README*"
                                    "*-pkg.el"))
                         :source "MELPA" :protocol https :inherit t
                         :depth treeless :ref
                         "d22633b654193bcab322ec51b6dd3bb98dd5f69f"))
 (mastodon :source "elpaca-menu-lock-file" :recipe
           (:package "mastodon" :fetcher codeberg :repo
                     "martianh/mastodon.el" :files
                     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                      "doc/*.texinfo" "lisp/*.el" "docs/dir"
                      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                      (:exclude ".dir-locals.el" "test.el" "tests.el"
                                "*-test.el" "*-tests.el" "LICENSE"
                                "README*" "*-pkg.el"))
                     :source "MELPA" :protocol https :inherit t :depth
                     treeless :ref
                     "edea11cc69c7fc45cb3606b9bff90c89372bdea1"))
 (mcp :source "elpaca-menu-lock-file" :recipe
      (:package "mcp" :fetcher github :repo "lizqwerscott/mcp.el"
                :files
                ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
                 "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
                 "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
                 "docs/*.texinfo"
                 (:exclude ".dir-locals.el" "test.el" "tests.el"
                           "*-test.el" "*-tests.el" "LICENSE"
                           "README*" "*-pkg.el"))
                :source "MELPA" :protocol https :inherit t :depth
                treeless :type git :host github :ref
                "5c105a8db470eb9777fdbd26251548dec42c03f0"))
 (md4rd :source "elpaca-menu-lock-file" :recipe
        (:package "md4rd" :repo "ahungry/md4rd" :fetcher github :files
                  ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                   "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                   "doc/*.texinfo" "lisp/*.el" "docs/dir"
                   "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                   (:exclude ".dir-locals.el" "test.el" "tests.el"
                             "*-test.el" "*-tests.el" "LICENSE"
                             "README*" "*-pkg.el"))
                  :source "MELPA" :protocol https :inherit t :depth
                  treeless :ref
                  "2fa198af749e9ddb759e052d911f56a626088903"))
 (meow :source "elpaca-menu-lock-file" :recipe
       (:package "meow" :repo "meow-edit/meow" :fetcher github :files
                 ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
                  "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
                  "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
                  "docs/*.texinfo"
                  (:exclude ".dir-locals.el" "test.el" "tests.el"
                            "*-test.el" "*-tests.el" "LICENSE"
                            "README*" "*-pkg.el"))
                 :source "MELPA" :protocol https :inherit t :depth
                 treeless :ref
                 "2246f593552c6208bac533de9af04b085fafa6fa"))
 (mermaid-mode :source "elpaca-menu-lock-file" :recipe
               (:package "mermaid-mode" :repo "abrochard/mermaid-mode"
                         :fetcher github :files
                         ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                          "*.texinfo" "doc/dir" "doc/*.info"
                          "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                          "docs/dir" "docs/*.info" "docs/*.texi"
                          "docs/*.texinfo"
                          (:exclude ".dir-locals.el" "test.el"
                                    "tests.el" "*-test.el"
                                    "*-tests.el" "LICENSE" "README*"
                                    "*-pkg.el"))
                         :source "MELPA" :protocol https :inherit t
                         :depth treeless :ref
                         "3b972164bf6a20b2f51607791b1e593ffa1e63cc"))
 (minimap :source "elpaca-menu-lock-file" :recipe
          (:package "minimap" :repo
                    ("https://github.com/emacsmirror/gnu_elpa"
                     . "minimap")
                    :branch "externals/minimap" :files
                    ("*" (:exclude ".git")) :source "GNU ELPA"
                    :protocol https :inherit t :depth treeless :ref
                    "b295cab07c1932c11dd00f23ba29c1ff0de486ab"))
 (modern-fringes :source "elpaca-menu-lock-file" :recipe
                 (:package "modern-fringes" :repo
                           "SpecialBomb/emacs-modern-fringes" :fetcher
                           github :files
                           ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                            "*.texinfo" "doc/dir" "doc/*.info"
                            "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                            "docs/dir" "docs/*.info" "docs/*.texi"
                            "docs/*.texinfo"
                            (:exclude ".dir-locals.el" "test.el"
                                      "tests.el" "*-test.el"
                                      "*-tests.el" "LICENSE" "README*"
                                      "*-pkg.el"))
                           :source "MELPA" :protocol https :inherit t
                           :depth treeless :ref
                           "98473694a33922cfdddb18b4791028e4854b53b5"))
 (modus-themes :source "elpaca-menu-lock-file" :recipe
               (:package "modus-themes" :fetcher github :repo
                         "protesilaos/modus-themes" :files
                         ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                          "*.texinfo" "doc/dir" "doc/*.info"
                          "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                          "docs/dir" "docs/*.info" "docs/*.texi"
                          "docs/*.texinfo"
                          (:exclude ".dir-locals.el" "test.el"
                                    "tests.el" "*-test.el"
                                    "*-tests.el" "LICENSE" "README*"
                                    "*-pkg.el"))
                         :source "MELPA" :protocol https :inherit t
                         :depth treeless :ref
                         "9d0226961d32fac7c14ad9fe613807a6913188c6"))
 (move-text :source "elpaca-menu-lock-file" :recipe
            (:package "move-text" :fetcher github :repo
                      "emacsfodder/move-text" :files
                      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                       "doc/*.texinfo" "lisp/*.el" "docs/dir"
                       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                       (:exclude ".dir-locals.el" "test.el" "tests.el"
                                 "*-test.el" "*-tests.el" "LICENSE"
                                 "README*" "*-pkg.el"))
                      :source "MELPA" :protocol https :inherit t
                      :depth treeless :ref
                      "2a8ebefeb0b363681e9562847eca3fd66e090d70"))
 (mu4e-column-faces :source "elpaca-menu-lock-file" :recipe
                    (:package "mu4e-column-faces" :repo
                              "Alexander-Miller/mu4e-column-faces"
                              :fetcher github :files
                              ("*.el" "*.el.in" "dir" "*.info"
                               "*.texi" "*.texinfo" "doc/dir"
                               "doc/*.info" "doc/*.texi"
                               "doc/*.texinfo" "lisp/*.el" "docs/dir"
                               "docs/*.info" "docs/*.texi"
                               "docs/*.texinfo"
                               (:exclude ".dir-locals.el" "test.el"
                                         "tests.el" "*-test.el"
                                         "*-tests.el" "LICENSE"
                                         "README*" "*-pkg.el"))
                              :source "MELPA" :protocol https :inherit
                              t :depth treeless :ref
                              "b3586a9bf61f0cddd8a9f4cb214458f13d37955a"))
 (mu4e-overview :source "elpaca-menu-lock-file" :recipe
                (:package "mu4e-overview" :fetcher github :repo
                          "mkcms/mu4e-overview" :files
                          ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                           "*.texinfo" "doc/dir" "doc/*.info"
                           "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                           "docs/dir" "docs/*.info" "docs/*.texi"
                           "docs/*.texinfo"
                           (:exclude ".dir-locals.el" "test.el"
                                     "tests.el" "*-test.el"
                                     "*-tests.el" "LICENSE" "README*"
                                     "*-pkg.el"))
                          :source "MELPA" :protocol https :inherit t
                          :depth treeless :ref
                          "80bb7bb5fdcd0d28c4ff6a362f4dab171b471981"))
 (mu4e-query-fragments :source "elpaca-menu-lock-file" :recipe
                       (:package "mu4e-query-fragments" :repo
                                 "wavexx/mu4e-query-fragments.el"
                                 :fetcher gitlab :files
                                 ("*.el" "*.el.in" "dir" "*.info"
                                  "*.texi" "*.texinfo" "doc/dir"
                                  "doc/*.info" "doc/*.texi"
                                  "doc/*.texinfo" "lisp/*.el"
                                  "docs/dir" "docs/*.info"
                                  "docs/*.texi" "docs/*.texinfo"
                                  (:exclude ".dir-locals.el" "test.el"
                                            "tests.el" "*-test.el"
                                            "*-tests.el" "LICENSE"
                                            "README*" "*-pkg.el"))
                                 :source "MELPA" :protocol https
                                 :inherit t :depth treeless :ref
                                 "14b38e4a7b7aae47f3c1bdccb6680f8c38c645bf"))
 (multiple-cursors :source "elpaca-menu-lock-file" :recipe
                   (:package "multiple-cursors" :fetcher github :repo
                             "magnars/multiple-cursors.el" :files
                             ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                              "*.texinfo" "doc/dir" "doc/*.info"
                              "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                              "docs/dir" "docs/*.info" "docs/*.texi"
                              "docs/*.texinfo"
                              (:exclude ".dir-locals.el" "test.el"
                                        "tests.el" "*-test.el"
                                        "*-tests.el" "LICENSE"
                                        "README*" "*-pkg.el"))
                             :source "MELPA" :protocol https :inherit
                             t :depth treeless :ref
                             "ddd677091afc7d65ce56d11866e18aeded110ada"))
 (mw-thesaurus :source "elpaca-menu-lock-file" :recipe
               (:package "mw-thesaurus" :repo "agzam/mw-thesaurus.el"
                         :fetcher github :files
                         ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                          "*.texinfo" "doc/dir" "doc/*.info"
                          "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                          "docs/dir" "docs/*.info" "docs/*.texi"
                          "docs/*.texinfo"
                          (:exclude ".dir-locals.el" "test.el"
                                    "tests.el" "*-test.el"
                                    "*-tests.el" "LICENSE" "README*"
                                    "*-pkg.el"))
                         :source "MELPA" :protocol https :inherit t
                         :depth treeless :ref
                         "c44d793595c2d0f6789621da457da065920968ac"))
 (nano-theme :source "elpaca-menu-lock-file" :recipe
             (:package "nano-theme" :repo
                       ("https://github.com/rougier/nano-theme"
                        . "nano-theme")
                       :files ("*" (:exclude ".git")) :source
                       "GNU ELPA" :protocol https :inherit t :depth
                       treeless :ref
                       "41ef36999bacbffe43c4a96320ad6bb285b7f09f"))
 (nerd-icons :source "elpaca-menu-lock-file" :recipe
             (:package "nerd-icons" :repo
                       "rainstormstudio/nerd-icons.el" :fetcher github
                       :files (:defaults "data") :source "MELPA"
                       :protocol https :inherit t :depth treeless :ref
                       "9a7f44db9a53567f04603bc88d05402cad49c64c"))
 (nerd-icons-corfu :source "elpaca-menu-lock-file" :recipe
                   (:package "nerd-icons-corfu" :fetcher github :repo
                             "LuigiPiucco/nerd-icons-corfu" :files
                             ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                              "*.texinfo" "doc/dir" "doc/*.info"
                              "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                              "docs/dir" "docs/*.info" "docs/*.texi"
                              "docs/*.texinfo"
                              (:exclude ".dir-locals.el" "test.el"
                                        "tests.el" "*-test.el"
                                        "*-tests.el" "LICENSE"
                                        "README*" "*-pkg.el"))
                             :source "MELPA" :protocol https :inherit
                             t :depth treeless :ref
                             "f821e953b1a3dc9b381bc53486aabf366bf11cb1"))
 (nord-theme :source "elpaca-menu-lock-file" :recipe
             (:package "nord-theme" :fetcher github :repo
                       "nordtheme/emacs" :files
                       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                        "*.texinfo" "doc/dir" "doc/*.info"
                        "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                        "docs/dir" "docs/*.info" "docs/*.texi"
                        "docs/*.texinfo"
                        (:exclude ".dir-locals.el" "test.el"
                                  "tests.el" "*-test.el" "*-tests.el"
                                  "LICENSE" "README*" "*-pkg.el"))
                       :source "MELPA" :protocol https :inherit t
                       :depth treeless :ref
                       "551b2b8a0751c0a22e5c5daa6958152f208e668f"))
 (nov :source "elpaca-menu-lock-file" :recipe
      (:package "nov" :fetcher git :url
                "https://depp.brause.cc/nov.el.git" :files
                ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
                 "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
                 "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
                 "docs/*.texinfo"
                 (:exclude ".dir-locals.el" "test.el" "tests.el"
                           "*-test.el" "*-tests.el" "LICENSE"
                           "README*" "*-pkg.el"))
                :source "MELPA" :protocol https :inherit t :depth
                treeless :ref
                "874daf5e4791a6d4f47741422c80e2736e907351"))
 (numpydoc :source "elpaca-menu-lock-file" :recipe
           (:package "numpydoc" :fetcher github :repo
                     "douglasdavis/numpydoc.el" :files
                     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                      "doc/*.texinfo" "lisp/*.el" "docs/dir"
                      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                      (:exclude ".dir-locals.el" "test.el" "tests.el"
                                "*-test.el" "*-tests.el" "LICENSE"
                                "README*" "*-pkg.el"))
                     :source "MELPA" :protocol https :inherit t :depth
                     treeless :ref
                     "77e2893442c6e20af9c99b9ba2c6c11988fe0e80"))
 (nyan-mode :source "elpaca-menu-lock-file" :recipe
            (:package "nyan-mode" :fetcher github :repo
                      "TeMPOraL/nyan-mode" :files
                      ("nyan-mode.el" "img" "mus") :source "MELPA"
                      :protocol https :inherit t :depth treeless :ref
                      "09904af23adb839c6a9c1175349a1fb67f5b4370"))
 (ob-mermaid :source "elpaca-menu-lock-file" :recipe
             (:package "ob-mermaid" :repo "arnm/ob-mermaid" :fetcher
                       github :files
                       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                        "*.texinfo" "doc/dir" "doc/*.info"
                        "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                        "docs/dir" "docs/*.info" "docs/*.texi"
                        "docs/*.texinfo"
                        (:exclude ".dir-locals.el" "test.el"
                                  "tests.el" "*-test.el" "*-tests.el"
                                  "LICENSE" "README*" "*-pkg.el"))
                       :source "MELPA" :protocol https :inherit t
                       :depth treeless :ref
                       "4f814ad5e1b96764af52d53799288ff3acc94b47"))
 (olivetti :source "elpaca-menu-lock-file" :recipe
           (:package "olivetti" :fetcher github :repo "rnkn/olivetti"
                     :files
                     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                      "doc/*.texinfo" "lisp/*.el" "docs/dir"
                      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                      (:exclude ".dir-locals.el" "test.el" "tests.el"
                                "*-test.el" "*-tests.el" "LICENSE"
                                "README*" "*-pkg.el"))
                     :source "MELPA" :protocol https :inherit t :depth
                     treeless :ref
                     "845eb7a95a3ca3325f1120c654d761b91683f598"))
 (orderless :source "elpaca-menu-lock-file" :recipe
            (:package "orderless" :repo "oantolin/orderless" :fetcher
                      github :files
                      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                       "doc/*.texinfo" "lisp/*.el" "docs/dir"
                       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                       (:exclude ".dir-locals.el" "test.el" "tests.el"
                                 "*-test.el" "*-tests.el" "LICENSE"
                                 "README*" "*-pkg.el"))
                      :source "MELPA" :protocol https :inherit t
                      :depth treeless :ref
                      "3a2a32181f7a5bd7b633e40d89de771a5dd88cc7"))
 (org-jira :source "elpaca-menu-lock-file" :recipe
           (:package "org-jira" :fetcher github :repo
                     "ahungry/org-jira" :files
                     ("jiralib.el" "org-jira.el" "org-jira-sdk.el")
                     :source "MELPA" :protocol https :inherit t :depth
                     treeless :ref
                     "738002ddbeb0b4311089706f0a979ceea53bf095"))
 (org-mime :source "elpaca-menu-lock-file" :recipe
           (:package "org-mime" :repo "org-mime/org-mime" :fetcher
                     github :files
                     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                      "doc/*.texinfo" "lisp/*.el" "docs/dir"
                      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                      (:exclude ".dir-locals.el" "test.el" "tests.el"
                                "*-test.el" "*-tests.el" "LICENSE"
                                "README*" "*-pkg.el"))
                     :source "MELPA" :protocol https :inherit t :depth
                     treeless :ref
                     "ffaad784a8597ee52842a578c01bd347d3e0281d"))
 (org-noter :source "elpaca-menu-lock-file" :recipe
            (:package "org-noter" :fetcher github :repo
                      "org-noter/org-noter" :files
                      ("*.el" "modules"
                       (:exclude "*-test-utils.el" "*-devel.el"))
                      :source "MELPA" :protocol https :inherit t
                      :depth treeless :ref
                      "81765d267e51efd8b4f5b7276000332ba3eabbf5"))
 (org-ql :source "elpaca-menu-lock-file" :recipe
         (:package "org-ql" :fetcher github :repo "alphapapa/org-ql"
                   :files (:defaults (:exclude "helm-org-ql.el"))
                   :source "MELPA" :protocol https :inherit t :depth
                   treeless :ref
                   "4b8330a683c43bb4a2c64ccce8cd5a90c8b174ca"))
 (org-ref :source "elpaca-menu-lock-file" :recipe
          (:package "org-ref" :fetcher github :repo "jkitchin/org-ref"
                    :files
                    (:defaults "org-ref.org" "org-ref.bib" "citeproc")
                    :source "MELPA" :protocol https :inherit t :depth
                    treeless :ref
                    "dc2481d430906fe2552f9318f4405242e6d37396"))
 (org-remark :source "elpaca-menu-lock-file" :recipe
             (:package "org-remark" :repo
                       ("https://github.com/nobiot/org-remark"
                        . "org-remark")
                       :files ("*" (:exclude ".git")) :source
                       "GNU ELPA" :protocol https :inherit t :depth
                       treeless :ref
                       "4389853625f51ef9495ea4317979a73f942f1b00"))
 (org-super-agenda :source "elpaca-menu-lock-file" :recipe
                   (:package "org-super-agenda" :fetcher github :repo
                             "alphapapa/org-super-agenda" :files
                             ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                              "*.texinfo" "doc/dir" "doc/*.info"
                              "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                              "docs/dir" "docs/*.info" "docs/*.texi"
                              "docs/*.texinfo"
                              (:exclude ".dir-locals.el" "test.el"
                                        "tests.el" "*-test.el"
                                        "*-tests.el" "LICENSE"
                                        "README*" "*-pkg.el"))
                             :source "MELPA" :protocol https :inherit
                             t :depth treeless :ref
                             "fb20ad9c8a9705aa05d40751682beae2d094e0fe"))
 (org-transclusion :source "elpaca-menu-lock-file" :recipe
                   (:package "org-transclusion" :repo
                             ("https://github.com/nobiot/org-transclusion"
                              . "org-transclusion")
                             :files ("*" (:exclude ".git")) :source
                             "GNU ELPA" :protocol https :inherit t
                             :depth treeless :ref
                             "6bc151d8d7afe889ce512637771e1329ac67b51d"))
 (org-tree-slide :source "elpaca-menu-lock-file" :recipe
                 (:package "org-tree-slide" :fetcher github :repo
                           "takaxp/org-tree-slide" :files
                           ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                            "*.texinfo" "doc/dir" "doc/*.info"
                            "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                            "docs/dir" "docs/*.info" "docs/*.texi"
                            "docs/*.texinfo"
                            (:exclude ".dir-locals.el" "test.el"
                                      "tests.el" "*-test.el"
                                      "*-tests.el" "LICENSE" "README*"
                                      "*-pkg.el"))
                           :source "MELPA" :protocol https :inherit t
                           :depth treeless :ref
                           "e2599a106a26ce5511095e23df4ea04be6687a8a"))
 (org-web-tools :source "elpaca-menu-lock-file" :recipe
                (:package "org-web-tools" :fetcher github :repo
                          "alphapapa/org-web-tools" :files
                          ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                           "*.texinfo" "doc/dir" "doc/*.info"
                           "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                           "docs/dir" "docs/*.info" "docs/*.texi"
                           "docs/*.texinfo"
                           (:exclude ".dir-locals.el" "test.el"
                                     "tests.el" "*-test.el"
                                     "*-tests.el" "LICENSE" "README*"
                                     "*-pkg.el"))
                          :source "MELPA" :protocol https :inherit t
                          :depth treeless :ref
                          "7a6498f442fc7f29504745649948635c7165d847"))
 (origami :source "elpaca-menu-lock-file" :recipe
          (:package "origami" :fetcher github :repo
                    "gregsexton/origami.el" :files
                    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                     "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                     "doc/*.texinfo" "lisp/*.el" "docs/dir"
                     "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                     (:exclude ".dir-locals.el" "test.el" "tests.el"
                               "*-test.el" "*-tests.el" "LICENSE"
                               "README*" "*-pkg.el"))
                    :source "MELPA" :protocol https :inherit t :depth
                    treeless :ref
                    "e558710a975e8511b9386edc81cd6bdd0a5bda74"))
 (osx-lib :source "elpaca-menu-lock-file" :recipe
          (:package "osx-lib" :repo "raghavgautam/osx-lib" :fetcher
                    github :files
                    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                     "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                     "doc/*.texinfo" "lisp/*.el" "docs/dir"
                     "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                     (:exclude ".dir-locals.el" "test.el" "tests.el"
                               "*-test.el" "*-tests.el" "LICENSE"
                               "README*" "*-pkg.el"))
                    :source "MELPA" :protocol https :inherit t :depth
                    treeless :ref
                    "7afdb57edd5725e8a66f841a90fa571a4cbb81e7"))
 (ov :source "elpaca-menu-lock-file" :recipe
     (:package "ov" :fetcher github :repo "emacsorphanage/ov" :files
               ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
                "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
                "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
                "docs/*.texinfo"
                (:exclude ".dir-locals.el" "test.el" "tests.el"
                          "*-test.el" "*-tests.el" "LICENSE" "README*"
                          "*-pkg.el"))
               :source "MELPA" :protocol https :inherit t :depth
               treeless :ref
               "e2971ad986b6ac441e9849031d34c56c980cf40b"))
 (ox-gfm :source "elpaca-menu-lock-file" :recipe
         (:package "ox-gfm" :fetcher github :repo "larstvei/ox-gfm"
                   :files
                   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                    "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                    "doc/*.texinfo" "lisp/*.el" "docs/dir"
                    "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                    (:exclude ".dir-locals.el" "test.el" "tests.el"
                              "*-test.el" "*-tests.el" "LICENSE"
                              "README*" "*-pkg.el"))
                   :source "MELPA" :protocol https :inherit t :depth
                   treeless :ref
                   "4f774f13d34b3db9ea4ddb0b1edc070b1526ccbb"))
 (ox-jekyll-md :source "elpaca-menu-lock-file" :recipe
               (:package "ox-jekyll-md" :repo "gonsie/ox-jekyll-md"
                         :fetcher github :files
                         ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                          "*.texinfo" "doc/dir" "doc/*.info"
                          "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                          "docs/dir" "docs/*.info" "docs/*.texi"
                          "docs/*.texinfo"
                          (:exclude ".dir-locals.el" "test.el"
                                    "tests.el" "*-test.el"
                                    "*-tests.el" "LICENSE" "README*"
                                    "*-pkg.el"))
                         :source "MELPA" :protocol https :inherit t
                         :depth treeless :ref
                         "26edb3f4575bcb0f1a2aed56237cd89694284449"))
 (ox-pandoc :source "elpaca-menu-lock-file" :recipe
            (:package "ox-pandoc" :repo "emacsorphanage/ox-pandoc"
                      :fetcher github :files
                      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                       "doc/*.texinfo" "lisp/*.el" "docs/dir"
                       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                       (:exclude ".dir-locals.el" "test.el" "tests.el"
                                 "*-test.el" "*-tests.el" "LICENSE"
                                 "README*" "*-pkg.el"))
                      :source "MELPA" :protocol https :inherit t
                      :depth treeless :ref
                      "1caeb56a4be26597319e7288edbc2cabada151b4"))
 (ox-reveal :source "elpaca-menu-lock-file" :recipe
            (:package "ox-reveal" :repo "yjwen/org-reveal" :fetcher
                      github :old-names (org-reveal) :files
                      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                       "doc/*.texinfo" "lisp/*.el" "docs/dir"
                       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                       (:exclude ".dir-locals.el" "test.el" "tests.el"
                                 "*-test.el" "*-tests.el" "LICENSE"
                                 "README*" "*-pkg.el"))
                      :source "MELPA" :protocol https :inherit t
                      :depth treeless :ref
                      "f55c851bf6aeb1bb2a7f6cf0f2b7bd0e79c4a5a0"))
 (parrot :source "elpaca-menu-lock-file" :recipe
         (:package "parrot" :fetcher github :repo
                   "positron-solutions/parrot" :files
                   (:defaults "img") :source "MELPA" :protocol https
                   :inherit t :depth treeless :type git :host github
                   :ref "a612b302887be92ba95606c41ac3f7e75aadb33e"))
 (parsebib :source "elpaca-menu-lock-file" :recipe
           (:package "parsebib" :fetcher github :repo
                     "joostkremers/parsebib" :files
                     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                      "doc/*.texinfo" "lisp/*.el" "docs/dir"
                      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                      (:exclude ".dir-locals.el" "test.el" "tests.el"
                                "*-test.el" "*-tests.el" "LICENSE"
                                "README*" "*-pkg.el"))
                     :source "MELPA" :protocol https :inherit t :depth
                     treeless :ref
                     "5b837e0a5b91a69cc0e5086d8e4a71d6d86dac93"))
 (pcache :source "elpaca-menu-lock-file" :recipe
         (:package "pcache" :repo "sigma/pcache" :fetcher github
                   :files
                   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                    "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                    "doc/*.texinfo" "lisp/*.el" "docs/dir"
                    "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                    (:exclude ".dir-locals.el" "test.el" "tests.el"
                              "*-test.el" "*-tests.el" "LICENSE"
                              "README*" "*-pkg.el"))
                   :source "MELPA" :protocol https :inherit t :depth
                   treeless :ref
                   "e287b5d116679f79789ee9ee22ee213dc6cef68c"))
 (pdf-tools :source "elpaca-menu-lock-file" :recipe
            (:package "pdf-tools" :fetcher github :repo
                      "vedang/pdf-tools" :files
                      (:defaults "README" ("build" "Makefile")
                                 ("build" "server"))
                      :source "MELPA" :protocol https :inherit t
                      :depth treeless :ref
                      "365f88238f46f9b1425685562105881800f10386"))
 (persist :source "elpaca-menu-lock-file" :recipe
          (:package "persist" :repo
                    ("https://github.com/emacsmirror/gnu_elpa"
                     . "persist")
                    :branch "externals/persist" :files
                    ("*" (:exclude ".git")) :source "GNU ELPA"
                    :protocol https :inherit t :depth treeless :ref
                    "3b4b421d5185f2c33bae478aa057dff13701cc25"))
 (persistent-soft :source "elpaca-menu-lock-file" :recipe
                  (:package "persistent-soft" :repo
                            "rolandwalker/persistent-soft" :fetcher
                            github :files
                            ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                             "*.texinfo" "doc/dir" "doc/*.info"
                             "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                             "docs/dir" "docs/*.info" "docs/*.texi"
                             "docs/*.texinfo"
                             (:exclude ".dir-locals.el" "test.el"
                                       "tests.el" "*-test.el"
                                       "*-tests.el" "LICENSE"
                                       "README*" "*-pkg.el"))
                            :source "MELPA" :protocol https :inherit t
                            :depth treeless :ref
                            "c94b34332529df573bad8a97f70f5a35d5da7333"))
 (pfuture :source "elpaca-menu-lock-file" :recipe
          (:package "pfuture" :repo "Alexander-Miller/pfuture"
                    :fetcher github :files
                    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                     "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                     "doc/*.texinfo" "lisp/*.el" "docs/dir"
                     "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                     (:exclude ".dir-locals.el" "test.el" "tests.el"
                               "*-test.el" "*-tests.el" "LICENSE"
                               "README*" "*-pkg.el"))
                    :source "MELPA" :protocol https :inherit t :depth
                    treeless :ref
                    "19b53aebbc0f2da31de6326c495038901bffb73c"))
 (plz :source "elpaca-menu-lock-file"
   :recipe
   (:package "plz" :repo
             ("https://github.com/alphapapa/plz.el.git" . "plz")
             :files ("*" (:exclude ".git" "LICENSE")) :source
             "GNU ELPA" :protocol https :inherit t :depth treeless
             :ref "e2d07838e3b64ee5ebe59d4c3c9011adefb7b58e"))
 (pocket-lib :source "elpaca-menu-lock-file" :recipe
             (:package "pocket-lib" :fetcher github :repo
                       "alphapapa/pocket-lib.el" :files
                       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                        "*.texinfo" "doc/dir" "doc/*.info"
                        "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                        "docs/dir" "docs/*.info" "docs/*.texi"
                        "docs/*.texinfo"
                        (:exclude ".dir-locals.el" "test.el"
                                  "tests.el" "*-test.el" "*-tests.el"
                                  "LICENSE" "README*" "*-pkg.el"))
                       :source "MELPA" :protocol https :inherit t
                       :depth treeless :ref
                       "f05f80645d8101518eed13b2da81400fe9b50918"))
 (pocket-reader :source "elpaca-menu-lock-file" :recipe
                (:package "pocket-reader" :fetcher github :repo
                          "alphapapa/pocket-reader.el" :files
                          ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                           "*.texinfo" "doc/dir" "doc/*.info"
                           "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                           "docs/dir" "docs/*.info" "docs/*.texi"
                           "docs/*.texinfo"
                           (:exclude ".dir-locals.el" "test.el"
                                     "tests.el" "*-test.el"
                                     "*-tests.el" "LICENSE" "README*"
                                     "*-pkg.el"))
                          :source "MELPA" :protocol https :inherit t
                          :depth treeless :ref
                          "d507c376f0edaee475466e4ecdcead4d4184e5aa"))
 (poet-theme :source "elpaca-menu-lock-file" :recipe
             (:package "poet-theme" :fetcher github :repo
                       "kunalb/poet" :files
                       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                        "*.texinfo" "doc/dir" "doc/*.info"
                        "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                        "docs/dir" "docs/*.info" "docs/*.texi"
                        "docs/*.texinfo"
                        (:exclude ".dir-locals.el" "test.el"
                                  "tests.el" "*-test.el" "*-tests.el"
                                  "LICENSE" "README*" "*-pkg.el"))
                       :source "MELPA" :protocol https :inherit t
                       :depth treeless :ref
                       "16eb694f0755c04c4db98614d0eca1199fddad70"))
 (poetry :source "elpaca-menu-lock-file" :recipe
         (:package "poetry" :fetcher github :repo "cybniv/poetry.el"
                   :files
                   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                    "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                    "doc/*.texinfo" "lisp/*.el" "docs/dir"
                    "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                    (:exclude ".dir-locals.el" "test.el" "tests.el"
                              "*-test.el" "*-tests.el" "LICENSE"
                              "README*" "*-pkg.el"))
                   :source "MELPA" :protocol https :inherit t :depth
                   treeless :ref
                   "1dff0d4a51ea8aff5f6ce97b154ea799902639ad"))
 (polymode :source "elpaca-menu-lock-file" :recipe
           (:package "polymode" :fetcher github :repo
                     "polymode/polymode" :files
                     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                      "doc/*.texinfo" "lisp/*.el" "docs/dir"
                      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                      (:exclude ".dir-locals.el" "test.el" "tests.el"
                                "*-test.el" "*-tests.el" "LICENSE"
                                "README*" "*-pkg.el"))
                     :source "MELPA" :protocol https :inherit t :depth
                     treeless :ref
                     "14b1fd8d2a183f11b123f62e02801dc1139da9c1"))
 (popper :source "elpaca-menu-lock-file" :recipe
         (:package "popper" :fetcher github :repo "karthink/popper"
                   :files
                   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                    "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                    "doc/*.texinfo" "lisp/*.el" "docs/dir"
                    "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                    (:exclude ".dir-locals.el" "test.el" "tests.el"
                              "*-test.el" "*-tests.el" "LICENSE"
                              "README*" "*-pkg.el"))
                   :source "MELPA" :protocol https :inherit t :depth
                   treeless :ref
                   "49f4904480cf4ca5c6db83fcfa9e6ea8d4567d96"))
 (posframe :source "elpaca-menu-lock-file" :recipe
           (:package "posframe" :fetcher github :repo
                     "tumashu/posframe" :files
                     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                      "doc/*.texinfo" "lisp/*.el" "docs/dir"
                      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                      (:exclude ".dir-locals.el" "test.el" "tests.el"
                                "*-test.el" "*-tests.el" "LICENSE"
                                "README*" "*-pkg.el"))
                     :source "MELPA" :protocol https :inherit t :depth
                     treeless :ref
                     "41cc4def6190f100ba50dca51457c38f4f90dfb1"))
 (pr-review :source "elpaca-menu-lock-file" :recipe
            (:package "pr-review" :fetcher github :repo
                      "blahgeek/emacs-pr-review" :files
                      (:defaults "graphql") :source "MELPA" :protocol
                      https :inherit t :depth treeless :ref
                      "d893429168b87003a99bf567932dce57fdac93fa"))
 (prescient :source "elpaca-menu-lock-file" :recipe
            (:package "prescient" :fetcher github :repo
                      "radian-software/prescient.el" :files
                      ("prescient.el" "corfu-prescient.el"
                       "vertico-prescient.el")
                      :source "MELPA" :protocol https :inherit t
                      :depth treeless :ref
                      "87e2d2f2ddf24f591a5f70cc90d2afb4537caa18"))
 (pretty-hydra :source "elpaca-menu-lock-file" :recipe
               (:package "pretty-hydra" :repo
                         "jerrypnz/major-mode-hydra.el" :fetcher
                         github :files ("pretty-hydra.el") :source
                         "MELPA" :protocol https :inherit t :depth
                         treeless :ref
                         "2494d71e24b61c1f5ef2dc17885e2f65bf98b3b2"))
 (projection :source "elpaca-menu-lock-file" :recipe
             (:package "projection" :fetcher github :repo
                       "mohkale/projection" :files
                       (:defaults "src/*.el"
                                  "src/projection-multi/*.el"
                                  "src/projection-multi-embark/*.el")
                       :source "MELPA" :protocol https :inherit t
                       :depth treeless :ref
                       "482789397c5e11dbb95438c87ccd0cad3d37a33a"))
 (pubmed :source "elpaca-menu-lock-file" :recipe
         (:package "pubmed" :fetcher gitlab :repo
                   "fvdbeek/emacs-pubmed" :files
                   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                    "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                    "doc/*.texinfo" "lisp/*.el" "docs/dir"
                    "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                    (:exclude ".dir-locals.el" "test.el" "tests.el"
                              "*-test.el" "*-tests.el" "LICENSE"
                              "README*" "*-pkg.el"))
                   :source "MELPA" :protocol https :inherit t :depth
                   treeless :host gitlab :ref
                   "b2fbc124cabf0d373845763adf882e9d89ff5daa"))
 (python-pytest :source "elpaca-menu-lock-file" :recipe
                (:package "python-pytest" :fetcher github :repo
                          "wbolster/emacs-python-pytest" :files
                          ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                           "*.texinfo" "doc/dir" "doc/*.info"
                           "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                           "docs/dir" "docs/*.info" "docs/*.texi"
                           "docs/*.texinfo"
                           (:exclude ".dir-locals.el" "test.el"
                                     "tests.el" "*-test.el"
                                     "*-tests.el" "LICENSE" "README*"
                                     "*-pkg.el"))
                          :source "MELPA" :protocol https :inherit t
                          :depth treeless :ref
                          "78b5ea1d19c7e365ac00649d13c733954b11f822"))
 (pyvenv :source "elpaca-menu-lock-file" :recipe
         (:package "pyvenv" :fetcher github :repo
                   "jorgenschaefer/pyvenv" :files
                   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                    "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                    "doc/*.texinfo" "lisp/*.el" "docs/dir"
                    "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                    (:exclude ".dir-locals.el" "test.el" "tests.el"
                              "*-test.el" "*-tests.el" "LICENSE"
                              "README*" "*-pkg.el"))
                   :source "MELPA" :protocol https :inherit t :depth
                   treeless :ref
                   "31ea715f2164dd611e7fc77b26390ef3ca93509b"))
 (queue :source "elpaca-menu-lock-file" :recipe
        (:package "queue" :repo
                  ("https://github.com/emacsmirror/gnu_elpa" . "queue")
                  :branch "externals/queue" :files
                  ("*" (:exclude ".git")) :source "GNU ELPA" :protocol
                  https :inherit t :depth treeless :ref
                  "f986fb68e75bdae951efb9e11a3012ab6bd408ee"))
 (rainbow-delimiters :source "elpaca-menu-lock-file" :recipe
                     (:package "rainbow-delimiters" :fetcher github
                               :repo "Fanael/rainbow-delimiters"
                               :files
                               ("*.el" "*.el.in" "dir" "*.info"
                                "*.texi" "*.texinfo" "doc/dir"
                                "doc/*.info" "doc/*.texi"
                                "doc/*.texinfo" "lisp/*.el" "docs/dir"
                                "docs/*.info" "docs/*.texi"
                                "docs/*.texinfo"
                                (:exclude ".dir-locals.el" "test.el"
                                          "tests.el" "*-test.el"
                                          "*-tests.el" "LICENSE"
                                          "README*" "*-pkg.el"))
                               :source "MELPA" :protocol https
                               :inherit t :depth treeless :ref
                               "f40ece58df8b2f0fb6c8576b527755a552a5e763"))
 (rainbow-mode :source "elpaca-menu-lock-file" :recipe
               (:package "rainbow-mode" :repo
                         ("https://github.com/emacsmirror/gnu_elpa"
                          . "rainbow-mode")
                         :branch "externals/rainbow-mode" :files
                         ("*" (:exclude ".git")) :source "GNU ELPA"
                         :protocol https :inherit t :depth treeless
                         :ref
                         "f7db3b5919f70420a91eb199f8663468de3033f3"))
 (rebecca-theme :source "elpaca-menu-lock-file" :recipe
                (:package "rebecca-theme" :fetcher github :repo
                          "vic/rebecca-theme" :files
                          ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                           "*.texinfo" "doc/dir" "doc/*.info"
                           "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                           "docs/dir" "docs/*.info" "docs/*.texi"
                           "docs/*.texinfo"
                           (:exclude ".dir-locals.el" "test.el"
                                     "tests.el" "*-test.el"
                                     "*-tests.el" "LICENSE" "README*"
                                     "*-pkg.el"))
                          :source "MELPA" :protocol https :inherit t
                          :depth treeless :ref
                          "feca16a9387247d8a1a0f5069148150cd1d9e258"))
 (recursion-indicator :source "elpaca-menu-lock-file" :recipe
                      (:package "recursion-indicator" :repo
                                "minad/recursion-indicator" :fetcher
                                github :files
                                ("*.el" "*.el.in" "dir" "*.info"
                                 "*.texi" "*.texinfo" "doc/dir"
                                 "doc/*.info" "doc/*.texi"
                                 "doc/*.texinfo" "lisp/*.el"
                                 "docs/dir" "docs/*.info"
                                 "docs/*.texi" "docs/*.texinfo"
                                 (:exclude ".dir-locals.el" "test.el"
                                           "tests.el" "*-test.el"
                                           "*-tests.el" "LICENSE"
                                           "README*" "*-pkg.el"))
                                :source "MELPA" :protocol https
                                :inherit t :depth treeless :ref
                                "0f5fc36ea6c1312708b00ee3ac9817511150fc0b"))
 (repeatable-lite :source "elpaca-menu-lock-file" :recipe
                  (:source nil :protocol https :inherit t :depth
                           treeless :host github :repo
                           "chiply/repeatable-lite" :wait t :package
                           "repeatable-lite" :ref
                           "3250f6e42f4870f7581a1975504a2e33c9628ddc"))
 (request :source "elpaca-menu-lock-file"
   :recipe
   (:package "request" :repo "tkf/emacs-request" :fetcher github
             :files ("request.el") :source "MELPA" :protocol https
             :inherit t :depth treeless :ref
             "c22e3c23a6dd90f64be536e176ea0ed6113a5ba6"))
 (rjsx-mode :source "elpaca-menu-lock-file" :recipe
            (:package "rjsx-mode" :fetcher github :repo
                      "felipeochoa/rjsx-mode" :files
                      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                       "doc/*.texinfo" "lisp/*.el" "docs/dir"
                       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                       (:exclude ".dir-locals.el" "test.el" "tests.el"
                                 "*-test.el" "*-tests.el" "LICENSE"
                                 "README*" "*-pkg.el"))
                      :source "MELPA" :protocol https :inherit t
                      :depth treeless :ref
                      "b697fe4d92cc84fa99a7bcb476f815935ea0d919"))
 (s :source "elpaca-menu-lock-file" :recipe
    (:package "s" :fetcher github :repo "magnars/s.el" :files
              ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
               "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
               "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
               "docs/*.texinfo"
               (:exclude ".dir-locals.el" "test.el" "tests.el"
                         "*-test.el" "*-tests.el" "LICENSE" "README*"
                         "*-pkg.el"))
              :source "MELPA" :protocol https :inherit t :depth
              treeless :ref "dda84d38fffdaf0c9b12837b504b402af910d01d"))
 (shell-maker :source "elpaca-menu-lock-file" :recipe
              (:package "shell-maker" :fetcher github :repo
                        "xenodium/shell-maker" :files
                        ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                         "*.texinfo" "doc/dir" "doc/*.info"
                         "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                         "docs/dir" "docs/*.info" "docs/*.texi"
                         "docs/*.texinfo"
                         (:exclude ".dir-locals.el" "test.el"
                                   "tests.el" "*-test.el" "*-tests.el"
                                   "LICENSE" "README*" "*-pkg.el"))
                        :source "MELPA" :protocol https :inherit t
                        :depth treeless :ref
                        "72710cc9907b83876c47fc06c45795c3fd842d25"))
 (smartparens :source "elpaca-menu-lock-file" :recipe
              (:package "smartparens" :fetcher github :repo
                        "Fuco1/smartparens" :files
                        ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                         "*.texinfo" "doc/dir" "doc/*.info"
                         "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                         "docs/dir" "docs/*.info" "docs/*.texi"
                         "docs/*.texinfo"
                         (:exclude ".dir-locals.el" "test.el"
                                   "tests.el" "*-test.el" "*-tests.el"
                                   "LICENSE" "README*" "*-pkg.el"))
                        :source "MELPA" :protocol https :inherit t
                        :depth treeless :ref
                        "82d2cf084a19b0c2c3812e0550721f8a61996056"))
 (space-tree :source "elpaca-menu-lock-file" :recipe
             (:source nil :protocol https :inherit t :depth treeless
                      :host github :repo "chiply/space-tree" :package
                      "space-tree" :ref
                      "1c9d95a02a2b94304a6c525142109f5768f00b88"))
 (speed-type :source "elpaca-menu-lock-file" :recipe
             (:package "speed-type" :fetcher github :repo
                       "dakra/speed-type" :files
                       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                        "*.texinfo" "doc/dir" "doc/*.info"
                        "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                        "docs/dir" "docs/*.info" "docs/*.texi"
                        "docs/*.texinfo"
                        (:exclude ".dir-locals.el" "test.el"
                                  "tests.el" "*-test.el" "*-tests.el"
                                  "LICENSE" "README*" "*-pkg.el"))
                       :source "MELPA" :protocol https :inherit t
                       :depth treeless :ref
                       "e27ebe21cf498ffd1718a18a77baa385c0bcca12"))
 (spinner :source "elpaca-menu-lock-file" :recipe
          (:package "spinner" :repo
                    ("https://github.com/Malabarba/spinner.el"
                     . "spinner")
                    :files ("*" (:exclude ".git")) :source "GNU ELPA"
                    :protocol https :inherit t :depth treeless :ref
                    "d4647ae87fb0cd24bc9081a3d287c860ff061c21"))
 (spot :source "elpaca-menu-lock-file" :recipe
       (:source nil :protocol https :inherit t :depth treeless :host
                github :repo "chiply/spot" :package "spot" :ref
                "aba41c5adee55812ffdca3f3fe7435723f0aa1b2"))
 (spotlight :source "elpaca-menu-lock-file" :recipe
            (:package "spotlight" :repo "benmaughan/spotlight.el"
                      :fetcher github :files
                      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                       "doc/*.texinfo" "lisp/*.el" "docs/dir"
                       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                       (:exclude ".dir-locals.el" "test.el" "tests.el"
                                 "*-test.el" "*-tests.el" "LICENSE"
                                 "README*" "*-pkg.el"))
                      :source "MELPA" :protocol https :inherit t
                      :depth treeless :ref
                      "ea71f4fd380c51e50c47bb25855af4f40e4d8da0"))
 (spray :source "elpaca-menu-lock-file" :recipe
        (:package "spray" :fetcher sourcehut :repo "emacsmirror/spray"
                  :files
                  ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                   "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                   "doc/*.texinfo" "lisp/*.el" "docs/dir"
                   "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                   (:exclude ".dir-locals.el" "test.el" "tests.el"
                             "*-test.el" "*-tests.el" "LICENSE"
                             "README*" "*-pkg.el"))
                  :source "MELPA" :protocol https :inherit t :depth
                  treeless :type git :host github :ref
                  "74d9dcfa2e8b38f96a43de9ab0eb13364300cb46"))
 (sql-indent :source "elpaca-menu-lock-file" :recipe
             (:package "sql-indent" :repo
                       ("https://github.com/alex-hhh/emacs-sql-indent"
                        . "sql-indent")
                       :files ("*" (:exclude ".git")) :source
                       "GNU ELPA" :protocol https :inherit t :depth
                       treeless :ref
                       "2ed4c6a26b8f3d651ac6231eaafb2565d77c918b"))
 (sqlup-mode :source "elpaca-menu-lock-file" :recipe
             (:package "sqlup-mode" :fetcher github :repo
                       "Trevoke/sqlup-mode.el" :files
                       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                        "*.texinfo" "doc/dir" "doc/*.info"
                        "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                        "docs/dir" "docs/*.info" "docs/*.texi"
                        "docs/*.texinfo"
                        (:exclude ".dir-locals.el" "test.el"
                                  "tests.el" "*-test.el" "*-tests.el"
                                  "LICENSE" "README*" "*-pkg.el"))
                       :source "MELPA" :protocol https :inherit t
                       :depth treeless :ref
                       "3f9df9c88d6a7f9b1ae907e401cad8d3d7d63bbf"))
 (string-inflection :source "elpaca-menu-lock-file" :recipe
                    (:package "string-inflection" :fetcher github
                              :repo "akicho8/string-inflection" :files
                              ("*.el" "*.el.in" "dir" "*.info"
                               "*.texi" "*.texinfo" "doc/dir"
                               "doc/*.info" "doc/*.texi"
                               "doc/*.texinfo" "lisp/*.el" "docs/dir"
                               "docs/*.info" "docs/*.texi"
                               "docs/*.texinfo"
                               (:exclude ".dir-locals.el" "test.el"
                                         "tests.el" "*-test.el"
                                         "*-tests.el" "LICENSE"
                                         "README*" "*-pkg.el"))
                              :source "MELPA" :protocol https :inherit
                              t :depth treeless :ref
                              "4a2f87d7b47f5efe702a78f8a40a98df36eeba13"))
 (super-save :source "elpaca-menu-lock-file" :recipe
             (:package "super-save" :fetcher github :repo
                       "bbatsov/super-save" :files
                       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                        "*.texinfo" "doc/dir" "doc/*.info"
                        "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                        "docs/dir" "docs/*.info" "docs/*.texi"
                        "docs/*.texinfo"
                        (:exclude ".dir-locals.el" "test.el"
                                  "tests.el" "*-test.el" "*-tests.el"
                                  "LICENSE" "README*" "*-pkg.el"))
                       :source "MELPA" :protocol https :inherit t
                       :depth treeless :ref
                       "b612da0b37859a23375366b725b1ab7e7fea02fd"))
 (svelte-mode :source "elpaca-menu-lock-file" :recipe
              (:package "svelte-mode" :fetcher github :repo
                        "leafOfTree/svelte-mode" :files
                        ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                         "*.texinfo" "doc/dir" "doc/*.info"
                         "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                         "docs/dir" "docs/*.info" "docs/*.texi"
                         "docs/*.texinfo"
                         (:exclude ".dir-locals.el" "test.el"
                                   "tests.el" "*-test.el" "*-tests.el"
                                   "LICENSE" "README*" "*-pkg.el"))
                        :source "MELPA" :protocol https :inherit t
                        :depth treeless :ref
                        "ac8fba901dc790976f9893e338c8ad1241b897c6"))
 (svg-lib :source "elpaca-menu-lock-file" :recipe
          (:package "svg-lib" :repo
                    ("https://github.com/rougier/svg-lib" . "svg-lib")
                    :files ("*" (:exclude ".git")) :source "GNU ELPA"
                    :protocol https :inherit t :depth treeless :ref
                    "925ed4a0215c197ba836e7810a93905b34bea777"))
 (swiper :source "elpaca-menu-lock-file" :recipe
         (:package "swiper" :repo "abo-abo/swiper" :fetcher github
                   :files ("swiper.el") :source "MELPA" :protocol
                   https :inherit t :depth treeless :ref
                   "ee79f68215ae7e2b8a38ba6bf7f82b3fe57dc16c"))
 (sx :source "elpaca-menu-lock-file" :recipe
     (:package "sx" :repo "vermiculus/sx.el" :fetcher github :files
               ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
                "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
                "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
                "docs/*.texinfo"
                (:exclude ".dir-locals.el" "test.el" "tests.el"
                          "*-test.el" "*-tests.el" "LICENSE" "README*"
                          "*-pkg.el"))
               :source "MELPA" :protocol https :inherit t :depth
               treeless :ref
               "8c1c28f33d714fc8869e49f5642e1a585c8c85af"))
 (symbol-overlay :source "elpaca-menu-lock-file" :recipe
                 (:package "symbol-overlay" :fetcher github :repo
                           "wolray/symbol-overlay" :files
                           ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                            "*.texinfo" "doc/dir" "doc/*.info"
                            "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                            "docs/dir" "docs/*.info" "docs/*.texi"
                            "docs/*.texinfo"
                            (:exclude ".dir-locals.el" "test.el"
                                      "tests.el" "*-test.el"
                                      "*-tests.el" "LICENSE" "README*"
                                      "*-pkg.el"))
                           :source "MELPA" :protocol https :inherit t
                           :depth treeless :ref
                           "6151f4279bd94b5960149596b202cdcb45cacec2"))
 (tablist :source "elpaca-menu-lock-file" :recipe
          (:package "tablist" :fetcher github :repo
                    "emacsorphanage/tablist" :files
                    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                     "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                     "doc/*.texinfo" "lisp/*.el" "docs/dir"
                     "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                     (:exclude ".dir-locals.el" "test.el" "tests.el"
                               "*-test.el" "*-tests.el" "LICENSE"
                               "README*" "*-pkg.el"))
                    :source "MELPA" :protocol https :inherit t :depth
                    treeless :ref
                    "fcd37147121fabdf003a70279cf86fbe08cfac6f"))
 (telephone-line :source "elpaca-menu-lock-file" :recipe
                 (:package "telephone-line" :repo
                           "dbordak/telephone-line" :fetcher github
                           :files
                           ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                            "*.texinfo" "doc/dir" "doc/*.info"
                            "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                            "docs/dir" "docs/*.info" "docs/*.texi"
                            "docs/*.texinfo"
                            (:exclude ".dir-locals.el" "test.el"
                                      "tests.el" "*-test.el"
                                      "*-tests.el" "LICENSE" "README*"
                                      "*-pkg.el"))
                           :source "MELPA" :protocol https :inherit t
                           :depth treeless :ref
                           "6016418a5e1e8e006cc202eff50ff28b594eeca4"))
 (tempel :source "elpaca-menu-lock-file" :recipe
         (:package "tempel" :repo "minad/tempel" :fetcher github
                   :files
                   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                    "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                    "doc/*.texinfo" "lisp/*.el" "docs/dir"
                    "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                    (:exclude ".dir-locals.el" "test.el" "tests.el"
                              "*-test.el" "*-tests.el" "LICENSE"
                              "README*" "*-pkg.el"))
                   :source "MELPA" :protocol https :inherit t :depth
                   treeless :ref
                   "7120539bf047d3748636a7299fd7bca62ab2c74a"))
 (tempel-collection :source "elpaca-menu-lock-file" :recipe
                    (:package "tempel-collection" :repo
                              "Crandel/tempel-collection" :fetcher
                              github :files (:defaults "templates")
                              :source "MELPA" :protocol https :inherit
                              t :depth treeless :ref
                              "6292604c1d5ed0044ce0beb2d46c73697dc66ed3"))
 (templatel :source "elpaca-menu-lock-file" :recipe
            (:package "templatel" :fetcher github :repo
                      "emacs-love/templatel" :files
                      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                       "doc/*.texinfo" "lisp/*.el" "docs/dir"
                       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                       (:exclude ".dir-locals.el" "test.el" "tests.el"
                                 "*-test.el" "*-tests.el" "LICENSE"
                                 "README*" "*-pkg.el"))
                      :source "MELPA" :protocol https :inherit t
                      :depth treeless :ref
                      "1c806f9259d0c22aabfcf4288c3bdc0c5e1d301f"))
 (terraform-mode :source "elpaca-menu-lock-file" :recipe
                 (:package "terraform-mode" :repo
                           "hcl-emacs/terraform-mode" :fetcher github
                           :files
                           ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                            "*.texinfo" "doc/dir" "doc/*.info"
                            "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                            "docs/dir" "docs/*.info" "docs/*.texi"
                            "docs/*.texinfo"
                            (:exclude ".dir-locals.el" "test.el"
                                      "tests.el" "*-test.el"
                                      "*-tests.el" "LICENSE" "README*"
                                      "*-pkg.el"))
                           :source "MELPA" :protocol https :inherit t
                           :depth treeless :ref
                           "01635df3625c0cec2bb4613a6f920b8569d41009"))
 (tokei :source "elpaca-menu-lock-file" :recipe
        (:package "tokei" :repo "nagy/tokei.el" :fetcher github :files
                  ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                   "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                   "doc/*.texinfo" "lisp/*.el" "docs/dir"
                   "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                   (:exclude ".dir-locals.el" "test.el" "tests.el"
                             "*-test.el" "*-tests.el" "LICENSE"
                             "README*" "*-pkg.el"))
                  :source "MELPA" :protocol https :inherit t :depth
                  treeless :ref
                  "abfef55c00b49bccd97484d11fab93c6ffce7560"))
 (touchtype :source "elpaca-menu-lock-file" :recipe
            (:source nil :protocol https :inherit t :depth treeless
                     :host github :repo "chiply/touchtype" :package
                     "touchtype" :ref
                     "41553e9f9fbb040fd9dec61976efc8f70f78abcd"))
 (tp :source "elpaca-menu-lock-file" :recipe
     (:package "tp" :fetcher codeberg :repo "martianh/tp.el" :files
               ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
                "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
                "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
                "docs/*.texinfo"
                (:exclude ".dir-locals.el" "test.el" "tests.el"
                          "*-test.el" "*-tests.el" "LICENSE" "README*"
                          "*-pkg.el"))
               :source "MELPA" :protocol https :inherit t :depth
               treeless :ref
               "cef3fc2daefbbfc29ad02b7e1f39542b57c72fe8"))
 (trailing-newline-indicator :source "elpaca-menu-lock-file" :recipe
                             (:package "trailing-newline-indicator"
                                       :fetcher github :repo
                                       "saulotoledo/trailing-newline-indicator"
                                       :files
                                       ("*.el" "*.el.in" "dir"
                                        "*.info" "*.texi" "*.texinfo"
                                        "doc/dir" "doc/*.info"
                                        "doc/*.texi" "doc/*.texinfo"
                                        "lisp/*.el" "docs/dir"
                                        "docs/*.info" "docs/*.texi"
                                        "docs/*.texinfo"
                                        (:exclude ".dir-locals.el"
                                                  "test.el" "tests.el"
                                                  "*-test.el"
                                                  "*-tests.el"
                                                  "LICENSE" "README*"
                                                  "*-pkg.el"))
                                       :source "MELPA" :protocol https
                                       :inherit t :depth treeless
                                       :host github :ref
                                       "4513a8dd691587b090fbd1f67e5434f300017ef7"))
 (transient :source "elpaca-menu-lock-file" :recipe
            (:package "transient" :fetcher github :repo
                      "magit/transient" :files
                      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                       "doc/*.texinfo" "lisp/*.el" "docs/dir"
                       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                       (:exclude ".dir-locals.el" "test.el" "tests.el"
                                 "*-test.el" "*-tests.el" "LICENSE"
                                 "README*" "*-pkg.el"))
                      :source "MELPA" :protocol https :inherit t
                      :depth treeless :ref
                      "7637fd025d2f7f34ec83db2180ae50a8e4ef5ed8"))
 (tree-mode :source "elpaca-menu-lock-file" :recipe
            (:package "tree-mode" :fetcher github :repo
                      "emacsorphanage/tree-mode" :files
                      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                       "doc/*.texinfo" "lisp/*.el" "docs/dir"
                       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                       (:exclude ".dir-locals.el" "test.el" "tests.el"
                                 "*-test.el" "*-tests.el" "LICENSE"
                                 "README*" "*-pkg.el"))
                      :source "MELPA" :protocol https :inherit t
                      :depth treeless :ref
                      "b06078826d5875d74b0e7b7ac47b0d0917610534"))
 (treemacs :source "elpaca-menu-lock-file" :recipe
           (:package "treemacs" :fetcher github :repo
                     "Alexander-Miller/treemacs" :files
                     ("src/elisp/*.el" "src/extra/*.el") :source
                     "MELPA" :protocol https :inherit t :depth
                     treeless :ref
                     "2ab5a3c89fa01bbbd99de9b8986908b2bc5a7b49"))
 (treepy :source "elpaca-menu-lock-file" :recipe
         (:package "treepy" :repo "volrath/treepy.el" :fetcher github
                   :files
                   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                    "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                    "doc/*.texinfo" "lisp/*.el" "docs/dir"
                    "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                    (:exclude ".dir-locals.el" "test.el" "tests.el"
                              "*-test.el" "*-tests.el" "LICENSE"
                              "README*" "*-pkg.el"))
                   :source "MELPA" :protocol https :inherit t :depth
                   treeless :ref
                   "651e2634f01f346da9ec8a64613c51f54b444bc3"))
 (treesit-fold :source "elpaca-menu-lock-file" :recipe
               (:package "treesit-fold" :repo
                         ("https://github.com/emacs-tree-sitter/treesit-fold"
                          . "treesit-fold")
                         :files ("*" (:exclude ".git")) :source
                         "NonGNU ELPA" :protocol https :inherit t
                         :depth treeless :ref
                         "d70c5f7240a8a48819421260c9a018c884a41111"))
 (ts :source "elpaca-menu-lock-file" :recipe
     (:package "ts" :fetcher github :repo "alphapapa/ts.el" :files
               ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
                "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
                "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
                "docs/*.texinfo"
                (:exclude ".dir-locals.el" "test.el" "tests.el"
                          "*-test.el" "*-tests.el" "LICENSE" "README*"
                          "*-pkg.el"))
               :source "MELPA" :protocol https :inherit t :depth
               treeless :ref
               "552936017cfdec89f7fc20c254ae6b37c3f22c5b"))
 (typescript-mode :source "elpaca-menu-lock-file" :recipe
                  (:package "typescript-mode" :fetcher github :repo
                            "emacs-typescript/typescript.el" :files
                            ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                             "*.texinfo" "doc/dir" "doc/*.info"
                             "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                             "docs/dir" "docs/*.info" "docs/*.texi"
                             "docs/*.texinfo"
                             (:exclude ".dir-locals.el" "test.el"
                                       "tests.el" "*-test.el"
                                       "*-tests.el" "LICENSE"
                                       "README*" "*-pkg.el"))
                            :source "MELPA" :protocol https :inherit t
                            :depth treeless :ref
                            "2535780bdb318d86761b9bd21b0347ca6a89628f"))
 (ucs-utils :source "elpaca-menu-lock-file" :recipe
            (:package "ucs-utils" :repo "rolandwalker/ucs-utils"
                      :fetcher github :files
                      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                       "doc/*.texinfo" "lisp/*.el" "docs/dir"
                       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                       (:exclude ".dir-locals.el" "test.el" "tests.el"
                                 "*-test.el" "*-tests.el" "LICENSE"
                                 "README*" "*-pkg.el"))
                      :source "MELPA" :protocol https :inherit t
                      :depth treeless :ref
                      "91b9e0207fff5883383fd39c45ad5522e9b90e65"))
 (ultra-scroll :source "elpaca-menu-lock-file" :recipe
               (:package "ultra-scroll" :fetcher github :repo
                         "jdtsmith/ultra-scroll" :files
                         ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                          "*.texinfo" "doc/dir" "doc/*.info"
                          "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                          "docs/dir" "docs/*.info" "docs/*.texi"
                          "docs/*.texinfo"
                          (:exclude ".dir-locals.el" "test.el"
                                    "tests.el" "*-test.el"
                                    "*-tests.el" "LICENSE" "README*"
                                    "*-pkg.el"))
                         :source "MELPA" :protocol https :inherit t
                         :depth treeless :type git :host github :ref
                         "08758c6772c5fbce54fb74fb5cce080b6425c6ce"))
 (undo-tree :source "elpaca-menu-lock-file" :recipe
            (:package "undo-tree" :repo
                      ("https://gitlab.com/tsc25/undo-tree"
                       . "undo-tree")
                      :files ("*" (:exclude ".git")) :source
                      "GNU ELPA" :protocol https :inherit t :depth
                      treeless :ref
                      "2bf5e230f1d11df7bbd9d8c722749e34482bc458"))
 (unicode-fonts :source "elpaca-menu-lock-file" :recipe
                (:package "unicode-fonts" :repo
                          "rolandwalker/unicode-fonts" :fetcher github
                          :files
                          ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                           "*.texinfo" "doc/dir" "doc/*.info"
                           "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                           "docs/dir" "docs/*.info" "docs/*.texi"
                           "docs/*.texinfo"
                           (:exclude ".dir-locals.el" "test.el"
                                     "tests.el" "*-test.el"
                                     "*-tests.el" "LICENSE" "README*"
                                     "*-pkg.el"))
                          :source "MELPA" :protocol https :inherit t
                          :depth treeless :ref
                          "d4a0648a2206d9a896433817110957b3b9e1c17a"))
 (unidecode :source "elpaca-menu-lock-file" :recipe
            (:package "unidecode" :fetcher github :repo
                      "sindikat/unidecode" :files (:defaults "data")
                      :source "MELPA" :protocol https :inherit t
                      :depth treeless :ref
                      "525b51b38f5b0435642005957740fe22ecb2a53c"))
 (verb :source "elpaca-menu-lock-file" :recipe
       (:package "verb" :repo "federicotdn/verb" :fetcher github
                 :files
                 ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
                  "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
                  "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
                  "docs/*.texinfo"
                  (:exclude ".dir-locals.el" "test.el" "tests.el"
                            "*-test.el" "*-tests.el" "LICENSE"
                            "README*" "*-pkg.el"))
                 :source "MELPA" :protocol https :inherit t :depth
                 treeless :ref
                 "0625fb314341a479dd472ae5e7f10375c1988131"))
 (vertico :source "elpaca-menu-lock-file" :recipe
          (:package "vertico" :repo "minad/vertico" :files
                    (:defaults "extensions/vertico-*.el") :fetcher
                    github :source "MELPA" :protocol https :inherit t
                    :depth treeless :ref
                    "93f15873d7d6244d72202c5dd7724a030a2d5b9a"))
 (vertico-posframe :source "elpaca-menu-lock-file" :recipe
                   (:package "vertico-posframe" :repo
                             ("https://github.com/tumashu/vertico-posframe"
                              . "vertico-posframe")
                             :files ("*" (:exclude ".git")) :source
                             "GNU ELPA" :protocol https :inherit t
                             :depth treeless :ref
                             "d6e06a4f1b34d24cc0ca6ec69d2d6c965191b23e"))
 (vimish-fold :source "elpaca-menu-lock-file" :recipe
              (:package "vimish-fold" :repo
                        "matsievskiysv/vimish-fold" :fetcher github
                        :files
                        ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                         "*.texinfo" "doc/dir" "doc/*.info"
                         "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                         "docs/dir" "docs/*.info" "docs/*.texi"
                         "docs/*.texinfo"
                         (:exclude ".dir-locals.el" "test.el"
                                   "tests.el" "*-test.el" "*-tests.el"
                                   "LICENSE" "README*" "*-pkg.el"))
                        :source "MELPA" :protocol https :inherit t
                        :depth treeless :ref
                        "f71f374d28a83e5f15612fa64aac1b2e78be2dcd"))
 (volatile-highlights :source "elpaca-menu-lock-file" :recipe
                      (:package "volatile-highlights" :repo
                                "k-talo/volatile-highlights.el"
                                :fetcher github :files
                                ("*.el" "*.el.in" "dir" "*.info"
                                 "*.texi" "*.texinfo" "doc/dir"
                                 "doc/*.info" "doc/*.texi"
                                 "doc/*.texinfo" "lisp/*.el"
                                 "docs/dir" "docs/*.info"
                                 "docs/*.texi" "docs/*.texinfo"
                                 (:exclude ".dir-locals.el" "test.el"
                                           "tests.el" "*-test.el"
                                           "*-tests.el" "LICENSE"
                                           "README*" "*-pkg.el"))
                                :source "MELPA" :protocol https
                                :inherit t :depth treeless :ref
                                "b1e7754d7b502ef6583a13f2662e515a654f944d"))
 (web-mode :source "elpaca-menu-lock-file" :recipe
           (:package "web-mode" :repo "fxbois/web-mode" :fetcher
                     github :files
                     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                      "doc/*.texinfo" "lisp/*.el" "docs/dir"
                      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                      (:exclude ".dir-locals.el" "test.el" "tests.el"
                                "*-test.el" "*-tests.el" "LICENSE"
                                "README*" "*-pkg.el"))
                     :source "MELPA" :protocol https :inherit t :depth
                     treeless :ref
                     "1e7694aee87722f9e51b6e39c35d175d83a1fb2c"))
 (websocket :source "elpaca-menu-lock-file" :recipe
            (:package "websocket" :repo "ahyatt/emacs-websocket"
                      :fetcher github :files
                      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                       "doc/*.texinfo" "lisp/*.el" "docs/dir"
                       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                       (:exclude ".dir-locals.el" "test.el" "tests.el"
                                 "*-test.el" "*-tests.el" "LICENSE"
                                 "README*" "*-pkg.el"))
                      :source "MELPA" :protocol https :inherit t
                      :depth treeless :ref
                      "2195e1247ecb04c30321702aa5f5618a51c329c5"))
 (wfnames :source "elpaca-menu-lock-file" :recipe
          (:package "wfnames" :fetcher github :repo
                    "thierryvolpiatto/wfnames" :files
                    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                     "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                     "doc/*.texinfo" "lisp/*.el" "docs/dir"
                     "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                     (:exclude ".dir-locals.el" "test.el" "tests.el"
                               "*-test.el" "*-tests.el" "LICENSE"
                               "README*" "*-pkg.el"))
                    :source "MELPA" :protocol https :inherit t :depth
                    treeless :ref
                    "6ea49841ab76f44c0164b9f4722da2f9d46228da"))
 (wgrep :source "elpaca-menu-lock-file" :recipe
        (:package "wgrep" :fetcher github :repo
                  "mhayashi1120/Emacs-wgrep" :files ("wgrep.el")
                  :source "MELPA" :protocol https :inherit t :depth
                  treeless :ref
                  "49f09ab9b706d2312cab1199e1eeb1bcd3f27f6f"))
 (which-key :source "elpaca-menu-lock-file" :recipe
            (:package "which-key" :repo "justbur/emacs-which-key"
                      :fetcher github :files
                      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                       "doc/*.texinfo" "lisp/*.el" "docs/dir"
                       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                       (:exclude ".dir-locals.el" "test.el" "tests.el"
                                 "*-test.el" "*-tests.el" "LICENSE"
                                 "README*" "*-pkg.el"))
                      :source "MELPA" :protocol https :inherit t
                      :depth treeless :wait t :ref
                      "38d4308d1143b61e4004b6e7a940686784e51500"))
 (whisper :source "elpaca-menu-lock-file" :recipe
          (:package "whisper" :fetcher github :repo
                    "natrys/whisper.el" :files
                    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                     "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                     "doc/*.texinfo" "lisp/*.el" "docs/dir"
                     "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                     (:exclude ".dir-locals.el" "test.el" "tests.el"
                               "*-test.el" "*-tests.el" "LICENSE"
                               "README*" "*-pkg.el"))
                    :source "MELPA" :protocol https :inherit t :depth
                    treeless :type git :host github :ref
                    "c6cecf821704e949fa735b0975377b401c121262"))
 (with-editor :source "elpaca-menu-lock-file"
   :recipe
   (:package "with-editor" :fetcher github :repo "magit/with-editor"
             :files
             ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
              "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
              "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
              "docs/*.texinfo"
              (:exclude ".dir-locals.el" "test.el" "tests.el"
                        "*-test.el" "*-tests.el" "LICENSE" "README*"
                        "*-pkg.el"))
             :source "MELPA" :protocol https :inherit t :depth
             treeless :ref "64211dcb815f2533ac3d2a7e56ff36ae804d8338"))
 (wombag :source "elpaca-menu-lock-file" :recipe
         (:source nil :protocol https :inherit t :depth treeless :host
                  github :repo "karthink/wombag" :package "wombag"
                  :ref "d5e19cc55a7388aa3c158b5c19c885b61da1f63e"))
 (wttrin :source "elpaca-menu-lock-file" :recipe
         (:package "wttrin" :fetcher github :repo
                   "cjennings/emacs-wttrin" :files
                   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                    "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                    "doc/*.texinfo" "lisp/*.el" "docs/dir"
                    "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                    (:exclude ".dir-locals.el" "test.el" "tests.el"
                              "*-test.el" "*-tests.el" "LICENSE"
                              "README*" "*-pkg.el"))
                   :source "MELPA" :protocol https :inherit t :depth
                   treeless :ref
                   "b74b98f177d92d50ddbede900ba41212e07c5f63"))
 (xterm-color :source "elpaca-menu-lock-file" :recipe
              (:package "xterm-color" :repo "atomontage/xterm-color"
                        :fetcher github :files
                        ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                         "*.texinfo" "doc/dir" "doc/*.info"
                         "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                         "docs/dir" "docs/*.info" "docs/*.texi"
                         "docs/*.texinfo"
                         (:exclude ".dir-locals.el" "test.el"
                                   "tests.el" "*-test.el" "*-tests.el"
                                   "LICENSE" "README*" "*-pkg.el"))
                        :source "MELPA" :protocol https :inherit t
                        :depth treeless :ref
                        "86fab1d247eb5ebe6b40fa5073a70dfa487cd465"))
 (yaml :source "elpaca-menu-lock-file" :recipe
       (:package "yaml" :repo "zkry/yaml.el" :fetcher github :files
                 ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
                  "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
                  "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
                  "docs/*.texinfo"
                  (:exclude ".dir-locals.el" "test.el" "tests.el"
                            "*-test.el" "*-tests.el" "LICENSE"
                            "README*" "*-pkg.el"))
                 :source "MELPA" :protocol https :inherit t :depth
                 treeless :host github :ref
                 "f2369fb4985ed054be47ae111760ff2075dff72a"))
 (yaml-mode :source "elpaca-menu-lock-file" :recipe
            (:package "yaml-mode" :repo "yoshiki/yaml-mode" :fetcher
                      github :files
                      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                       "doc/*.texinfo" "lisp/*.el" "docs/dir"
                       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                       (:exclude ".dir-locals.el" "test.el" "tests.el"
                                 "*-test.el" "*-tests.el" "LICENSE"
                                 "README*" "*-pkg.el"))
                      :source "MELPA" :protocol https :inherit t
                      :depth treeless :ref
                      "d91f878729312a6beed77e6637c60497c5786efa"))
 (yaml-pro :source "elpaca-menu-lock-file" :recipe
           (:package "yaml-pro" :repo "zkry/yaml-pro" :fetcher github
                     :files
                     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                      "doc/*.texinfo" "lisp/*.el" "docs/dir"
                      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                      (:exclude ".dir-locals.el" "test.el" "tests.el"
                                "*-test.el" "*-tests.el" "LICENSE"
                                "README*" "*-pkg.el"))
                     :source "MELPA" :protocol https :inherit t :depth
                     treeless :ref
                     "9b9509188e5b88bb933e98ab36ab992519b9554b"))
 (yascroll :source "elpaca-menu-lock-file" :recipe
           (:package "yascroll" :fetcher github :repo
                     "emacsorphanage/yascroll" :files
                     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                      "doc/*.texinfo" "lisp/*.el" "docs/dir"
                      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                      (:exclude ".dir-locals.el" "test.el" "tests.el"
                                "*-test.el" "*-tests.el" "LICENSE"
                                "README*" "*-pkg.el"))
                     :source "MELPA" :protocol https :inherit t :depth
                     treeless :ref
                     "c0a302e6a44169c290564174c48298572f418f62"))
 (yasnippet :source "elpaca-menu-lock-file" :recipe
            (:package "yasnippet" :repo "joaotavora/yasnippet"
                      :fetcher github :files
                      ("yasnippet.el" "snippets") :source "MELPA"
                      :protocol https :inherit t :depth treeless :ref
                      "c1e6ff23e9af16b856c88dfaab9d3ad7b746ad37"))
 (yasnippet-snippets :source "elpaca-menu-lock-file" :recipe
                     (:package "yasnippet-snippets" :repo
                               "AndreaCrotti/yasnippet-snippets"
                               :fetcher github :files
                               ("*.el" "snippets" ".nosearch") :source
                               "MELPA" :protocol https :inherit t
                               :depth treeless :ref
                               "606ee926df6839243098de6d71332a697518cb86"))
 (zenburn-theme :source "elpaca-menu-lock-file" :recipe
                (:package "zenburn-theme" :repo
                          "bbatsov/zenburn-emacs" :fetcher github
                          :files
                          ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                           "*.texinfo" "doc/dir" "doc/*.info"
                           "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                           "docs/dir" "docs/*.info" "docs/*.texi"
                           "docs/*.texinfo"
                           (:exclude ".dir-locals.el" "test.el"
                                     "tests.el" "*-test.el"
                                     "*-tests.el" "LICENSE" "README*"
                                     "*-pkg.el"))
                          :source "MELPA" :protocol https :inherit t
                          :depth treeless :ref
                          "d9557cf5ab9c03dc70693e3892f5ffdc5d345d22")))
