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
                          :source "elpaca-menu-lock-file" :id
                          ace-jump-mode :type git :protocol https
                          :inherit t :depth treeless :ref
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
                   :source "elpaca-menu-lock-file" :id ace-mc :type
                   git :protocol https :inherit t :depth treeless :ref
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
                       :source "elpaca-menu-lock-file" :id ace-window
                       :type git :protocol https :inherit t :depth
                       treeless :ref
                       "77115afc1b0b9f633084cf7479c767988106c196"))
 (adaptive-wrap :source "elpaca-menu-lock-file" :recipe
                (:package "adaptive-wrap" :repo
                          ("https://github.com/emacsmirror/gnu_elpa"
                           . "adaptive-wrap")
                          :tar "0.9" :host gnu :branch
                          "externals/adaptive-wrap" :files
                          ("*" (:exclude ".git")) :source
                          "elpaca-menu-lock-file" :id adaptive-wrap
                          :type git :protocol https :inherit t :depth
                          treeless :ref
                          "e929b38c12f17aa6f8d6270326301d61fbb09cab"))
 (ag :source "elpaca-menu-lock-file" :recipe
     (:package "ag" :repo "Wilfred/ag.el" :fetcher github :files
               ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
                "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
                "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
                "docs/*.texinfo"
                (:exclude ".dir-locals.el" "test.el" "tests.el"
                          "*-test.el" "*-tests.el" "LICENSE" "README*"
                          "*-pkg.el"))
               :source "elpaca-menu-lock-file" :id ag :type git
               :protocol https :inherit t :depth treeless :ref
               "ed7e32064f92f1315cecbfc43f120bbc7508672c"))
 (aio :source "elpaca-menu-lock-file" :recipe
      (:package "aio" :fetcher github :repo "skeeto/emacs-aio" :files
                ("aio.el" "README.md" "UNLICENSE") :source
                "elpaca-menu-lock-file" :id aio :type git :protocol
                https :inherit t :depth treeless :ref
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
                  :source "elpaca-menu-lock-file" :id alert :type git
                  :protocol https :inherit t :depth treeless :ref
                  "31fc56855289d0846e73d7ca9b84b628aeac16a0"))
 (all-the-icons :source "elpaca-menu-lock-file" :recipe
                (:package "all-the-icons" :repo
                          "domtronn/all-the-icons.el" :fetcher github
                          :files (:defaults "svg") :source
                          "elpaca-menu-lock-file" :id all-the-icons
                          :host github :branch "svg" :type git
                          :protocol https :inherit t :depth treeless
                          :ref
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
                                     :source "elpaca-menu-lock-file"
                                     :id all-the-icons-completion
                                     :type git :protocol https
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
                                :source "elpaca-menu-lock-file" :id
                                all-the-icons-dired :type git
                                :protocol https :inherit t :depth
                                treeless :ref
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
                                  :source "elpaca-menu-lock-file" :id
                                  all-the-icons-ibuffer :type git
                                  :protocol https :inherit t :depth
                                  treeless :ref
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
                     :source "elpaca-menu-lock-file" :id anaphora
                     :type git :protocol https :inherit t :depth
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
                     :source "elpaca-menu-lock-file" :id annalist
                     :type git :protocol https :inherit t :depth
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
                 :source "elpaca-menu-lock-file" :id anzu :type git
                 :protocol https :inherit t :depth treeless :ref
                 "21cb5ab2295614372cb9f1a21429381e49a6255f"))
 (apheleia :source "elpaca-menu-lock-file" :recipe
           (:package "apheleia" :fetcher github :repo
                     "radian-software/apheleia" :files
                     (:defaults ("scripts" "scripts/formatters"))
                     :source "elpaca-menu-lock-file" :id apheleia
                     :type git :protocol https :inherit t :depth
                     treeless :ref
                     "e6e5d5523d229735ab5f8ec83e10beefcfd00d76"))
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
                  :source "elpaca-menu-lock-file" :id async :type git
                  :protocol https :inherit t :depth treeless :ref
                  "5faab28916603bb324d9faba057021ce028ca847"))
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
                       :source "elpaca-menu-lock-file" :id autothemer
                       :type git :protocol https :inherit t :depth
                       treeless :ref
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
                :source "elpaca-menu-lock-file" :id avy :type git
                :protocol https :inherit t :depth treeless :ref
                "933d1f36cca0f71e4acb5fac707e9ae26c536264"))
 (awesome-tray :source "elpaca-menu-lock-file" :recipe
               (:source "elpaca-menu-lock-file" :package
                        "awesome-tray" :id awesome-tray :type git
                        :host github :repo
                        "manateelazycat/awesome-tray" :protocol https
                        :inherit t :depth treeless :ref
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
                            :source "elpaca-menu-lock-file" :id
                            bash-completion :type git :protocol https
                            :inherit t :depth treeless :ref
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
                   :source "elpaca-menu-lock-file" :id beacon :type
                   git :protocol https :inherit t :depth treeless :ref
                   "85261a928ae0ec3b41e639f05291ffd6bf7c231c"))
 (biblio :source "elpaca-menu-lock-file" :recipe
         (:package "biblio" :repo "cpitclaudel/biblio.el" :fetcher
                   github :files
                   (:defaults (:exclude "biblio-core.el")) :source
                   "elpaca-menu-lock-file" :id biblio :type git
                   :protocol https :inherit t :depth treeless :ref
                   "bb9d6b4b962fb2a4e965d27888268b66d868766b"))
 (biblio-core :source "elpaca-menu-lock-file" :recipe
              (:package "biblio-core" :repo "cpitclaudel/biblio.el"
                        :fetcher github :files ("biblio-core.el")
                        :source "elpaca-menu-lock-file" :id
                        biblio-core :type git :protocol https :inherit
                        t :depth treeless :ref
                        "bb9d6b4b962fb2a4e965d27888268b66d868766b"))
 (bibtex-completion :source "elpaca-menu-lock-file" :recipe
                    (:package "bibtex-completion" :fetcher github
                              :repo "tmalsburg/helm-bibtex" :files
                              ("bibtex-completion.el") :source
                              "elpaca-menu-lock-file" :id
                              bibtex-completion :type git :protocol
                              https :inherit t :depth treeless :ref
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
                  :source "elpaca-menu-lock-file" :id biome :type git
                  :protocol https :inherit t :depth treeless :ref
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
                    :source "elpaca-menu-lock-file" :id blacken :type
                    git :protocol https :inherit t :depth treeless
                    :ref "cdd0cdb1e25f119d9347fd1c642760c6666a9180"))
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
                   :source "elpaca-menu-lock-file" :id blamer :type
                   git :protocol https :inherit t :depth treeless :ref
                   "aa9b22d4e847d15a5c4659c0407aa8bf4242cc94"))
 (bookmark+ :source "elpaca-menu-lock-file" :recipe
            (:source "elpaca-menu-lock-file" :package "bookmark+" :id
                     bookmark+ :fetcher github :repo
                     "emacsmirror/bookmark-plus" :files
                     (:defaults "*.el") :main "bookmark+.el" :type git
                     :protocol https :inherit t :depth treeless :ref
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
                                :source "elpaca-menu-lock-file" :id
                                bookmark-in-project :type git
                                :protocol https :inherit t :depth
                                treeless :ref
                                "bf923ddd3e74fe99e086221e461a5fa7599d0644"))
 (bookmark-view :source "elpaca-menu-lock-file" :recipe
                (:source "elpaca-menu-lock-file" :package
                         "bookmark-view" :id bookmark-view :type git
                         :host github :repo "minad/bookmark-view"
                         :protocol https :inherit t :depth treeless
                         :ref
                         "0023eb200eea083e8f2d36df860234c3acfc0499"))
 (breadcrumb :source "elpaca-menu-lock-file" :recipe
             (:package "breadcrumb" :repo
                       ("https://github.com/joaotavora/breadcrumb"
                        . "breadcrumb")
                       :tar "1.0.1" :host gnu :files
                       ("*" (:exclude ".git")) :source
                       "elpaca-menu-lock-file" :id breadcrumb :type
                       git :protocol https :inherit t :depth treeless
                       :ref "1d9dd90f77a594cd50b368e6efc85d44539ec209"))
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
                             :source "elpaca-menu-lock-file" :id
                             browse-at-remote :type git :protocol
                             https :inherit t :depth treeless :ref
                             "38e5ffd77493c17c821fd88f938dbf42705a5158"))
 (brushup :source "elpaca-menu-lock-file" :recipe
          (:source "elpaca-menu-lock-file" :package "brushup" :id
                   brushup :host github :repo "chiply/brushup" :type
                   git :protocol https :inherit t :depth treeless :ref
                   "e838b75c75288c2854b8640d39034981532e44a5"))
 (bufler :source "elpaca-menu-lock-file" :recipe
         (:package "bufler" :fetcher github :repo
                   "alphapapa/bufler.el" :files
                   (:defaults (:exclude "helm-bufler.el")) :source
                   "elpaca-menu-lock-file" :id bufler :type git
                   :protocol https :inherit t :depth treeless :ref
                   "b96822d2132fda6bd1dd86f017d7e76e3b990c82"))
 (bui :source "elpaca-menu-lock-file" :recipe
      (:package "bui" :repo "alezost/bui.el" :fetcher github :files
                ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
                 "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
                 "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
                 "docs/*.texinfo"
                 (:exclude ".dir-locals.el" "test.el" "tests.el"
                           "*-test.el" "*-tests.el" "LICENSE"
                           "README*" "*-pkg.el"))
                :source "elpaca-menu-lock-file" :id bui :type git
                :protocol https :inherit t :depth treeless :ref
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
                  :source "elpaca-menu-lock-file" :id burly :type git
                  :protocol https :inherit t :depth treeless :ref
                  "d5b7133b5b629dd6bca29bb16660a9e472e82e25"))
 (calfw :source "elpaca-menu-lock-file" :recipe
        (:package "calfw" :fetcher github :repo "kiwanami/emacs-calfw"
                  :files ("calfw.el" "calfw-compat.el" "calfw-org.el")
                  :source "elpaca-menu-lock-file" :id calfw :type git
                  :protocol https :inherit t :depth treeless :ref
                  "36846cdca91794cf38fa171d5a3ac291d3ebc060"))
 (cape :source "elpaca-menu-lock-file" :recipe
       (:package "cape" :repo "minad/cape" :fetcher github :files
                 ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
                  "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
                  "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
                  "docs/*.texinfo"
                  (:exclude ".dir-locals.el" "test.el" "tests.el"
                            "*-test.el" "*-tests.el" "LICENSE"
                            "README*" "*-pkg.el"))
                 :source "elpaca-menu-lock-file" :id cape :type git
                 :protocol https :inherit t :depth treeless :ref
                 "e608ccb4c19caabae3fe37d71e41891feec23601"))
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
                                :source "elpaca-menu-lock-file" :id
                                celestial-mode-line :type git
                                :protocol https :inherit t :depth
                                treeless :ref
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
                 :source "elpaca-menu-lock-file" :id cfrs :type git
                 :protocol https :inherit t :depth treeless :ref
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
                            :source "elpaca-menu-lock-file" :id
                            chocolate-theme :type git :protocol https
                            :inherit t :depth treeless :ref
                            "ccc05f7ad96d3d1332727689bf6250443adc7ec0"))
 (circe :source "elpaca-menu-lock-file" :recipe
        (:package "circe" :repo "emacs-circe/circe" :fetcher github
                  :files
                  ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                   "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                   "doc/*.texinfo" "lisp/*.el" "docs/dir"
                   "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                   (:exclude ".dir-locals.el" "test.el" "tests.el"
                             "*-test.el" "*-tests.el" "LICENSE"
                             "README*" "*-pkg.el"))
                  :source "elpaca-menu-lock-file" :id circe :type git
                  :protocol https :inherit t :depth treeless :ref
                  "f717332348e4b59499dbf60c56155d9f03cd9303"))
 (citar :source "elpaca-menu-lock-file" :recipe
        (:package "citar" :repo "emacs-citar/citar" :fetcher github
                  :files (:defaults) :old-names (bibtex-actions)
                  :source "elpaca-menu-lock-file" :id citar :type git
                  :protocol https :inherit t :depth treeless :ref
                  "911a7d59c4ac94318fc6b6fb6f55840ad04482ad"))
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
                     :source "elpaca-menu-lock-file" :id citeproc
                     :type git :protocol https :inherit t :depth
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
                   :source "elpaca-menu-lock-file" :id closql :type
                   git :protocol https :inherit t :depth treeless :ref
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
                                   :source "elpaca-menu-lock-file" :id
                                   color-identifiers-mode :type git
                                   :protocol https :inherit t :depth
                                   treeless :ref
                                   "adcdbbe9c69edeb207f2b066db071057f3f612d6"))
 (color-rg :source "elpaca-menu-lock-file" :recipe
           (:source "elpaca-menu-lock-file" :package "color-rg" :id
                    color-rg :type git :host github :repo
                    "manateelazycat/color-rg" :protocol https :inherit
                    t :depth treeless :ref
                    "fdecae30c59187a8de42582c3b2ef219ddf5e31c"))
 (combobulate :source "elpaca-menu-lock-file" :recipe
              (:source "elpaca-menu-lock-file" :package "combobulate"
                       :id combobulate :host github :repo
                       "mickeynp/combobulate" :type git :protocol
                       https :inherit t :depth treeless :ref
                       "38773810b5e532f25d11c6d1af02c3a8dffeacd7"))
 (compat :source "elpaca-menu-lock-file" :recipe
         (:package "compat" :repo
                   ("https://github.com/emacs-compat/compat"
                    . "compat")
                   :files ("*" (:exclude ".git")) :source "GNU ELPA"
                   :protocol https :inherit t :depth treeless :ref
                   "1f3d7596173cf2851d3c4181b15d6c3573a38252"))
 (compile-angel :source "elpaca-menu-lock-file" :recipe
                (:package "compile-angel" :fetcher github :repo
                          "jamescherti/compile-angel.el" :files
                          ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                           "*.texinfo" "doc/dir" "doc/*.info"
                           "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                           "docs/dir" "docs/*.info" "docs/*.texi"
                           "docs/*.texinfo"
                           (:exclude ".dir-locals.el" "test.el"
                                     "tests.el" "*-test.el"
                                     "*-tests.el" "LICENSE" "README*"
                                     "*-pkg.el"))
                          :source "elpaca-menu-lock-file" :id
                          compile-angel :type git :protocol https
                          :inherit t :depth treeless :ref
                          "b44df344bd8f2279452a526a10f984df29b3aefc"))
 (compile-multi :source "elpaca-menu-lock-file" :recipe
                (:package "compile-multi" :fetcher github :repo
                          "mohkale/compile-multi" :files
                          (:defaults "extensions/*/*.el") :source
                          "elpaca-menu-lock-file" :id compile-multi
                          :type git :protocol https :inherit t :depth
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
             :source "elpaca-menu-lock-file" :id cond-let :type git
             :protocol https :inherit t :depth treeless :ref
             "8bf87d45e169ebc091103b2aae325aece3aa804d"))
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
                    :source "elpaca-menu-lock-file" :id consult :type
                    git :protocol https :inherit t :depth treeless
                    :ref "f8c2ef57e83af3d45e345e5c14089f2f9973682b"))
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
                         :source "elpaca-menu-lock-file" :id
                         consult-dash :type git :protocol https
                         :inherit t :depth treeless :ref
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
                        :source "elpaca-menu-lock-file" :id
                        consult-dir :type git :protocol https :inherit
                        t :depth treeless :ref
                        "1497b46d6f48da2d884296a1297e5ace1e050eb5"))
 (consult-gh :source "elpaca-menu-lock-file" :recipe
             (:package "consult-gh" :fetcher github :repo
                       "armindarvish/consult-gh" :files ("*.el")
                       :source "elpaca-menu-lock-file" :id consult-gh
                       :host github :type git :protocol https :inherit
                       t :depth treeless :ref
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
                           :source "elpaca-menu-lock-file" :id
                           consult-ls-git :type git :protocol https
                           :inherit t :depth treeless :ref
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
                        :source "elpaca-menu-lock-file" :id
                        consult-lsp :type git :protocol https :inherit
                        t :depth treeless :ref
                        "d11102c9db33c4ca7817296a2edafc3e26a61117"))
 (consult-mu :source "elpaca-menu-lock-file" :recipe
             (:source "elpaca-menu-lock-file" :package "consult-mu"
                      :id consult-mu :host github :repo
                      "armindarvish/consult-mu" :branch "main" :files
                      (:defaults "extras/*.el") :type git :protocol
                      https :inherit t :depth treeless :ref
                      "8b54bbf86c2f112e3520eeeefb70d509b4590385"))
 (consult-omni :source "elpaca-menu-lock-file" :recipe
               (:source "elpaca-menu-lock-file" :package
                        "consult-omni" :id consult-omni :host github
                        :repo "armindarvish/consult-omni" :files
                        (:defaults "sources/*.el") :type git :protocol
                        https :inherit t :depth treeless :ref
                        "bdcd5a065340dce9906ac5c5f359906d31877963"))
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
                                  :source "elpaca-menu-lock-file" :id
                                  consult-project-extra :type git
                                  :protocol https :inherit t :depth
                                  treeless :ref
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
                              :source "elpaca-menu-lock-file" :id
                              consult-yasnippet :type git :protocol
                              https :inherit t :depth treeless :ref
                              "a3482dfbdcbe487ba5ff934a1bb6047066ff2194"))
 (copilot :source "elpaca-menu-lock-file" :recipe
          (:package "copilot" :fetcher github :repo
                    "copilot-emacs/copilot.el" :files
                    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                     "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                     "doc/*.texinfo" "lisp/*.el" "docs/dir"
                     "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                     (:exclude ".dir-locals.el" "test.el" "tests.el"
                               "*-test.el" "*-tests.el" "LICENSE"
                               "README*" "*-pkg.el"))
                    :source "elpaca-menu-lock-file" :id copilot :type
                    git :protocol https :inherit t :depth treeless
                    :ref "c8c06efaa508569e13d7191882ae33435bb14543"))
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
                         :source "elpaca-menu-lock-file" :id
                         copilot-chat :type git :protocol https
                         :inherit t :depth treeless :ref
                         "07aa0bce626da5fa656f14474d24b4d01dce7091"))
 (corfu :source "elpaca-menu-lock-file" :recipe
        (:package "corfu" :repo "minad/corfu" :files
                  (:defaults "extensions/corfu-*.el") :fetcher github
                  :source "elpaca-menu-lock-file" :id corfu :type git
                  :protocol https :inherit t :depth treeless :ref
                  "d2a995c5c732d0fc439efe09440870a9de779a74"))
 (counsel :source "elpaca-menu-lock-file" :recipe
          (:package "counsel" :repo "abo-abo/swiper" :fetcher github
                    :files ("counsel.el") :source
                    "elpaca-menu-lock-file" :id counsel :type git
                    :protocol https :inherit t :depth treeless :ref
                    "1005bff8a700b92dc464f770aff8a0db5b4a1c0b"))
 (csv-mode :source "elpaca-menu-lock-file" :recipe
           (:package "csv-mode" :repo
                     ("https://github.com/emacsmirror/gnu_elpa"
                      . "csv-mode")
                     :tar "1.27" :host gnu :branch
                     "externals/csv-mode" :files
                     ("*" (:exclude ".git")) :source
                     "elpaca-menu-lock-file" :id csv-mode :type git
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
               :source "elpaca-menu-lock-file" :id ct :type git
               :protocol https :inherit t :depth treeless :ref
               "66fb78baf83525ca068c3ddd156ef0989a65bf9d"))
 (dap-mode :source "elpaca-menu-lock-file" :recipe
           (:package "dap-mode" :repo "emacs-lsp/dap-mode" :fetcher
                     github :files (:defaults "icons") :source
                     "elpaca-menu-lock-file" :id dap-mode :type git
                     :protocol https :inherit t :depth treeless :ref
                     "b77d9bdb15d89e354b8a20906bebe7789e19fc9b"))
 (dash :source "elpaca-menu-lock-file" :recipe
       (:package "dash" :fetcher github :repo "magnars/dash.el" :files
                 ("dash.el" "dash.texi") :source
                 "elpaca-menu-lock-file" :id dash :type git :protocol
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
                      :source "elpaca-menu-lock-file" :id dash-docs
                      :wait t :type git :protocol https :inherit t
                      :depth treeless :ref
                      "29848b6b347ac520f7646c200ed2ec36cea3feda"))
 (dash-functional :source "elpaca-menu-lock-file" :recipe
                  (:package "dash-functional" :fetcher github :repo
                            "magnars/dash.el" :files
                            ("dash-functional.el") :source
                            "elpaca-menu-lock-file" :id
                            dash-functional :type git :protocol https
                            :inherit t :depth treeless :ref
                            "d3a84021dbe48dba63b52ef7665651e0cf02e915"))
 (ddp :source "elpaca-menu-lock-file" :recipe
      (:package "ddp" :fetcher github :repo "eki3z/ddp.el" :files
                ("*.el") :source "elpaca-menu-lock-file" :id ddp :type
                git :host github :branch "master" :protocol https
                :inherit t :depth treeless :ref
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
                               :source "elpaca-menu-lock-file" :id
                               default-text-scale :type git :protocol
                               https :inherit t :depth treeless :ref
                               "e23b3f8d402dd3871ee5e6dacd10fda223128896"))
 (deferred :source "elpaca-menu-lock-file" :recipe
           (:package "deferred" :repo "kiwanami/emacs-deferred"
                     :fetcher github :files ("deferred.el") :source
                     "elpaca-menu-lock-file" :id deferred :type git
                     :protocol https :inherit t :depth treeless :ref
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
                        :source "elpaca-menu-lock-file" :id
                        define-word :type git :protocol https :inherit
                        t :depth treeless :ref
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
                     :source "elpaca-menu-lock-file" :id detached
                     :type git :protocol https :inherit t :depth
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
                    :source "elpaca-menu-lock-file" :id devdocs :type
                    git :protocol https :inherit t :depth treeless
                    :ref "25c746024ddf73570195bf42b841f761a2fee10c"))
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
                    :source "elpaca-menu-lock-file" :id diff-hl :type
                    git :protocol https :inherit t :depth treeless
                    :ref "bb9af85441b0cbb3281268d30256d50f0595ebfe"))
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
                   :source "elpaca-menu-lock-file" :id dimmer :type
                   git :protocol https :inherit t :depth treeless :ref
                   "a5b697580e5aed6168b571ae3d925753428284f8"))
 (dired-hacks :source "elpaca-menu-lock-file" :recipe
              (:source "elpaca-menu-lock-file" :package "dired-hacks"
                       :id dired-hacks :host github :repo
                       "Fuco1/dired-hacks" :files
                       ("dired-hacks.el" "dired-hacks-utils.el"
                        "dired-subtree.el" "dired-ranger.el")
                       :type git :protocol https :inherit t :depth
                       treeless :ref
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
                   :source "elpaca-menu-lock-file" :id docker :type
                   git :protocol https :inherit t :depth treeless :ref
                   "916686b86e83a3bd2281fbc5e6f98962aa747429"))
 (docker-compose-mode :source "elpaca-menu-lock-file" :recipe
                      (:package "docker-compose-mode" :repo
                                "meqif/docker-compose-mode" :fetcher
                                github :files
                                (:defaults
                                 (:exclude
                                  "docker-compose-mode-helpers.el"))
                                :source "elpaca-menu-lock-file" :id
                                docker-compose-mode :type git
                                :protocol https :inherit t :depth
                                treeless :ref
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
                            :source "elpaca-menu-lock-file" :id
                            dockerfile-mode :type git :protocol https
                            :inherit t :depth treeless :ref
                            "97733ce074b1252c1270fd5e8a53d178b66668ed"))
 (dogears :source "elpaca-menu-lock-file" :recipe
          (:package "dogears" :fetcher github :repo
                    "alphapapa/dogears.el" :files
                    (:defaults (:exclude "helm-dogears.el")) :source
                    "elpaca-menu-lock-file" :id dogears :type git
                    :protocol https :inherit t :depth treeless :ref
                    "162671e66cac601f1cfd5d22f7da2671af2e9866"))
 (doric-themes :source "elpaca-menu-lock-file" :recipe
               (:package "doric-themes" :repo
                         "emacsmirror/doric-themes" :tar "1.1.0" :host
                         github :files ("*" (:exclude ".git")) :source
                         "elpaca-menu-lock-file" :id doric-themes
                         :type git :protocol https :inherit t :depth
                         treeless :ref
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
                      :source "elpaca-menu-lock-file" :id dumb-jump
                      :type git :protocol https :inherit t :depth
                      treeless :ref
                      "41b6b9dd44b19cf8259e45985f332917b4d9fcba"))
 (eca :source "elpaca-menu-lock-file" :recipe
      (:package "eca" :fetcher github :repo
                "editor-code-assistant/eca-emacs" :files ("*.el")
                :source "elpaca-menu-lock-file" :id eca :host github
                :type git :protocol https :inherit t :depth treeless
                :ref "f143e3d62211395de843b6f1fdb3e97df126ad3e"))
 (ef-themes :source "elpaca-menu-lock-file" :recipe
            (:package "ef-themes" :repo
                      ("https://github.com/protesilaos/ef-themes"
                       . "ef-themes")
                      :tar "2.1.0" :host gnu :files
                      ("*"
                       (:exclude ".git" "COPYING" "doclicense.texi"
                                 "contrast-ratios.org"))
                      :source "elpaca-menu-lock-file" :id ef-themes
                      :type git :protocol https :inherit t :depth
                      treeless :ref
                      "877554112c7fc8afb35f1d1c59827e5f3cba7c5e"))
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
                :source "elpaca-menu-lock-file" :id ein :type git
                :protocol https :inherit t :depth treeless :ref
                "8fa836fcd1c22f45d36249b09590b32a890f2b9e"))
 (elfeed :source "elpaca-menu-lock-file" :recipe
         (:package "elfeed" :repo "skeeto/elfeed" :fetcher github
                   :files (:defaults "README.md") :source
                   "elpaca-menu-lock-file" :id elfeed :ref
                   "90470c3ff7cf215771f31e8c5e4b08fe6ad8f65b" :type
                   git :protocol https :inherit t :depth treeless))
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
                       :source "elpaca-menu-lock-file" :id elfeed-org
                       :type git :protocol https :inherit t :depth
                       treeless :ref
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
                            :source "elpaca-menu-lock-file" :id
                            elfeed-protocol :host github :ref
                            "58936590459ccc2dfd6132f69983011d15d9404a"
                            :type git :protocol https :inherit t
                            :depth treeless))
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
                         :source "elpaca-menu-lock-file" :id
                         elfeed-score :type git :host github :protocol
                         https :inherit t :depth treeless :ref
                         "f6ef83c472e6f01d0f60130ecac768462c5a20b7"))
 (elisp-refs :source "elpaca-menu-lock-file" :recipe
             (:package "elisp-refs" :repo "Wilfred/elisp-refs"
                       :fetcher github :files
                       (:defaults (:exclude "elisp-refs-bench.el"))
                       :source "elpaca-menu-lock-file" :id elisp-refs
                       :type git :protocol https :inherit t :depth
                       treeless :ref
                       "541a064c3ce27867872cf708354a65d83baf2a6d"))
 (elpaca :source
   "elpaca-menu-lock-file" :recipe
   (:source nil :protocol https :inherit ignore :depth nil :repo
            "https://github.com/progfolio/elpaca.git" :ref
            "1508298c1ed19c81fa4ebc5d22d945322e9e4c52" :files
            (:defaults "elpaca-test.el" (:exclude "extensions"))
            :build (:not elpaca--activate-package) :package "elpaca"))
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
                    :source "elpaca-menu-lock-file" :id elysium :type
                    git :protocol https :inherit t :depth treeless
                    :ref "049ad3091baf3ce578791187c5e5e4f932c26044"))
 (emacsql :source "elpaca-menu-lock-file" :recipe
          (:package "emacsql" :fetcher github :repo "magit/emacsql"
                    :files (:defaults "README.md" "sqlite") :source
                    "elpaca-menu-lock-file" :id emacsql :type git
                    :protocol https :inherit t :depth treeless :ref
                    "f1bf30a76e621ad3c7f614a86a8445470e112896"))
 (embark :source "elpaca-menu-lock-file" :recipe
         (:package "embark" :repo "oantolin/embark" :fetcher github
                   :files ("embark.el" "embark-org.el" "embark.texi")
                   :source "elpaca-menu-lock-file" :id embark :wait t
                   :type git :protocol https :inherit t :depth
                   treeless :ref
                   "e0238889b1c946514fd967d21d70599af9c4e887"))
 (embark-consult :source "elpaca-menu-lock-file" :recipe
                 (:package "embark-consult" :repo "oantolin/embark"
                           :fetcher github :files
                           ("embark-consult.el") :source
                           "elpaca-menu-lock-file" :id embark-consult
                           :type git :protocol https :inherit t :depth
                           treeless :ref
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
                      :source "elpaca-menu-lock-file" :id embark-vc
                      :type git :protocol https :inherit t :depth
                      treeless :ref
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
                       :source "elpaca-menu-lock-file" :id emmet-mode
                       :type git :protocol https :inherit t :depth
                       treeless :ref
                       "322d3bb112fced57d63b44863357f7a0b7eee1e3"))
 (emojify :source "elpaca-menu-lock-file" :recipe
          (:package "emojify" :fetcher github :repo
                    "iqbalansari/emacs-emojify" :files
                    (:defaults "data" "images") :source
                    "elpaca-menu-lock-file" :id emojify :type git
                    :protocol https :inherit t :depth treeless :ref
                    "1b726412f19896abf5e4857d4c32220e33400b55"))
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
                     :source "elpaca-menu-lock-file" :id epresent
                     :type git :protocol https :inherit t :depth
                     treeless :ref
                     "6c8abedcf46ff08091fa2bba52eb905c6290057d"))
 (esxml :source "elpaca-menu-lock-file" :recipe
        (:package "esxml" :fetcher github :repo "tali713/esxml" :files
                  ("esxml.el" "esxml-query.el") :source
                  "elpaca-menu-lock-file" :id esxml :type git
                  :protocol https :inherit t :depth treeless :ref
                  "affada143fed7e2da08f2b3d927a027f26ad4a8f"))
 (evil :source "elpaca-menu-lock-file" :recipe
       (:package "evil" :repo "emacs-evil/evil" :fetcher github :files
                 (:defaults "doc/build/texinfo/evil.texi"
                            (:exclude "evil-test-helpers.el"))
                 :source "elpaca-menu-lock-file" :id evil :wait t
                 :type git :protocol https :inherit t :depth treeless
                 :ref "729d9a58b387704011a115c9200614e32da3cefc"))
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
                      :source "elpaca-menu-lock-file" :id evil-anzu
                      :type git :protocol https :inherit t :depth
                      treeless :ref
                      "7309650425797420944075c9c1556c7c1ff960b3"))
 (evil-collection :source "elpaca-menu-lock-file" :recipe
                  (:package "evil-collection" :fetcher github :repo
                            "emacs-evil/evil-collection" :files
                            (:defaults "modes") :source
                            "elpaca-menu-lock-file" :id
                            evil-collection :type git :protocol https
                            :inherit t :depth treeless :ref
                            "0c63456ae73520839b66c3985de9bfabd38b835f"))
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
                          :source "elpaca-menu-lock-file" :id
                          evil-exchange :type git :protocol https
                          :inherit t :depth treeless :ref
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
                             :source "elpaca-menu-lock-file" :id
                             evil-fringe-mark :type git :protocol
                             https :inherit t :depth treeless :ref
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
                             :source "elpaca-menu-lock-file" :id
                             evil-indent-plus :type git :protocol
                             https :inherit t :depth treeless :ref
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
                          :source "elpaca-menu-lock-file" :id
                          evil-surround :type git :protocol https
                          :inherit t :depth treeless :ref
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
                                 :source "elpaca-menu-lock-file" :id
                                 exec-path-from-shell :type git
                                 :protocol https :inherit t :depth
                                 treeless :ref
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
                          :source "elpaca-menu-lock-file" :id
                          expand-region :type git :protocol https
                          :inherit t :depth treeless :ref
                          "351279272330cae6cecea941b0033a8dd8bcc4e8"))
 (explain-pause-mode :source "elpaca-menu-lock-file" :recipe
                     (:source "elpaca-menu-lock-file" :package
                              "explain-pause-mode" :id
                              explain-pause-mode :host github :repo
                              "lastquestion/explain-pause-mode" :type
                              git :protocol https :inherit t :depth
                              treeless :ref
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
              :source "elpaca-menu-lock-file" :id f :type git
              :protocol https :inherit t :depth treeless :ref
              "931b6d0667fe03e7bf1c6c282d6d8d7006143c52"))
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
                              :source "elpaca-menu-lock-file" :id
                              fancy-compilation :type git :protocol
                              https :inherit t :depth treeless :ref
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
                     :source "elpaca-menu-lock-file" :id flycheck
                     :type git :protocol https :inherit t :depth
                     treeless :ref
                     "0e5eb8300d32fd562724216c19eaf199ee1451ab"))
 (flycheck-aspell :source "elpaca-menu-lock-file" :recipe
                  (:package "flycheck-aspell" :fetcher github :repo
                            "leotaku/flycheck-aspell" :files
                            ("flycheck-aspell.el") :source
                            "elpaca-menu-lock-file" :id
                            flycheck-aspell :type git :protocol https
                            :inherit t :depth treeless :ref
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
                               :source "elpaca-menu-lock-file" :id
                               flycheck-indicator :type git :protocol
                               https :inherit t :depth treeless :ref
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
                  :source "elpaca-menu-lock-file" :id focus :type git
                  :protocol https :inherit t :depth treeless :ref
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
                       :source "elpaca-menu-lock-file" :id font-utils
                       :type git :protocol https :inherit t :depth
                       treeless :ref
                       "abc572eb0dc30a26584c0058c3fe6c7273a10003"))
 (forge :source "elpaca-menu-lock-file" :recipe
        (:package "forge" :fetcher github :repo "magit/forge" :files
                  ("lisp/*.el" "docs/*.texi" ".dir-locals.el") :source
                  "elpaca-menu-lock-file" :id forge :type git
                  :protocol https :inherit t :depth treeless :ref
                  "f46e2be47ae89b18a0d6bb4496e60e72aa7a0df1"))
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
                          :source "elpaca-menu-lock-file" :id
                          fringe-helper :type git :protocol https
                          :inherit t :depth treeless :ref
                          "ef4a9c023bae18ec1ddd7265f1f2d6d2e775efdd"))
 (gcmh :source "elpaca-menu-lock-file" :recipe
       (:package "gcmh" :repo "koral/gcmh" :fetcher gitlab :files
                 ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
                  "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
                  "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
                  "docs/*.texinfo"
                  (:exclude ".dir-locals.el" "test.el" "tests.el"
                            "*-test.el" "*-tests.el" "LICENSE"
                            "README*" "*-pkg.el"))
                 :source "elpaca-menu-lock-file" :id gcmh :type git
                 :protocol https :inherit t :depth treeless :ref
                 "0089f9c3a6d4e9a310d0791cf6fa8f35642ecfd9"))
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
                    :source "elpaca-menu-lock-file" :id general :wait
                    t :type git :protocol https :inherit t :depth
                    treeless :ref
                    "a48768f85a655fe77b5f45c2880b420da1b1b9c3"))
 (ghostel :source "elpaca-menu-lock-file" :recipe
          (:source "elpaca-menu-lock-file" :package "ghostel" :id
                   ghostel :host github :repo "dakra/ghostel" :type
                   git :protocol https :inherit t :depth treeless :ref
                   "057fb1f7cc74ecb82eecd11b86be44d76d902dfc"))
 (ghub :source "elpaca-menu-lock-file" :recipe
       (:package "ghub" :fetcher github :repo "magit/ghub" :files
                 ("lisp/*.el" "docs/*.texi" ".dir-locals.el") :source
                 "elpaca-menu-lock-file" :id ghub :type git :protocol
                 https :inherit t :depth treeless :ref
                 "3866c821eea83060603d28528af1700ff6a9b318"))
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
                           :source "elpaca-menu-lock-file" :id
                           gif-screencast :type git :protocol https
                           :inherit t :depth treeless :ref
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
                       :source "elpaca-menu-lock-file" :id git-gutter
                       :type git :protocol https :inherit t :depth
                       treeless :ref
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
                     :source "elpaca-menu-lock-file" :id git-link
                     :type git :protocol https :inherit t :depth
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
                            :source "elpaca-menu-lock-file" :id
                            git-timemachine :type git :protocol https
                            :inherit t :depth treeless :ref
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
                 :source "elpaca-menu-lock-file" :id gntp :type git
                 :protocol https :inherit t :depth treeless :ref
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
                     :source "elpaca-menu-lock-file" :id goto-chg
                     :type git :protocol https :inherit t :depth
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
                  :source "elpaca-menu-lock-file" :id gptel :type git
                  :protocol https :inherit t :depth treeless :ref
                  "6df3413964e6a127a404292929795dca0d0819ef"))
 (gptel-autocomplete :source "elpaca-menu-lock-file" :recipe
                     (:source "elpaca-menu-lock-file" :package
                              "gptel-autocomplete" :id
                              gptel-autocomplete :type git :host
                              github :repo
                              "JDNdeveloper/gptel-autocomplete"
                              :protocol https :inherit t :depth
                              treeless :ref
                              "6d2a37fbf514858a98aaa8d90343b1fb4d6b540a"))
 (gptel-prompts :source "elpaca-menu-lock-file" :recipe
                (:source "elpaca-menu-lock-file" :package
                         "gptel-prompts" :id gptel-prompts :type git
                         :host github :repo "jwiegley/gptel-prompts"
                         :protocol https :inherit t :depth treeless
                         :ref
                         "f1c29208c1f0b62918ac6682038da5db4184fc51"))
 (gptel-quick :source "elpaca-menu-lock-file" :recipe
              (:source "elpaca-menu-lock-file" :package "gptel-quick"
                       :id gptel-quick :type git :host github :repo
                       "karthink/gptel-quick" :protocol https :inherit
                       t :depth treeless :ref
                       "018ff2be8f860a1e8fe3966eec418ad635620c38"))
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
                              :source "elpaca-menu-lock-file" :id
                              graphviz-dot-mode :type git :protocol
                              https :inherit t :depth treeless :ref
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
                     :source "elpaca-menu-lock-file" :id hcl-mode
                     :type git :protocol https :inherit t :depth
                     treeless :ref
                     "1da895ed75d28d9f87cbf9b74f075d90ba31c0ed"))
 (helm :source "elpaca-menu-lock-file" :recipe
       (:package "helm" :fetcher github :repo "emacs-helm/helm" :files
                 (:defaults "emacs-helm.sh"
                            (:exclude "helm-lib.el" "helm-source.el"
                                      "helm-multi-match.el"
                                      "helm-core.el"))
                 :source "elpaca-menu-lock-file" :id helm :type git
                 :protocol https :inherit t :depth treeless :ref
                 "9d8de1e0810ef5a5e1f3a46c9461b78b9e86167b"))
 (helm-core :source "elpaca-menu-lock-file" :recipe
            (:package "helm-core" :repo "emacs-helm/helm" :fetcher
                      github :files
                      ("helm-core.el" "helm-lib.el" "helm-source.el"
                       "helm-multi-match.el")
                      :source "elpaca-menu-lock-file" :id helm-core
                      :type git :protocol https :inherit t :depth
                      treeless :ref
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
                           :source "elpaca-menu-lock-file" :id
                           helm-wikipedia :type git :protocol https
                           :inherit t :depth treeless :ref
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
                    :source "elpaca-menu-lock-file" :id helpful :type
                    git :protocol https :inherit t :depth treeless
                    :ref "03756fa6ad4dcca5e0920622b1ee3f70abfc4e39"))
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
                         :source "elpaca-menu-lock-file" :id
                         heroku-theme :type git :protocol https
                         :inherit t :depth treeless :ref
                         "8083643fe92ec3a1c3eb82f1b8dc2236c9c9691d"))
 (hide-mode-line :source "elpaca-menu-lock-file" :recipe
                 (:package "hide-mode-line" :repo
                           "hlissner/emacs-hide-mode-line" :fetcher
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
                           :source "elpaca-menu-lock-file" :id
                           hide-mode-line :type git :protocol https
                           :inherit t :depth treeless :ref
                           "ddd154f1e04d666cd004bf8212ead8684429350d"))
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
                      :source "elpaca-menu-lock-file" :id highlight
                      :type git :protocol https :inherit t :depth
                      treeless :ref
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
                                    :source "elpaca-menu-lock-file"
                                    :id highlight-indent-guides :type
                                    git :protocol https :inherit t
                                    :depth treeless :ref
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
                    :source "elpaca-menu-lock-file" :id hl-todo :type
                    git :protocol https :inherit t :depth treeless
                    :ref "9540fc414014822dde00f0188b74e17ac99e916d"))
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
                  :source "elpaca-menu-lock-file" :id hsluv :type git
                  :protocol https :inherit t :depth treeless :ref
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
               :source "elpaca-menu-lock-file" :id ht :type git
               :protocol https :inherit t :depth treeless :ref
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
                    :source "elpaca-menu-lock-file" :id htmlize :type
                    git :protocol https :inherit t :depth treeless
                    :ref "fa644880699adea3770504f913e6dddbec90c076"))
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
                          :source "elpaca-menu-lock-file" :id
                          hungry-delete :type git :protocol https
                          :inherit t :depth treeless :ref
                          "d919e555e5c13a2edf4570f3ceec84f0ade71657"))
 (hydra :source "elpaca-menu-lock-file" :recipe
        (:package "hydra" :repo "abo-abo/hydra" :fetcher github :files
                  (:defaults (:exclude "lv.el")) :source
                  "elpaca-menu-lock-file" :id hydra :type git
                  :protocol https :inherit t :depth treeless :ref
                  "59a2a45a35027948476d1d7751b0f0215b1e61aa"))
 (hyperbole :source "elpaca-menu-lock-file" :recipe
            (:package "hyperbole" :url
                      "https://git.savannah.gnu.org/git/hyperbole.git"
                      :fetcher git :files
                      ("*.el" "MANIFEST" "dir" "ChangeLog" "Makefile"
                       "HY-ABOUT" "HY-ANNOUNCE" "HY-CONCEPTS.kotl"
                       "HY-NEWS" "HY-WHY.kotl" "INSTALL" "DEMO"
                       "DEMO-ROLO.otl" "FAST-DEMO" "README.md" "_hypb"
                       ".hypb" "hyrolo.py" "smart-clib-sym"
                       "topwin.py" "hyperbole-banner.png"
                       ("kotl" "kotl/MANIFEST" "kotl/EXAMPLE.kotl"
                        "kotl/*.el")
                       ("man" "man/hyperbole.texi" "man/hyperbole.css"
                        "man/hkey-help.txt" "man/hyperbole.info"
                        "man/hyperbole.html" "man/hyperbole.pdf")
                       ("man/im" "man/im/*.png")
                       ("HY-TALK" "HY-TALK/.hypb" "HY-TALK/HYPB"
                        "HY-TALK/HY-TALK.org" "HY-TALK/HYPERAMP.org"
                        "HY-TALK/HYPERORG.org")
                       ("test" "test/MANIFEST" "test/*tests.el"
                        "test/hy-test-*.el"))
                      :source "elpaca-menu-lock-file" :id hyperbole
                      :type git :protocol https :inherit t :depth
                      treeless :ref
                      "f076ff8c5997e9e9401d02da5034c1c10ba070f4"))
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
                  :source "elpaca-menu-lock-file" :id iedit :type git
                  :protocol https :inherit t :depth treeless :ref
                  "14161daa295332a49dda92b97c00d62efd38acfe"))
 (ivy :source "elpaca-menu-lock-file" :recipe
      (:package "ivy" :repo "abo-abo/swiper" :fetcher github :files
                (:defaults "doc/ivy-help.org"
                           (:exclude "swiper.el" "counsel.el"
                                     "ivy-hydra.el" "ivy-avy.el"))
                :source "elpaca-menu-lock-file" :id ivy :type git
                :protocol https :inherit t :depth treeless :ref
                "1005bff8a700b92dc464f770aff8a0db5b4a1c0b"))
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
                         :source "elpaca-menu-lock-file" :id
                         jbeans-theme :type git :protocol https
                         :inherit t :depth treeless :ref
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
                     :source "elpaca-menu-lock-file" :id js2-mode
                     :type git :protocol https :inherit t :depth
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
                      :source "elpaca-menu-lock-file" :id json-mode
                      :type git :protocol https :inherit t :depth
                      treeless :ref
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
                          :source "elpaca-menu-lock-file" :id
                          json-snatcher :type git :protocol https
                          :inherit t :depth treeless :ref
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
                    :source "elpaca-menu-lock-file" :id jsonian :type
                    git :protocol https :inherit t :depth treeless
                    :ref "513219ebb3ccdefc915715e4bf2dd6e718fabccd"))
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
                      :source "elpaca-menu-lock-file" :id key-chord
                      :type git :protocol https :inherit t :depth
                      treeless :ref
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
                     :source "elpaca-menu-lock-file" :id key-quiz
                     :type git :protocol https :inherit t :depth
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
                    :source "elpaca-menu-lock-file" :id keycast :type
                    git :protocol https :inherit t :depth treeless
                    :ref "b831e380c4deb1d51ce5db0a965b96427aec52e4"))
 (kirigami :source "elpaca-menu-lock-file" :recipe
           (:package "kirigami" :fetcher github :repo
                     "jamescherti/kirigami.el" :files
                     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                      "doc/*.texinfo" "lisp/*.el" "docs/dir"
                      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                      (:exclude ".dir-locals.el" "test.el" "tests.el"
                                "*-test.el" "*-tests.el" "LICENSE"
                                "README*" "*-pkg.el"))
                     :source "elpaca-menu-lock-file" :id kirigami
                     :type git :protocol https :inherit t :depth
                     treeless :ref
                     "b7069a4b0126321c263552d5f6133a503bf4a68f"))
 (know-your-http-well :source "elpaca-menu-lock-file" :recipe
                      (:package "know-your-http-well" :fetcher github
                                :repo "for-GET/know-your-http-well"
                                :files ("emacs/*.el") :source
                                "elpaca-menu-lock-file" :id
                                know-your-http-well :type git
                                :protocol https :inherit t :depth
                                treeless :ref
                                "c916e825b0c75c2f2b6ff5ba79c981cff7de5797"))
 (kubel :source "elpaca-menu-lock-file" :recipe
        (:package "kubel" :fetcher github :repo "abrochard/kubel"
                  :files (:defaults (:exclude "kubel-evil.el"))
                  :source "elpaca-menu-lock-file" :id kubel :type git
                  :protocol https :inherit t :depth treeless :ref
                  "7b0a13704675f1bca7d951444c637d4c967e9303"))
 (kubernetes :source "elpaca-menu-lock-file" :recipe
             (:source "elpaca-menu-lock-file" :package "kubernetes"
                      :id kubernetes :host github :repo
                      "kubernetes-el/kubernetes-el" :type git
                      :protocol https :inherit t :depth treeless :ref
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
               :source "elpaca-menu-lock-file" :id kv :type git
               :protocol https :inherit t :depth treeless :ref
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
                      :source "elpaca-menu-lock-file" :id lark-mode
                      :type git :protocol https :inherit t :depth
                      treeless :ref
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
                           :source "elpaca-menu-lock-file" :id
                           lavender-theme :type git :protocol https
                           :inherit t :depth treeless :ref
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
                         :source "elpaca-menu-lock-file" :id
                         leuven-theme :type git :protocol https
                         :inherit t :depth treeless :ref
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
                       :source "elpaca-menu-lock-file" :id list-utils
                       :type git :protocol https :inherit t :depth
                       treeless :ref
                       "bbea0e7cc7ab7d96e7f062014bde438aa8ffcd43"))
 (llama :source "elpaca-menu-lock-file" :recipe
        (:package "llama" :fetcher github :repo "tarsius/llama" :files
                  ("llama.el" ".dir-locals.el") :source
                  "elpaca-menu-lock-file" :id llama :type git
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
                  :source "elpaca-menu-lock-file" :id log4e :type git
                  :protocol https :inherit t :depth treeless :ref
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
                       :source "elpaca-menu-lock-file" :id lsp-docker
                       :type git :protocol https :inherit t :depth
                       treeless :ref
                       "ff41f4a76b640d39dc238bacba7f654c297827fa"))
 (lsp-mode :source "elpaca-menu-lock-file" :recipe
           (:package "lsp-mode" :repo "emacs-lsp/lsp-mode" :fetcher
                     github :files (:defaults "clients/*.*") :source
                     "elpaca-menu-lock-file" :id lsp-mode :type git
                     :protocol https :inherit t :depth treeless :ref
                     "9a2513cb40cb7daac87efcc63f35c7e066681808"))
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
                        :source "elpaca-menu-lock-file" :id
                        lsp-pyright :type git :protocol https :inherit
                        t :depth treeless :ref
                        "21b8f487855feb08f7df669b8884fbd5861dca25"))
 (lsp-treemacs :source "elpaca-menu-lock-file" :recipe
               (:package "lsp-treemacs" :repo "emacs-lsp/lsp-treemacs"
                         :fetcher github :files (:defaults "icons")
                         :source "elpaca-menu-lock-file" :id
                         lsp-treemacs :type git :protocol https
                         :inherit t :depth treeless :ref
                         "49df7292c521b4bac058985ceeaf006607b497dd"))
 (lsp-ui :source "elpaca-menu-lock-file" :recipe
         (:package "lsp-ui" :repo "emacs-lsp/lsp-ui" :fetcher github
                   :files (:defaults "lsp-ui-doc.html" "resources")
                   :source "elpaca-menu-lock-file" :id lsp-ui :type
                   git :protocol https :inherit t :depth treeless :ref
                   "ff349658ed69086bd18c336c8a071ba15f7fd574"))
 (lv :source "elpaca-menu-lock-file" :recipe
     (:package "lv" :repo "abo-abo/hydra" :fetcher github :files
               ("lv.el") :source "elpaca-menu-lock-file" :id lv :type
               git :protocol https :inherit t :depth treeless :ref
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
                      :source "elpaca-menu-lock-file" :id macrostep
                      :type git :protocol https :inherit t :depth
                      treeless :ref
                      "d0928626b4711dcf9f8f90439d23701118724199"))
 (magit :source "elpaca-menu-lock-file" :recipe
        (:package "magit" :fetcher github :repo "magit/magit" :files
                  ("lisp/magit*.el" "lisp/git-*.el" "docs/magit.texi"
                   "docs/AUTHORS.md" "LICENSE" ".dir-locals.el"
                   ("git-hooks" "git-hooks/*")
                   (:exclude "lisp/magit-section.el"))
                  :source "elpaca-menu-lock-file" :id magit :type git
                  :protocol https :inherit t :depth treeless :ref
                  "df9e539fc33ad24e2664730530e61c7be5c69d36"))
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
                        :source "elpaca-menu-lock-file" :id
                        magit-popup :type git :protocol https :inherit
                        t :depth treeless :ref
                        "d8585fa39f88956963d877b921322530257ba9f5"))
 (magit-section :source "elpaca-menu-lock-file" :recipe
                (:package "magit-section" :fetcher github :repo
                          "magit/magit" :files
                          ("lisp/magit-section.el"
                           "docs/magit-section.texi"
                           "magit-section-pkg.el")
                          :source "elpaca-menu-lock-file" :id
                          magit-section :type git :protocol https
                          :inherit t :depth treeless :ref
                          "df9e539fc33ad24e2664730530e61c7be5c69d36"))
 (magneto :source "elpaca-menu-lock-file" :recipe
          (:source "elpaca-menu-lock-file" :package "magneto" :id
                   magneto :host github :repo "chiply/magneto" :type
                   git :protocol https :inherit t :depth treeless :ref
                   "e4e2a209e6ca1fb2994ff5808890677b165adcb0"))
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
                       :source "elpaca-menu-lock-file" :id marginalia
                       :type git :protocol https :inherit t :depth
                       treeless :ref
                       "d28a5e5c1a2e5f3e6669b0197f38da84e08f94a0"))
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
                          :source "elpaca-menu-lock-file" :id
                          markdown-mode :type git :protocol https
                          :inherit t :depth treeless :ref
                          "182640f79c3ed66f82f0419f130dffc173ee9464"))
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
                         :source "elpaca-menu-lock-file" :id
                         markdown-toc :type git :protocol https
                         :inherit t :depth treeless :ref
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
                     :source "elpaca-menu-lock-file" :id mastodon
                     :type git :protocol https :inherit t :depth
                     treeless :ref
                     "703f3645417f545df2d2cd07731d5f99ca347229"))
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
                :source "elpaca-menu-lock-file" :id mcp :type git
                :host github :protocol https :inherit t :depth
                treeless :ref
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
                  :source "elpaca-menu-lock-file" :id md4rd :type git
                  :protocol https :inherit t :depth treeless :ref
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
                 :source "elpaca-menu-lock-file" :id meow :type git
                 :protocol https :inherit t :depth treeless :ref
                 "2246f593552c6208bac533de9af04b085fafa6fa"))
 (meow-tree-sitter :source "elpaca-menu-lock-file" :recipe
                   (:package "meow-tree-sitter" :fetcher github :repo
                             "skissue/meow-tree-sitter" :files
                             (:defaults "queries") :source
                             "elpaca-menu-lock-file" :id
                             meow-tree-sitter :host github :type git
                             :protocol https :inherit t :depth
                             treeless :ref
                             "f050dc0867b7a37efc2c6432b33305a0f14b1029"))
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
                         :source "elpaca-menu-lock-file" :id
                         mermaid-mode :type git :protocol https
                         :inherit t :depth treeless :ref
                         "127fad71666faacf4e962a1498f3fe08910cc6c4"))
 (mini-echo :source "elpaca-menu-lock-file" :recipe
            (:package "mini-echo" :fetcher github :repo
                      "eki3z/mini-echo.el" :files
                      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                       "doc/*.texinfo" "lisp/*.el" "docs/dir"
                       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                       (:exclude ".dir-locals.el" "test.el" "tests.el"
                                 "*-test.el" "*-tests.el" "LICENSE"
                                 "README*" "*-pkg.el"))
                      :source "elpaca-menu-lock-file" :id mini-echo
                      :type git :protocol https :inherit t :depth
                      treeless :ref
                      "d5e5ab763184d0eac2b3dc72e1aac4a7b2e6762f"))
 (minimap :source "elpaca-menu-lock-file" :recipe
          (:package "minimap" :repo
                    ("https://github.com/emacsmirror/gnu_elpa"
                     . "minimap")
                    :tar "1.4" :host gnu :branch "externals/minimap"
                    :files ("*" (:exclude ".git")) :source
                    "elpaca-menu-lock-file" :id minimap :type git
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
                           :source "elpaca-menu-lock-file" :id
                           modern-fringes :type git :protocol https
                           :inherit t :depth treeless :ref
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
                         :source "elpaca-menu-lock-file" :id
                         modus-themes :type git :protocol https
                         :inherit t :depth treeless :ref
                         "e5fb7f2229a0f825332360f4d3ad916f632c086f"))
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
                      :source "elpaca-menu-lock-file" :id move-text
                      :type git :protocol https :inherit t :depth
                      treeless :ref
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
                              :source "elpaca-menu-lock-file" :id
                              mu4e-column-faces :type git :protocol
                              https :inherit t :depth treeless :ref
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
                          :source "elpaca-menu-lock-file" :id
                          mu4e-overview :type git :protocol https
                          :inherit t :depth treeless :ref
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
                                 :source "elpaca-menu-lock-file" :id
                                 mu4e-query-fragments :type git
                                 :protocol https :inherit t :depth
                                 treeless :ref
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
                             :source "elpaca-menu-lock-file" :id
                             multiple-cursors :type git :protocol
                             https :inherit t :depth treeless :ref
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
                         :source "elpaca-menu-lock-file" :id
                         mw-thesaurus :type git :protocol https
                         :inherit t :depth treeless :ref
                         "c44d793595c2d0f6789621da457da065920968ac"))
 (nano-theme :source "elpaca-menu-lock-file" :recipe
             (:package "nano-theme" :repo
                       ("https://github.com/rougier/nano-theme"
                        . "nano-theme")
                       :tar "0.3.4" :host gnu :files
                       ("*" (:exclude ".git")) :source
                       "elpaca-menu-lock-file" :id nano-theme :type
                       git :protocol https :inherit t :depth treeless
                       :ref "41ef36999bacbffe43c4a96320ad6bb285b7f09f"))
 (nerd-icons :source "elpaca-menu-lock-file" :recipe
             (:package "nerd-icons" :repo
                       "rainstormstudio/nerd-icons.el" :fetcher github
                       :files (:defaults "data") :source
                       "elpaca-menu-lock-file" :id nerd-icons :type
                       git :protocol https :inherit t :depth treeless
                       :ref "9a7f44db9a53567f04603bc88d05402cad49c64c"))
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
                             :source "elpaca-menu-lock-file" :id
                             nerd-icons-corfu :type git :protocol
                             https :inherit t :depth treeless :ref
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
                       :source "elpaca-menu-lock-file" :id nord-theme
                       :type git :protocol https :inherit t :depth
                       treeless :ref
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
                :source "elpaca-menu-lock-file" :id nov :type git
                :protocol https :inherit t :depth treeless :ref
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
                     :source "elpaca-menu-lock-file" :id numpydoc
                     :type git :protocol https :inherit t :depth
                     treeless :ref
                     "77e2893442c6e20af9c99b9ba2c6c11988fe0e80"))
 (nyan-mode :source "elpaca-menu-lock-file" :recipe
            (:package "nyan-mode" :fetcher github :repo
                      "TeMPOraL/nyan-mode" :files
                      ("nyan-mode.el" "img" "mus") :source
                      "elpaca-menu-lock-file" :id nyan-mode :type git
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
                       :source "elpaca-menu-lock-file" :id ob-mermaid
                       :type git :protocol https :inherit t :depth
                       treeless :ref
                       "30c2da02e3d24dbec0d004d3c6dfe7b381500b05"))
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
                     :source "elpaca-menu-lock-file" :id olivetti
                     :type git :protocol https :inherit t :depth
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
                      :source "elpaca-menu-lock-file" :id orderless
                      :type git :protocol https :inherit t :depth
                      treeless :ref
                      "3a2a32181f7a5bd7b633e40d89de771a5dd88cc7"))
 (org-fragtog :source "elpaca-menu-lock-file" :recipe
              (:package "org-fragtog" :fetcher github :repo
                        "io12/org-fragtog" :files
                        ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                         "*.texinfo" "doc/dir" "doc/*.info"
                         "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
                         "docs/dir" "docs/*.info" "docs/*.texi"
                         "docs/*.texinfo"
                         (:exclude ".dir-locals.el" "test.el"
                                   "tests.el" "*-test.el" "*-tests.el"
                                   "LICENSE" "README*" "*-pkg.el"))
                        :source "elpaca-menu-lock-file" :id
                        org-fragtog :type git :protocol https :inherit
                        t :depth treeless :ref
                        "562f6590843eeab30ac8aa2ced285aff8d590861"))
 (org-jira :source "elpaca-menu-lock-file" :recipe
           (:package "org-jira" :fetcher github :repo
                     "ahungry/org-jira" :files
                     ("jiralib.el" "org-jira.el" "org-jira-sdk.el")
                     :source "elpaca-menu-lock-file" :id org-jira
                     :type git :protocol https :inherit t :depth
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
                     :source "elpaca-menu-lock-file" :id org-mime
                     :type git :protocol https :inherit t :depth
                     treeless :ref
                     "ffaad784a8597ee52842a578c01bd347d3e0281d"))
 (org-noter :source "elpaca-menu-lock-file" :recipe
            (:package "org-noter" :fetcher github :repo
                      "org-noter/org-noter" :files
                      ("*.el" "modules"
                       (:exclude "*-test-utils.el" "*-devel.el"))
                      :source "elpaca-menu-lock-file" :id org-noter
                      :type git :protocol https :inherit t :depth
                      treeless :ref
                      "81765d267e51efd8b4f5b7276000332ba3eabbf5"))
 (org-ql :source "elpaca-menu-lock-file" :recipe
         (:package "org-ql" :fetcher github :repo "alphapapa/org-ql"
                   :files (:defaults (:exclude "helm-org-ql.el"))
                   :source "elpaca-menu-lock-file" :id org-ql :type
                   git :protocol https :inherit t :depth treeless :ref
                   "4b8330a683c43bb4a2c64ccce8cd5a90c8b174ca"))
 (org-ref :source "elpaca-menu-lock-file" :recipe
          (:package "org-ref" :fetcher github :repo "jkitchin/org-ref"
                    :files
                    (:defaults "org-ref.org" "org-ref.bib" "citeproc")
                    :source "elpaca-menu-lock-file" :id org-ref :type
                    git :protocol https :inherit t :depth treeless
                    :ref "dc2481d430906fe2552f9318f4405242e6d37396"))
 (org-remark :source "elpaca-menu-lock-file" :recipe
             (:package "org-remark" :repo
                       ("https://github.com/nobiot/org-remark"
                        . "org-remark")
                       :tar "1.3.0" :host gnu :files
                       ("*" (:exclude ".git")) :source
                       "elpaca-menu-lock-file" :id org-remark :type
                       git :protocol https :inherit t :depth treeless
                       :ref "4389853625f51ef9495ea4317979a73f942f1b00"))
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
                             :source "elpaca-menu-lock-file" :id
                             org-super-agenda :type git :protocol
                             https :inherit t :depth treeless :ref
                             "fb20ad9c8a9705aa05d40751682beae2d094e0fe"))
 (org-transclusion :source "elpaca-menu-lock-file" :recipe
                   (:package "org-transclusion" :repo
                             ("https://github.com/nobiot/org-transclusion"
                              . "org-transclusion")
                             :tar "1.4.0" :host gnu :files
                             ("*" (:exclude ".git")) :source
                             "elpaca-menu-lock-file" :id
                             org-transclusion :type git :protocol
                             https :inherit t :depth treeless :ref
                             "f5dd4c22adc9d30c5d9365c3e6e1bceafabd4db5"))
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
                           :source "elpaca-menu-lock-file" :id
                           org-tree-slide :type git :protocol https
                           :inherit t :depth treeless :ref
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
                          :source "elpaca-menu-lock-file" :id
                          org-web-tools :type git :protocol https
                          :inherit t :depth treeless :ref
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
                    :source "elpaca-menu-lock-file" :id origami :type
                    git :protocol https :inherit t :depth treeless
                    :ref "e558710a975e8511b9386edc81cd6bdd0a5bda74"))
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
                    :source "elpaca-menu-lock-file" :id osx-lib :type
                    git :protocol https :inherit t :depth treeless
                    :ref "7afdb57edd5725e8a66f841a90fa571a4cbb81e7"))
 (ov :source "elpaca-menu-lock-file" :recipe
     (:package "ov" :fetcher github :repo "emacsorphanage/ov" :files
               ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
                "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
                "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
                "docs/*.texinfo"
                (:exclude ".dir-locals.el" "test.el" "tests.el"
                          "*-test.el" "*-tests.el" "LICENSE" "README*"
                          "*-pkg.el"))
               :source "elpaca-menu-lock-file" :id ov :type git
               :protocol https :inherit t :depth treeless :ref
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
                   :source "elpaca-menu-lock-file" :id ox-gfm :type
                   git :protocol https :inherit t :depth treeless :ref
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
                         :source "elpaca-menu-lock-file" :id
                         ox-jekyll-md :type git :protocol https
                         :inherit t :depth treeless :ref
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
                      :source "elpaca-menu-lock-file" :id ox-pandoc
                      :type git :protocol https :inherit t :depth
                      treeless :ref
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
                      :source "elpaca-menu-lock-file" :id ox-reveal
                      :type git :protocol https :inherit t :depth
                      treeless :ref
                      "f55c851bf6aeb1bb2a7f6cf0f2b7bd0e79c4a5a0"))
 (package-tutor :source "elpaca-menu-lock-file" :recipe
                (:source "elpaca-menu-lock-file" :package
                         "package-tutor" :id package-tutor :host
                         github :repo "chiply/package-tutor" :type git
                         :protocol https :inherit t :depth treeless
                         :ref
                         "43c750f085caee77be6bf8904358835fda875e26"))
 (parrot :source "elpaca-menu-lock-file" :recipe
         (:package "parrot" :fetcher github :repo
                   "positron-solutions/parrot" :files
                   (:defaults "img") :source "elpaca-menu-lock-file"
                   :id parrot :type git :host github :protocol https
                   :inherit t :depth treeless :ref
                   "a612b302887be92ba95606c41ac3f7e75aadb33e"))
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
                     :source "elpaca-menu-lock-file" :id parsebib
                     :type git :protocol https :inherit t :depth
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
                   :source "elpaca-menu-lock-file" :id pcache :type
                   git :protocol https :inherit t :depth treeless :ref
                   "e287b5d116679f79789ee9ee22ee213dc6cef68c"))
 (pdf-tools :source "elpaca-menu-lock-file" :recipe
            (:package "pdf-tools" :fetcher github :repo
                      "vedang/pdf-tools" :files
                      (:defaults "README" ("build" "Makefile")
                                 ("build" "server"))
                      :source "elpaca-menu-lock-file" :id pdf-tools
                      :type git :protocol https :inherit t :depth
                      treeless :ref
                      "365f88238f46f9b1425685562105881800f10386"))
 (persist :source "elpaca-menu-lock-file" :recipe
          (:package "persist" :repo
                    ("https://github.com/emacsmirror/gnu_elpa"
                     . "persist")
                    :tar "0.8" :host gnu :branch "externals/persist"
                    :files ("*" (:exclude ".git")) :source
                    "elpaca-menu-lock-file" :id persist :type git
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
                            :source "elpaca-menu-lock-file" :id
                            persistent-soft :type git :protocol https
                            :inherit t :depth treeless :ref
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
                    :source "elpaca-menu-lock-file" :id pfuture :type
                    git :protocol https :inherit t :depth treeless
                    :ref "19b53aebbc0f2da31de6326c495038901bffb73c"))
 (plz :source "elpaca-menu-lock-file"
   :recipe
   (:package "plz" :repo
             ("https://github.com/alphapapa/plz.el.git" . "plz") :tar
             "0.9.1" :host gnu :files
             ("*" (:exclude ".git" "LICENSE")) :source
             "elpaca-menu-lock-file" :id plz :type git :protocol https
             :inherit t :depth treeless :ref
             "e2d07838e3b64ee5ebe59d4c3c9011adefb7b58e"))
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
                       :source "elpaca-menu-lock-file" :id pocket-lib
                       :type git :protocol https :inherit t :depth
                       treeless :ref
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
                          :source "elpaca-menu-lock-file" :id
                          pocket-reader :type git :protocol https
                          :inherit t :depth treeless :ref
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
                       :source "elpaca-menu-lock-file" :id poet-theme
                       :type git :protocol https :inherit t :depth
                       treeless :ref
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
                   :source "elpaca-menu-lock-file" :id poetry :type
                   git :protocol https :inherit t :depth treeless :ref
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
                     :source "elpaca-menu-lock-file" :id polymode
                     :type git :protocol https :inherit t :depth
                     treeless :ref
                     "4604f55cc020c75562526fb76b723e5e242c97c0"))
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
                   :source "elpaca-menu-lock-file" :id popper :type
                   git :protocol https :inherit t :depth treeless :ref
                   "d83b894ee7a9daf7c8e9b864c23d08f1b23d78f6"))
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
                     :source "elpaca-menu-lock-file" :id posframe
                     :type git :protocol https :inherit t :depth
                     treeless :ref
                     "3a80911b2f45ce6926196930bb7d5cc662c7b3c8"))
 (pr-review :source "elpaca-menu-lock-file" :recipe
            (:package "pr-review" :fetcher github :repo
                      "blahgeek/emacs-pr-review" :files
                      (:defaults "graphql") :source
                      "elpaca-menu-lock-file" :id pr-review :type git
                      :protocol https :inherit t :depth treeless :ref
                      "1bb67e6a10869ccef75812f421d35b0366d95cf5"))
 (prescient :source "elpaca-menu-lock-file" :recipe
            (:package "prescient" :fetcher github :repo
                      "radian-software/prescient.el" :files
                      ("prescient.el" "corfu-prescient.el"
                       "vertico-prescient.el")
                      :source "elpaca-menu-lock-file" :id prescient
                      :type git :protocol https :inherit t :depth
                      treeless :ref
                      "87e2d2f2ddf24f591a5f70cc90d2afb4537caa18"))
 (pretty-hydra :source "elpaca-menu-lock-file" :recipe
               (:package "pretty-hydra" :repo
                         "jerrypnz/major-mode-hydra.el" :fetcher
                         github :files ("pretty-hydra.el") :source
                         "elpaca-menu-lock-file" :id pretty-hydra
                         :type git :protocol https :inherit t :depth
                         treeless :ref
                         "2494d71e24b61c1f5ef2dc17885e2f65bf98b3b2"))
 (projection :source "elpaca-menu-lock-file" :recipe
             (:package "projection" :fetcher github :repo
                       "mohkale/projection" :files
                       (:defaults "src/*.el"
                                  "src/projection-multi/*.el"
                                  "src/projection-multi-embark/*.el")
                       :source "elpaca-menu-lock-file" :id projection
                       :type git :protocol https :inherit t :depth
                       treeless :ref
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
                   :source "elpaca-menu-lock-file" :id pubmed :host
                   gitlab :type git :protocol https :inherit t :depth
                   treeless :ref
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
                          :source "elpaca-menu-lock-file" :id
                          python-pytest :type git :protocol https
                          :inherit t :depth treeless :ref
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
                   :source "elpaca-menu-lock-file" :id pyvenv :type
                   git :protocol https :inherit t :depth treeless :ref
                   "31ea715f2164dd611e7fc77b26390ef3ca93509b"))
 (queue :source "elpaca-menu-lock-file" :recipe
        (:package "queue" :repo
                  ("https://github.com/emacsmirror/gnu_elpa" . "queue")
                  :tar "0.2" :host gnu :branch "externals/queue"
                  :files ("*" (:exclude ".git")) :source
                  "elpaca-menu-lock-file" :id queue :type git
                  :protocol https :inherit t :depth treeless :ref
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
                               :source "elpaca-menu-lock-file" :id
                               rainbow-delimiters :type git :protocol
                               https :inherit t :depth treeless :ref
                               "f40ece58df8b2f0fb6c8576b527755a552a5e763"))
 (rainbow-mode :source "elpaca-menu-lock-file" :recipe
               (:package "rainbow-mode" :repo
                         ("https://github.com/emacsmirror/gnu_elpa"
                          . "rainbow-mode")
                         :tar "1.0.6" :host gnu :branch
                         "externals/rainbow-mode" :files
                         ("*" (:exclude ".git")) :source
                         "elpaca-menu-lock-file" :id rainbow-mode
                         :type git :protocol https :inherit t :depth
                         treeless :ref
                         "f7db3b5919f70420a91eb199f8663468de3033f3"))
 (reader :source "elpaca-menu-lock-file" :recipe
         (:source "elpaca-menu-lock-file" :package "reader" :id reader
                  :host codeberg :repo "MonadicSheep/emacs-reader"
                  :files ("*.el" "render-core.dylib") :pre-build
                  ("make" "all") :type git :protocol https :inherit t
                  :depth treeless :ref
                  "98c5046683e997902a83092b65cdb70ab120e000"))
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
                          :source "elpaca-menu-lock-file" :id
                          rebecca-theme :type git :protocol https
                          :inherit t :depth treeless :ref
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
                                :source "elpaca-menu-lock-file" :id
                                recursion-indicator :type git
                                :protocol https :inherit t :depth
                                treeless :ref
                                "4805275937585102aba0047169f047032201c5b9"))
 (repeatable :source "elpaca-menu-lock-file" :recipe
             (:source "elpaca-menu-lock-file" :package "repeatable"
                      :id repeatable :host github :repo
                      "chiply/repeatable" :wait t :type git :protocol
                      https :inherit t :depth treeless :ref
                      "ddc87b36d61c0172ff892da8619c3608e656e6d2"))
 (request :source "elpaca-menu-lock-file"
   :recipe
   (:package "request" :repo "tkf/emacs-request" :fetcher github
             :files ("request.el") :source "elpaca-menu-lock-file" :id
             request :type git :protocol https :inherit t :depth
             treeless :ref "c22e3c23a6dd90f64be536e176ea0ed6113a5ba6"))
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
                      :source "elpaca-menu-lock-file" :id rjsx-mode
                      :type git :protocol https :inherit t :depth
                      treeless :ref
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
              :source "elpaca-menu-lock-file" :id s :type git
              :protocol https :inherit t :depth treeless :ref
              "dda84d38fffdaf0c9b12837b504b402af910d01d"))
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
                        :source "elpaca-menu-lock-file" :id
                        shell-maker :type git :protocol https :inherit
                        t :depth treeless :ref
                        "55f829d179608a3c4b11e86427713d5be7c4bb58"))
 (signel :source "elpaca-menu-lock-file" :recipe
         (:package "signel" :fetcher github :repo "keenban/signel"
                   :files
                   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                    "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                    "doc/*.texinfo" "lisp/*.el" "docs/dir"
                    "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                    (:exclude ".dir-locals.el" "test.el" "tests.el"
                              "*-test.el" "*-tests.el" "LICENSE"
                              "README*" "*-pkg.el"))
                   :source "elpaca-menu-lock-file" :id signel :type
                   git :protocol https :inherit t :depth treeless :ref
                   "5b309ddd8668344310ae7e9f93b6b756da28d9b4"))
 (slack :source "elpaca-menu-lock-file" :recipe
        (:package "slack" :fetcher github :repo
                  "emacs-slack/emacs-slack" :files
                  ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                   "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                   "doc/*.texinfo" "lisp/*.el" "docs/dir"
                   "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                   (:exclude ".dir-locals.el" "test.el" "tests.el"
                             "*-test.el" "*-tests.el" "LICENSE"
                             "README*" "*-pkg.el"))
                  :source "elpaca-menu-lock-file" :id slack :type git
                  :protocol https :inherit t :depth treeless :ref
                  "b4a360cdff4ca5e51a1eb9b1503b390423750a2c"))
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
                        :source "elpaca-menu-lock-file" :id
                        smartparens :type git :protocol https :inherit
                        t :depth treeless :ref
                        "82d2cf084a19b0c2c3812e0550721f8a61996056"))
 (space-tree :source "elpaca-menu-lock-file" :recipe
             (:source "elpaca-menu-lock-file" :package "space-tree"
                      :id space-tree :host github :repo
                      "chiply/space-tree" :type git :protocol https
                      :inherit t :depth treeless :ref
                      "ce075d23879c1527c2a39be8fa8743073b1be087"))
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
                       :source "elpaca-menu-lock-file" :id speed-type
                       :type git :protocol https :inherit t :depth
                       treeless :ref
                       "257fec4d1ed5637300bf0457df8d7e0bbc5b5226"))
 (spinner :source "elpaca-menu-lock-file" :recipe
          (:package "spinner" :repo
                    ("https://github.com/Malabarba/spinner.el"
                     . "spinner")
                    :tar "1.7.4" :host gnu :files
                    ("*" (:exclude ".git")) :source
                    "elpaca-menu-lock-file" :id spinner :type git
                    :protocol https :inherit t :depth treeless :ref
                    "d4647ae87fb0cd24bc9081a3d287c860ff061c21"))
 (spot :source "elpaca-menu-lock-file" :recipe
       (:source "elpaca-menu-lock-file" :package "spot" :id spot :host
                github :repo "chiply/spot" :type git :protocol https
                :inherit t :depth treeless :ref
                "9d9a61c52a57219a056a8f5a70d093c787b91225"))
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
                      :source "elpaca-menu-lock-file" :id spotlight
                      :type git :protocol https :inherit t :depth
                      treeless :ref
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
                  :source "elpaca-menu-lock-file" :id spray :type git
                  :host github :protocol https :inherit t :depth
                  treeless :ref
                  "74d9dcfa2e8b38f96a43de9ab0eb13364300cb46"))
 (sql-indent :source "elpaca-menu-lock-file" :recipe
             (:package "sql-indent" :repo
                       ("https://github.com/alex-hhh/emacs-sql-indent"
                        . "sql-indent")
                       :tar "1.7" :host gnu :files
                       ("*" (:exclude ".git")) :source
                       "elpaca-menu-lock-file" :id sql-indent :type
                       git :protocol https :inherit t :depth treeless
                       :ref "2ed4c6a26b8f3d651ac6231eaafb2565d77c918b"))
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
                       :source "elpaca-menu-lock-file" :id sqlup-mode
                       :type git :protocol https :inherit t :depth
                       treeless :ref
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
                              :source "elpaca-menu-lock-file" :id
                              string-inflection :type git :protocol
                              https :inherit t :depth treeless :ref
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
                       :source "elpaca-menu-lock-file" :id super-save
                       :type git :protocol https :inherit t :depth
                       treeless :ref
                       "dae7cfe4bba83904d1567e14cbbd7ed141ab37a1"))
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
                        :source "elpaca-menu-lock-file" :id
                        svelte-mode :type git :protocol https :inherit
                        t :depth treeless :ref
                        "ac8fba901dc790976f9893e338c8ad1241b897c6"))
 (svg-lib :source "elpaca-menu-lock-file" :recipe
          (:package "svg-lib" :repo
                    ("https://github.com/rougier/svg-lib" . "svg-lib")
                    :tar "0.3" :host gnu :files
                    ("*" (:exclude ".git")) :source
                    "elpaca-menu-lock-file" :id svg-lib :type git
                    :protocol https :inherit t :depth treeless :ref
                    "925ed4a0215c197ba836e7810a93905b34bea777"))
 (svg-line :source "elpaca-menu-lock-file" :recipe
           (:source "elpaca-menu-lock-file" :package "svg-line" :id
                    svg-line :host github :repo "chiply/svg-line"
                    :wait t :type git :protocol https :inherit t
                    :depth treeless :ref
                    "3e607da217758515f058c3f8afa2ac4b0e9d6302"))
 (svg-margin :source "elpaca-menu-lock-file" :recipe
             (:source "elpaca-menu-lock-file" :package "svg-margin"
                      :id svg-margin :host github :repo
                      "chiply/svg-margin" :wait t :type git :protocol
                      https :inherit t :depth treeless :ref
                      "1548736551346fc62bf19d7829806b7aa373b46a"))
 (swagg :source "elpaca-menu-lock-file" :recipe
        (:package "swagg" :fetcher github :repo "isamert/swagg.el"
                  :files
                  ("*.el" "*.el.in" "dir" "*.info" "*.texi"
                   "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
                   "doc/*.texinfo" "lisp/*.el" "docs/dir"
                   "docs/*.info" "docs/*.texi" "docs/*.texinfo"
                   (:exclude ".dir-locals.el" "test.el" "tests.el"
                             "*-test.el" "*-tests.el" "LICENSE"
                             "README*" "*-pkg.el"))
                  :source "elpaca-menu-lock-file" :id swagg :host
                  github :type git :protocol https :inherit t :depth
                  treeless :ref
                  "87bd1f698bc4c77a1c0d6b252e15f4ee345d2afa"))
 (swiper :source "elpaca-menu-lock-file" :recipe
         (:package "swiper" :repo "abo-abo/swiper" :fetcher github
                   :files ("swiper.el") :source
                   "elpaca-menu-lock-file" :id swiper :type git
                   :protocol https :inherit t :depth treeless :ref
                   "1005bff8a700b92dc464f770aff8a0db5b4a1c0b"))
 (sx :source "elpaca-menu-lock-file" :recipe
     (:package "sx" :repo "vermiculus/sx.el" :fetcher github :files
               ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
                "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
                "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
                "docs/*.texinfo"
                (:exclude ".dir-locals.el" "test.el" "tests.el"
                          "*-test.el" "*-tests.el" "LICENSE" "README*"
                          "*-pkg.el"))
               :source "elpaca-menu-lock-file" :id sx :type git
               :protocol https :inherit t :depth treeless :ref
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
                           :source "elpaca-menu-lock-file" :id
                           symbol-overlay :type git :protocol https
                           :inherit t :depth treeless :ref
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
                    :source "elpaca-menu-lock-file" :id tablist :type
                    git :protocol https :inherit t :depth treeless
                    :ref "fcd37147121fabdf003a70279cf86fbe08cfac6f"))
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
                           :source "elpaca-menu-lock-file" :id
                           telephone-line :type git :protocol https
                           :inherit t :depth treeless :ref
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
                   :source "elpaca-menu-lock-file" :id tempel :type
                   git :protocol https :inherit t :depth treeless :ref
                   "add72000e580aaf80e64195412747181fc95d231"))
 (tempel-collection :source "elpaca-menu-lock-file" :recipe
                    (:package "tempel-collection" :repo
                              "Crandel/tempel-collection" :fetcher
                              github :files (:defaults "templates")
                              :source "elpaca-menu-lock-file" :id
                              tempel-collection :type git :protocol
                              https :inherit t :depth treeless :ref
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
                      :source "elpaca-menu-lock-file" :id templatel
                      :type git :protocol https :inherit t :depth
                      treeless :ref
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
                           :source "elpaca-menu-lock-file" :id
                           terraform-mode :type git :protocol https
                           :inherit t :depth treeless :ref
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
                  :source "elpaca-menu-lock-file" :id tokei :type git
                  :protocol https :inherit t :depth treeless :ref
                  "abfef55c00b49bccd97484d11fab93c6ffce7560"))
 (touchtype :source "elpaca-menu-lock-file" :recipe
            (:source "elpaca-menu-lock-file" :package "touchtype" :id
                     touchtype :host github :repo "chiply/touchtype"
                     :type git :protocol https :inherit t :depth
                     treeless :ref
                     "b6110787d1f6c389acc3b69e366b29cbd1285e26"))
 (tp :source "elpaca-menu-lock-file" :recipe
     (:package "tp" :fetcher codeberg :repo "martianh/tp.el" :files
               ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
                "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
                "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
                "docs/*.texinfo"
                (:exclude ".dir-locals.el" "test.el" "tests.el"
                          "*-test.el" "*-tests.el" "LICENSE" "README*"
                          "*-pkg.el"))
               :source "elpaca-menu-lock-file" :id tp :type git
               :protocol https :inherit t :depth treeless :ref
               "cef3fc2daefbbfc29ad02b7e1f39542b57c72fe8"))
 (track-changes :source "elpaca-menu-lock-file" :recipe
                (:package "track-changes" :repo
                          ("https://github.com/emacs-mirror/emacs"
                           . "track-changes")
                          :branch "master" :files
                          ("lisp/emacs-lisp/track-changes.el"
                           (:exclude ".git"))
                          :source "GNU ELPA" :protocol https :inherit
                          t :depth treeless :ref
                          "389be0b24781bdf81679beb39042ff2bd9a1c275"))
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
                                       :source "elpaca-menu-lock-file"
                                       :id trailing-newline-indicator
                                       :host github :type git
                                       :protocol https :inherit t
                                       :depth treeless :ref
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
                      :source "elpaca-menu-lock-file" :id transient
                      :type git :protocol https :inherit t :depth
                      treeless :ref
                      "733c408d94aac9ca1660d14ff3aedc367abcd8ca"))
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
                      :source "elpaca-menu-lock-file" :id tree-mode
                      :type git :protocol https :inherit t :depth
                      treeless :ref
                      "b06078826d5875d74b0e7b7ac47b0d0917610534"))
 (treemacs :source "elpaca-menu-lock-file" :recipe
           (:package "treemacs" :fetcher github :repo
                     "Alexander-Miller/treemacs" :files
                     ("src/elisp/*.el" "src/extra/*.el"
                      "src/scripts/*.py")
                     :source "elpaca-menu-lock-file" :id treemacs
                     :type git :protocol https :inherit t :depth
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
                   :source "elpaca-menu-lock-file" :id treepy :type
                   git :protocol https :inherit t :depth treeless :ref
                   "28f0e2c2c75ea186e8beb570a4a70087926ff80b"))
 (treesit-fold :source "elpaca-menu-lock-file" :recipe
               (:package "treesit-fold" :repo
                         ("https://github.com/emacs-tree-sitter/treesit-fold"
                          . "treesit-fold")
                         :tar "0.2.1" :host nongnu :files
                         ("*" (:exclude ".git")) :source
                         "elpaca-menu-lock-file" :id treesit-fold
                         :type git :protocol https :inherit t :depth
                         treeless :ref
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
               :source "elpaca-menu-lock-file" :id ts :type git
               :protocol https :inherit t :depth treeless :ref
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
                            :source "elpaca-menu-lock-file" :id
                            typescript-mode :type git :protocol https
                            :inherit t :depth treeless :ref
                            "2535780bdb318d86761b9bd21b0347ca6a89628f"))
 (typst-ts-mode :source "elpaca-menu-lock-file" :recipe
                (:package "typst-ts-mode" :repo
                          ("https://codeberg.org/meow_king/typst-ts-mode"
                           . "typst-ts-mode")
                          :tar "0.12.2" :host nongnu :files
                          ("*" (:exclude ".git")) :source
                          "elpaca-menu-lock-file" :id typst-ts-mode
                          :type git :protocol https :inherit t :depth
                          treeless :ref
                          "278562d702de429f5c4369c007913ca0ef1584f3"))
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
                      :source "elpaca-menu-lock-file" :id ucs-utils
                      :type git :protocol https :inherit t :depth
                      treeless :ref
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
                         :source "elpaca-menu-lock-file" :id
                         ultra-scroll :type git :host github :protocol
                         https :inherit t :depth treeless :ref
                         "08758c6772c5fbce54fb74fb5cce080b6425c6ce"))
 (undo-tree :source "elpaca-menu-lock-file" :recipe
            (:package "undo-tree" :repo
                      ("https://gitlab.com/tsc25/undo-tree"
                       . "undo-tree")
                      :tar "0.8.2" :host gnu :files
                      ("*" (:exclude ".git")) :source
                      "elpaca-menu-lock-file" :id undo-tree :type git
                      :protocol https :inherit t :depth treeless :ref
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
                          :source "elpaca-menu-lock-file" :id
                          unicode-fonts :type git :protocol https
                          :inherit t :depth treeless :ref
                          "d4a0648a2206d9a896433817110957b3b9e1c17a"))
 (unidecode :source "elpaca-menu-lock-file" :recipe
            (:package "unidecode" :fetcher github :repo
                      "sindikat/unidecode" :files (:defaults "data")
                      :source "elpaca-menu-lock-file" :id unidecode
                      :type git :protocol https :inherit t :depth
                      treeless :ref
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
                 :source "elpaca-menu-lock-file" :id verb :type git
                 :protocol https :inherit t :depth treeless :ref
                 "40ad1f06aac3373db788aedffd0eba113b80972f"))
 (vertico :source "elpaca-menu-lock-file" :recipe
          (:package "vertico" :repo "minad/vertico" :files
                    (:defaults "extensions/vertico-*.el") :fetcher
                    github :source "elpaca-menu-lock-file" :id vertico
                    :type git :protocol https :inherit t :depth
                    treeless :ref
                    "0b96e8f169653cba6530da1ab0a1c28ffa44b180"))
 (vertico-posframe :source "elpaca-menu-lock-file" :recipe
                   (:package "vertico-posframe" :repo
                             ("https://github.com/tumashu/vertico-posframe"
                              . "vertico-posframe")
                             :tar "0.9.2" :host gnu :files
                             ("*" (:exclude ".git")) :source
                             "elpaca-menu-lock-file" :id
                             vertico-posframe :type git :protocol
                             https :inherit t :depth treeless :ref
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
                        :source "elpaca-menu-lock-file" :id
                        vimish-fold :type git :protocol https :inherit
                        t :depth treeless :ref
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
                                :source "elpaca-menu-lock-file" :id
                                volatile-highlights :type git
                                :protocol https :inherit t :depth
                                treeless :ref
                                "f68ac37451c1226d6f13c1b299ec7516f74888a1"))
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
                     :source "elpaca-menu-lock-file" :id web-mode
                     :type git :protocol https :inherit t :depth
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
                      :source "elpaca-menu-lock-file" :id websocket
                      :type git :protocol https :inherit t :depth
                      treeless :ref
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
                    :source "elpaca-menu-lock-file" :id wfnames :type
                    git :protocol https :inherit t :depth treeless
                    :ref "6ea49841ab76f44c0164b9f4722da2f9d46228da"))
 (wgrep :source "elpaca-menu-lock-file" :recipe
        (:package "wgrep" :fetcher github :repo
                  "mhayashi1120/Emacs-wgrep" :files ("wgrep.el")
                  :source "elpaca-menu-lock-file" :id wgrep :type git
                  :protocol https :inherit t :depth treeless :ref
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
                      :source "elpaca-menu-lock-file" :id which-key
                      :wait t :type git :protocol https :inherit t
                      :depth treeless :ref
                      "38d4308d1143b61e4004b6e7a940686784e51500"))
 (whisper :source "elpaca-menu-lock-file" :recipe
          (:source "elpaca-menu-lock-file" :package "whisper" :id
                   whisper :type git :host github :repo
                   "natrys/whisper.el" :protocol https :inherit t
                   :depth treeless :ref
                   "1858f49e07e5d4b9abb1329d41a2163eddc7c285"))
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
             :source "elpaca-menu-lock-file" :id with-editor :type git
             :protocol https :inherit t :depth treeless :ref
             "64211dcb815f2533ac3d2a7e56ff36ae804d8338"))
 (wombag :source "elpaca-menu-lock-file" :recipe
         (:source "elpaca-menu-lock-file" :package "wombag" :id wombag
                  :host github :repo "karthink/wombag" :type git
                  :protocol https :inherit t :depth treeless :ref
                  "d5e19cc55a7388aa3c158b5c19c885b61da1f63e"))
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
                   :source "elpaca-menu-lock-file" :id wttrin :type
                   git :protocol https :inherit t :depth treeless :ref
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
                        :source "elpaca-menu-lock-file" :id
                        xterm-color :type git :protocol https :inherit
                        t :depth treeless :ref
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
                 :source "elpaca-menu-lock-file" :id yaml :host github
                 :type git :protocol https :inherit t :depth treeless
                 :ref "f2369fb4985ed054be47ae111760ff2075dff72a"))
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
                      :source "elpaca-menu-lock-file" :id yaml-mode
                      :type git :protocol https :inherit t :depth
                      treeless :ref
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
                     :source "elpaca-menu-lock-file" :id yaml-pro
                     :type git :protocol https :inherit t :depth
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
                     :source "elpaca-menu-lock-file" :id yascroll
                     :type git :protocol https :inherit t :depth
                     treeless :ref
                     "c0a302e6a44169c290564174c48298572f418f62"))
 (yasnippet :source "elpaca-menu-lock-file" :recipe
            (:package "yasnippet" :repo "joaotavora/yasnippet"
                      :fetcher github :files
                      ("yasnippet.el" "snippets") :source
                      "elpaca-menu-lock-file" :id yasnippet :type git
                      :protocol https :inherit t :depth treeless :ref
                      "c1e6ff23e9af16b856c88dfaab9d3ad7b746ad37"))
 (yasnippet-snippets :source "elpaca-menu-lock-file" :recipe
                     (:package "yasnippet-snippets" :repo
                               "AndreaCrotti/yasnippet-snippets"
                               :fetcher github :files
                               ("*.el" "snippets" ".nosearch") :source
                               "elpaca-menu-lock-file" :id
                               yasnippet-snippets :type git :protocol
                               https :inherit t :depth treeless :ref
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
                          :source "elpaca-menu-lock-file" :id
                          zenburn-theme :type git :protocol https
                          :inherit t :depth treeless :ref
                          "d9557cf5ab9c03dc70693e3892f5ffdc5d345d22")))
