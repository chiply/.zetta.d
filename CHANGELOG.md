# Changelog

## [0.1.5](https://github.com/chiply/.zetta.d/compare/v0.1.4...v0.1.5) (2026-06-02)


### Features

* migrate config to renamed repeatable package with ** alias ([8a27108](https://github.com/chiply/.zetta.d/commit/8a27108f591d32cb5d849e67be8a7ef084e720dc))

## [0.1.4](https://github.com/chiply/.zetta.d/compare/v0.1.3...v0.1.4) (2026-06-02)


### Features

* **chiply-isr:** semantic completing-read (ISR) demo ([f20f60f](https://github.com/chiply/.zetta.d/commit/f20f60f7c6fa24118be03c0849347b980461b501))
* **embark-by-type:** factor out type-aware embark UX as standalone package ([c58fae1](https://github.com/chiply/.zetta.d/commit/c58fae1113778d7b8112320cc822d3b9f748191d))
* factor out zettapkg packages + test suites + chiply-isr ISR demo ([c389dc1](https://github.com/chiply/.zetta.d/commit/c389dc1875662bbb4d17b1732dae7ff36c57c590))
* **tap-fold:** factor out as standalone package ([82a8260](https://github.com/chiply/.zetta.d/commit/82a8260ebb75147746260e6ea28e7c84c7c3c483))
* **treesit-tap:** factor out as standalone package ([8a2b00c](https://github.com/chiply/.zetta.d/commit/8a2b00c5c729c0564e5116556cba22a557303cf2))
* **zettapkg:** embark-scope nav/jump refinements, test suites, new modules ([ee45912](https://github.com/chiply/.zetta.d/commit/ee4591205ebad9f1625708925fa42fa5d294af79))


### Bug Fixes

* **chiply-isr:** defer consult require to runtime for clean byte-compile ([158cc06](https://github.com/chiply/.zetta.d/commit/158cc06951873f712b472b88bbf33008a927b687))
* **repeatable-lite:** restore portable github recipe ([cd5dc55](https://github.com/chiply/.zetta.d/commit/cd5dc55bf232469568816c240f505097f81bd8d0))

## [0.1.3](https://github.com/chiply/.zetta.d/compare/v0.1.2...v0.1.3) (2026-05-23)


### Features

* faster + more visual target-type picking across avy/embark/tap ([#17](https://github.com/chiply/.zetta.d/issues/17)) ([8849075](https://github.com/chiply/.zetta.d/commit/88490753a6027c08c47ea57c7554bee38264c812))

## [0.1.2](https://github.com/chiply/.zetta.d/compare/v0.1.1...v0.1.2) (2026-05-23)


### Features

* **present:** CLIM-style typed-presentation picker ([18db9f6](https://github.com/chiply/.zetta.d/commit/18db9f610995a100d9e5a8c4668095f0852d3603))
* **present:** CLIM-style typed-presentation picker ([e750ec1](https://github.com/chiply/.zetta.d/commit/e750ec125db85b62c36b0e95ac3f47e1dc64380c))
* **present:** command-map type detection, mode-aware URL finder, stable avy labels ([89cb1f3](https://github.com/chiply/.zetta.d/commit/89cb1f3fec22c58a0376f61bd23b05e2a76a8e33))
* **present:** highlight candidates during picker (CLIM-style) ([e44bc8d](https://github.com/chiply/.zetta.d/commit/e44bc8d7e1be0fcd7da155fcd567251544336ae7))


### Bug Fixes

* **embark:** make zetta-embark--collect-visible-instances handle org-* link types ([19f1435](https://github.com/chiply/.zetta.d/commit/19f14350cd13695d12dffe21c571eb5ed9de0bf8))
* **present,embark:** address Copilot PR review ([17291b9](https://github.com/chiply/.zetta.d/commit/17291b99f22951202a73fee27b96c01f949293e9))


### Performance Improvements

* **embark:** use regex sweep for URL/email visible-instance collection ([5dd9fca](https://github.com/chiply/.zetta.d/commit/5dd9fca3e5bed550451bf51cb348ba2a4402e343))

## [0.1.1](https://github.com/chiply/.zetta.d/compare/v0.1.0...v0.1.1) (2026-05-22)


### Features

* tap/treesit/embark integration for type-aware editing ([#13](https://github.com/chiply/.zetta.d/issues/13)) ([887f6ce](https://github.com/chiply/.zetta.d/commit/887f6ce4bd40f5c0a33cea114f86a3e3df1e8ce5))


### Bug Fixes

* typos in zettapkg ([#11](https://github.com/chiply/.zetta.d/issues/11)) ([972d84c](https://github.com/chiply/.zetta.d/commit/972d84c95387487dee3a32ab5e584a883fe74c15))

## 0.1.0 (2026-05-07)


### Features

* add base face overrides from brushup into user config ([2dd035a](https://github.com/chiply/.zetta.d/commit/2dd035a925bf8fc784e17ae600f7b3bdfb152c20))
* add blinker and keycast modules, overhaul tab-bar layout ([a2563d5](https://github.com/chiply/.zetta.d/commit/a2563d5c22c145d12d81cb1afd5c93b1acf712e0))
* add CI and release-please workflows ([913528b](https://github.com/chiply/.zetta.d/commit/913528b960765d06dfb913633be50b27670c5d80))
* add editorconfig support ([e5ed3f9](https://github.com/chiply/.zetta.d/commit/e5ed3f92480b405681ca58c388def16e1594e22d))
* add embark backend switching and misc config updates ([9e88f46](https://github.com/chiply/.zetta.d/commit/9e88f46793b69391cb09d33d143172c364e12a11))
* add gif-screencast module with ImageMagick 7 support ([7c56e26](https://github.com/chiply/.zetta.d/commit/7c56e26c37987ebef51c25f60b70546cba18846e))
* add system dependency guards to use-package declarations ([0433905](https://github.com/chiply/.zetta.d/commit/0433905f3a430699d4220a446524e3418d939605))
* auto-select best available audio device for whisper ([8c4722d](https://github.com/chiply/.zetta.d/commit/8c4722d4e0a989a87c911bade4c725d40171dfc9))
* Emacs 31 compatibility fixes and config updates ([105e881](https://github.com/chiply/.zetta.d/commit/105e881e48b12d60893b2416c29736f35c85ea73))
* generate elpaca lock file for reproducible builds ([93263e6](https://github.com/chiply/.zetta.d/commit/93263e6bbfa436531906b6f1b149149ce35cb60b))
* **spot:** enable spot-mode in config ([ab8c263](https://github.com/chiply/.zetta.d/commit/ab8c26368ab05449f878d50c18c8f803068ac315))


### Bug Fixes

* add :wait t to which-key so repeatable-lite installs in CI ([1f726d4](https://github.com/chiply/.zetta.d/commit/1f726d4d4518b5dc80bca8568dd45da09cb0b10c))
* add elpa to gitignore ([5365237](https://github.com/chiply/.zetta.d/commit/536523702e33a55c0b83d98fe81fd399e554e118))
* add elpaca failure reasons to CI output and fail on package errors ([6313721](https://github.com/chiply/.zetta.d/commit/63137215adfe2974349173bda2af99c1cc7f3738))
* add elpaca-wait after repeatable-lite install ([397ab67](https://github.com/chiply/.zetta.d/commit/397ab67b117bf1d99a1661d7d114df7871809631))
* add explicit elpaca recipes for monorepo sub-packages ([638dae1](https://github.com/chiply/.zetta.d/commit/638dae127832a609419985fca333061ea2ab5d5a))
* add missing prompts directory for gptel-prompts ([bb7a91c](https://github.com/chiply/.zetta.d/commit/bb7a91c7c0a8f1a82d1ee2d00665d722dd3a21a7))
* add progress logging to elpaca-wait in CI ([81f6dc6](https://github.com/chiply/.zetta.d/commit/81f6dc66fe8967fcf056d92908bc8e3e25b1cde2))
* add repeatable-lite-wrap fallback macro for CI ([403839d](https://github.com/chiply/.zetta.d/commit/403839d5c19faaefb0ccc114437e6a4d5ba09a6e))
* bulk changes ([81fa44d](https://github.com/chiply/.zetta.d/commit/81fa44d4f48df2d5575467ff1b9d6f7f02a1ada1))
* bulk changes ([3dfbb83](https://github.com/chiply/.zetta.d/commit/3dfbb83e271ba4cfa8583428730cc0876c99af96))
* byte-compile modules with packages on load-path ([1dd276f](https://github.com/chiply/.zetta.d/commit/1dd276f773cbd2b518412f68f218f4ef009932e5))
* cache elpaca directory and restore elpaca-wait in CI ([f1cdcf9](https://github.com/chiply/.zetta.d/commit/f1cdcf9e470337b0e4f73e1637bfd2f4ce7503fc))
* **ci:** use snapshot for Emacs 31 (nix attribute name) ([738db9b](https://github.com/chiply/.zetta.d/commit/738db9bc93b59ab4c4174b8ab86491078fd8df2b))
* correct typos in comments and docstrings ([f758724](https://github.com/chiply/.zetta.d/commit/f7587240d215fce7ab0e9384c2d18006206006b3))
* eliminate first-run prompts for pdf-tools and snippets ([00b3a14](https://github.com/chiply/.zetta.d/commit/00b3a14897e33506aa63013b5305786628924ef7))
* exclude minibuffer from tab-line to prevent redisplay errors ([cbad42e](https://github.com/chiply/.zetta.d/commit/cbad42e75351a1a8007df129614cdf6048df1c12))
* fail ci-test on serious errors (void-function, wrong-type-argument) ([e869f77](https://github.com/chiply/.zetta.d/commit/e869f77768d662ecaae53ec25b2391d0f682faff))
* gracefully handle elpaca-wait timeout instead of aborting ([3e9a031](https://github.com/chiply/.zetta.d/commit/3e9a031fbb0df15357dfc95a78bb7153df71d37e))
* guard horizontal-scroll-bar-mode with fboundp for batch/terminal ([3ccf2da](https://github.com/chiply/.zetta.d/commit/3ccf2da1ee802ea8718f4393c32ff9e437c70c0f))
* guard mcp/copilot-chat for Emacs 30+ (requires emacs 30.1) ([93b69a0](https://github.com/chiply/.zetta.d/commit/93b69a0b2cbdef500c4df6148bda102621c99ac3))
* guard mode-line/header-line against unloaded packages ([dbd238f](https://github.com/chiply/.zetta.d/commit/dbd238fa886bcaed2d01fa2eb6664dffdf11e811))
* guard recursion-indicator brushup style with facep check ([3a18353](https://github.com/chiply/.zetta.d/commit/3a1835356440ec663a04d1ef4eb7e6813cb13400))
* guard repeatable-lite-wrap usage for CI compatibility ([1ee9d5c](https://github.com/chiply/.zetta.d/commit/1ee9d5c2f4278604a1e06afc82dde8ea17c591c6))
* guard scroll-bar-mode for non-GUI Emacs in CI ([51a1a8a](https://github.com/chiply/.zetta.d/commit/51a1a8a5e4b5460f5b99093383f4b914100f10e5))
* improve face contrast for light themes ([9826a01](https://github.com/chiply/.zetta.d/commit/9826a0121fa2857cf925fc75995d6c879b52ce87))
* include lockfile in CI cache key ([e5377a0](https://github.com/chiply/.zetta.d/commit/e5377a0c0b259c484376f7d81bbe84be7831abfb))
* make native compilation in `zetta install` block until complete ([36979e7](https://github.com/chiply/.zetta.d/commit/36979e7c45e7f08c26981a114116179cc02a7474))
* misc changes ([6ffa458](https://github.com/chiply/.zetta.d/commit/6ffa4584a79d83da97fa05daf2f764829b3201f6))
* move signel-account out of repo into ~/.private.el ([6b8219b](https://github.com/chiply/.zetta.d/commit/6b8219bb1fd0118a3076b52d51636fa1987fdd55))
* preserve call-interactively return value in keycast advice ([88e5197](https://github.com/chiply/.zetta.d/commit/88e519741c2749b03d53ddd03bd3c9e85df80376))
* prevent which-key auto-popup and add embark help backend ([4b9db31](https://github.com/chiply/.zetta.d/commit/4b9db31a44e7589c75efeddd7b9fb82377e22ac3))
* remove elpaca-wait from ci-test to prevent CI hang ([7ea03b8](https://github.com/chiply/.zetta.d/commit/7ea03b87c46efdacfc8ac4d00f534ee057ea5fdf))
* repair zetta test daemon detection and keycast face warnings ([a41eb91](https://github.com/chiply/.zetta.d/commit/a41eb91e1896e1a9433110fa740dfc8a31524ec4))
* replace debug messages with proper return values in bootstrap-display.el ([0fb858d](https://github.com/chiply/.zetta.d/commit/0fb858dd248dee40ff36d5a9d230a95740af72f9))
* resolve install errors and update repeatable-lite to v0.2.0 ([8a60a2a](https://github.com/chiply/.zetta.d/commit/8a60a2a0a4235f5e6c1bf5179052b49c1d1a81e9))
* resolve multi-compile crashes and spinner not firing ([aa1f55d](https://github.com/chiply/.zetta.d/commit/aa1f55dd373114c66a07898ea106694200fb87b7))
* serialize elpaca installs by module category to prevent queue overload ([89209a6](https://github.com/chiply/.zetta.d/commit/89209a65c628dcd909405324946a0c6b50269242))
* set tempel-path to avoid directory read error ([c8cb0ce](https://github.com/chiply/.zetta.d/commit/c8cb0ceed4b8fe7b71dba8206c0119cfbaeef4b9))
* silence embark keymap binding errors for async-loaded packages ([1774b6c](https://github.com/chiply/.zetta.d/commit/1774b6c1923664fae6548ca885179a46951e6e50))
* skip vterm in batch mode to prevent CI hang ([6e448d0](https://github.com/chiply/.zetta.d/commit/6e448d05d9c996fd9c1f9dc53650bb4463de78bd))
* slack.md ([616de8f](https://github.com/chiply/.zetta.d/commit/616de8fbf78b655203765b2915bcba8adc1087e5))
* startup fixes and optimizations ([7587183](https://github.com/chiply/.zetta.d/commit/7587183803ae4aa96229929e03fb6b5161f38bf1))
* stop clearing elpaca builds on stale cache restore ([dd46985](https://github.com/chiply/.zetta.d/commit/dd469851588aec5a60f1c85add4540bf8d11dfb7))
* stream ci-test output in real-time for debugging ([3d1b808](https://github.com/chiply/.zetta.d/commit/3d1b808b4d2533964d7a29554a64e2af1f4c0118))
* suppress first-run compilation prompts for pdf-tools and vterm ([22c9aa7](https://github.com/chiply/.zetta.d/commit/22c9aa7379d645d56842c35dd7d19e98c3ab8d92))
* switch magneto and touchtype to GitHub remotes ([a5bae00](https://github.com/chiply/.zetta.d/commit/a5bae00b8ae2b9e8877475c048f331b0d518c26a))
* update magneto binding to use magneto-compose ([535ab27](https://github.com/chiply/.zetta.d/commit/535ab27272632fb1605deaf26e5cc8162a9653d3))
* use :ensure nil for monorepo sub-packages to avoid deadlock ([2156a41](https://github.com/chiply/.zetta.d/commit/2156a417cef82d47946820ced729ed4e9865aff8))
* use :wait t in repeatable-lite recipe for CI cache compatibility ([c589f79](https://github.com/chiply/.zetta.d/commit/c589f7983fce321fcc3219c165c0622ddeddd5d6))
* use defvar for CI timer to avoid void-variable in dynamic scope ([6f9e40b](https://github.com/chiply/.zetta.d/commit/6f9e40ba9db4f63b94093b94d8fb102a1595cd4e))
* use internal capture and colon-safe filenames for gif-screencast ([d5c5d70](https://github.com/chiply/.zetta.d/commit/d5c5d708c6936b56a6c46fb5e717d97b8c566612))
* use real elpaca-wait with timer-based progress logging ([d43c4c5](https://github.com/chiply/.zetta.d/commit/d43c4c5500640870e4d4c7ce99c1cd4f3be948c9))
* wrap mcp/copilot-chat in (when) to prevent elpaca queuing on Emacs &lt;30 ([75d0c49](https://github.com/chiply/.zetta.d/commit/75d0c4924ac94ef36d5a59c2d357c3955f06107b))


### Performance Improvements

* add Doom-inspired startup and runtime optimizations to early-init.el ([3e99430](https://github.com/chiply/.zetta.d/commit/3e994300519456867c53a526226d19b64a58afe5))


### Reverts

* remove editorconfig test package ([9a5712c](https://github.com/chiply/.zetta.d/commit/9a5712c02a9b02f6cb1806b6e4b37b232549b14f))


### Miscellaneous Chores

* reset versioning baseline to 0.0.0 ([50acb5a](https://github.com/chiply/.zetta.d/commit/50acb5ac29f638eae8442f42c93c86e0404fda52))

## Changelog
