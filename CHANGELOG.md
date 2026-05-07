# Changelog

## 0.1.0 (2026-05-07)


### Features

* add base face overrides from brushup into user config ([79ec28f](https://github.com/chiply/.zetta.d/commit/79ec28f6b385e5f0700e3ca9c646cebae3acaa69))
* add blinker and keycast modules, overhaul tab-bar layout ([7e42910](https://github.com/chiply/.zetta.d/commit/7e42910e41bed689e8f2a8b34aa8888fc000c887))
* add CI and release-please workflows ([d13ec10](https://github.com/chiply/.zetta.d/commit/d13ec102a68d75ea75124ef5fece3e38f705dac1))
* add editorconfig support ([bb6ad69](https://github.com/chiply/.zetta.d/commit/bb6ad698205e593c4887eaf559abb5e803a1e186))
* add embark backend switching and misc config updates ([33d8d4a](https://github.com/chiply/.zetta.d/commit/33d8d4a560e0ee4c54c1026ded181bd373ced69f))
* add gif-screencast module with ImageMagick 7 support ([eabc74d](https://github.com/chiply/.zetta.d/commit/eabc74d9cadd76aaaed8f18d7297c79c3ec15228))
* add system dependency guards to use-package declarations ([fa8f979](https://github.com/chiply/.zetta.d/commit/fa8f979757c38b1e8d0ac18e8fc78a35f37e4242))
* auto-select best available audio device for whisper ([7a5031f](https://github.com/chiply/.zetta.d/commit/7a5031fcbb3402cd8646c1e4d910a271a74e78d7))
* Emacs 31 compatibility fixes and config updates ([a954479](https://github.com/chiply/.zetta.d/commit/a954479e9d67be3f74817f87cb7b3ec2f9fa48a5))
* generate elpaca lock file for reproducible builds ([c812937](https://github.com/chiply/.zetta.d/commit/c812937404f298b937cd03f0fb370d0ae1dd60c0))
* **spot:** enable spot-mode in config ([b340c37](https://github.com/chiply/.zetta.d/commit/b340c37d3774be5268e6ba02eed5aa36950e5170))


### Bug Fixes

* add :wait t to which-key so repeatable-lite installs in CI ([9fb0dcc](https://github.com/chiply/.zetta.d/commit/9fb0dcc05292367d46253bba8907e4183a438e3a))
* add elpa to gitignore ([a8d816c](https://github.com/chiply/.zetta.d/commit/a8d816cc1c341df5f5ea3d894d681dffc20a2658))
* add elpaca failure reasons to CI output and fail on package errors ([8550a4b](https://github.com/chiply/.zetta.d/commit/8550a4b412e9b01ba1aeb0c06d7b2fb4186dcdc4))
* add elpaca-wait after repeatable-lite install ([4704c98](https://github.com/chiply/.zetta.d/commit/4704c988a4ecb49ad095b384a14280e2b2174605))
* add explicit elpaca recipes for monorepo sub-packages ([3fdc855](https://github.com/chiply/.zetta.d/commit/3fdc855772c593fbf885ac8ffdfbaadbd4eb49a9))
* add missing prompts directory for gptel-prompts ([040150f](https://github.com/chiply/.zetta.d/commit/040150f1cf1edbc95151e0ec090d13b033f98f71))
* add progress logging to elpaca-wait in CI ([9057918](https://github.com/chiply/.zetta.d/commit/905791837fe3e5700708bd3c3acfeeaaae16a088))
* add repeatable-lite-wrap fallback macro for CI ([a489259](https://github.com/chiply/.zetta.d/commit/a4892597cd4242dd663cc9ca641734a5c2560525))
* bulk changes ([4b2b4b0](https://github.com/chiply/.zetta.d/commit/4b2b4b02d81477f55e22d567879cf2c5adc75c78))
* bulk changes ([acebef5](https://github.com/chiply/.zetta.d/commit/acebef5d17aef9fafe73964b5a14cf88ab69f7f3))
* byte-compile modules with packages on load-path ([866fc0b](https://github.com/chiply/.zetta.d/commit/866fc0bf58d7fa0721be45a6bb99e05e04a1949a))
* cache elpaca directory and restore elpaca-wait in CI ([e3015fa](https://github.com/chiply/.zetta.d/commit/e3015fa9333bac98ae395958f2408bb020ce1b6e))
* **ci:** use snapshot for Emacs 31 (nix attribute name) ([532f344](https://github.com/chiply/.zetta.d/commit/532f344c4c1c9a72b92ec9383a91e15d6015d8c5))
* correct typos in comments and docstrings ([710689f](https://github.com/chiply/.zetta.d/commit/710689f37477a2f9eca1688f0f4586e5b5f93690))
* eliminate first-run prompts for pdf-tools and snippets ([7968a36](https://github.com/chiply/.zetta.d/commit/7968a36a734ed519ba0aa7d601147efd07242008))
* exclude minibuffer from tab-line to prevent redisplay errors ([9db2bba](https://github.com/chiply/.zetta.d/commit/9db2bba54f18cc25011e2c105a4a01571338a577))
* fail ci-test on serious errors (void-function, wrong-type-argument) ([a8d119d](https://github.com/chiply/.zetta.d/commit/a8d119d37c9184cee0a0882fa55a2a76bf75bd1f))
* gracefully handle elpaca-wait timeout instead of aborting ([0e8883d](https://github.com/chiply/.zetta.d/commit/0e8883d1c484928579924566173b341a943aa7bf))
* guard horizontal-scroll-bar-mode with fboundp for batch/terminal ([8aa2e3c](https://github.com/chiply/.zetta.d/commit/8aa2e3c87cac056824a4f7fe93234cde4d53e5c3))
* guard mcp/copilot-chat for Emacs 30+ (requires emacs 30.1) ([6ef8633](https://github.com/chiply/.zetta.d/commit/6ef86330837e9f19c10c4e688bf0cbd8d282e061))
* guard mode-line/header-line against unloaded packages ([b35d48e](https://github.com/chiply/.zetta.d/commit/b35d48e54045fc5ad74a56e7ec0c38c936e450ca))
* guard recursion-indicator brushup style with facep check ([db3eb7d](https://github.com/chiply/.zetta.d/commit/db3eb7df8981291ffce1de256ccb6a80186d4680))
* guard repeatable-lite-wrap usage for CI compatibility ([71ebbfd](https://github.com/chiply/.zetta.d/commit/71ebbfd072ea8198a89d544076f9404d97ca1221))
* guard scroll-bar-mode for non-GUI Emacs in CI ([43c732e](https://github.com/chiply/.zetta.d/commit/43c732e65388f825df5708fe0ba24cab4425d77d))
* improve face contrast for light themes ([1d3bdb7](https://github.com/chiply/.zetta.d/commit/1d3bdb79cdd5bd1a8252966ca721d8ec93183f84))
* include lockfile in CI cache key ([5c322f5](https://github.com/chiply/.zetta.d/commit/5c322f519a344f403e6a08563d44fdbb966801c9))
* make native compilation in `zetta install` block until complete ([fd354db](https://github.com/chiply/.zetta.d/commit/fd354dbd2c4148a9d3758f7c4650698d175ce7ee))
* misc changes ([c39c1af](https://github.com/chiply/.zetta.d/commit/c39c1af6d2cbf8b9d46f22460247c72f1c4ee794))
* preserve call-interactively return value in keycast advice ([a0a5a9d](https://github.com/chiply/.zetta.d/commit/a0a5a9dc296ce0e206a357f18fe1b4ec343d319c))
* prevent which-key auto-popup and add embark help backend ([5763bca](https://github.com/chiply/.zetta.d/commit/5763bcaa8b5a6c663976e54d149613c1dc2176ab))
* remove elpaca-wait from ci-test to prevent CI hang ([f0edba9](https://github.com/chiply/.zetta.d/commit/f0edba993a71b0c5c572b011b642c5379e401ab6))
* repair zetta test daemon detection and keycast face warnings ([d3678f5](https://github.com/chiply/.zetta.d/commit/d3678f5d22c9b38a98a7091c734e48627b599898))
* replace debug messages with proper return values in bootstrap-display.el ([c999dc6](https://github.com/chiply/.zetta.d/commit/c999dc6bb381003b7e20c55a97d95503ecb11614))
* resolve install errors and update repeatable-lite to v0.2.0 ([46bf3cc](https://github.com/chiply/.zetta.d/commit/46bf3cc6e5bc0cd48730b40cec48fd43d2bc6a4d))
* resolve multi-compile crashes and spinner not firing ([2d925fb](https://github.com/chiply/.zetta.d/commit/2d925fbe13b2acdadb79669d879e052e7b9622d4))
* serialize elpaca installs by module category to prevent queue overload ([5547339](https://github.com/chiply/.zetta.d/commit/5547339d9ca960dd526847f08aaf77ea82fb7562))
* set tempel-path to avoid directory read error ([5007fba](https://github.com/chiply/.zetta.d/commit/5007fbaaf339741f9a554909072186c2a7e05005))
* silence embark keymap binding errors for async-loaded packages ([bffbe6d](https://github.com/chiply/.zetta.d/commit/bffbe6da7de36ffab963d5126a485de73030d397))
* skip vterm in batch mode to prevent CI hang ([0dd37b0](https://github.com/chiply/.zetta.d/commit/0dd37b0114ad42783266f5ad8fe6994df1f4db73))
* slack.md ([1dbc95e](https://github.com/chiply/.zetta.d/commit/1dbc95e6fe1bac33a9e979250d854c23136ef5fc))
* startup fixes and optimizations ([ae533b2](https://github.com/chiply/.zetta.d/commit/ae533b2f7d4446a5f8355e6f4c87a29ee9b2c088))
* stop clearing elpaca builds on stale cache restore ([e079245](https://github.com/chiply/.zetta.d/commit/e079245049cfc12b251f17f6cde70d6b476c1e90))
* stream ci-test output in real-time for debugging ([624a9e3](https://github.com/chiply/.zetta.d/commit/624a9e39f45697725fcf1537e16906de6c1f514a))
* suppress first-run compilation prompts for pdf-tools and vterm ([39b2dc7](https://github.com/chiply/.zetta.d/commit/39b2dc797ef37ef7e284138e9dcf583103a9970b))
* switch magneto and touchtype to GitHub remotes ([2773297](https://github.com/chiply/.zetta.d/commit/2773297a07113519d39f0410f51768fac860c07a))
* update magneto binding to use magneto-compose ([02e0668](https://github.com/chiply/.zetta.d/commit/02e0668aa420f6d6654428e56755208e56d7a6d7))
* use :ensure nil for monorepo sub-packages to avoid deadlock ([d34218e](https://github.com/chiply/.zetta.d/commit/d34218e129af084cdc9bd0790bc13fb09007165c))
* use :wait t in repeatable-lite recipe for CI cache compatibility ([0e38940](https://github.com/chiply/.zetta.d/commit/0e38940405550984a0bc9d4613b4637ee9f828f8))
* use defvar for CI timer to avoid void-variable in dynamic scope ([0db0363](https://github.com/chiply/.zetta.d/commit/0db0363b2130ead03ffd1c8c78c340ac76336754))
* use internal capture and colon-safe filenames for gif-screencast ([4bde36e](https://github.com/chiply/.zetta.d/commit/4bde36e09e6825368a7b7a512b1397011b682224))
* use real elpaca-wait with timer-based progress logging ([eb04eb4](https://github.com/chiply/.zetta.d/commit/eb04eb470b38b256ee90f394311b91e046d0f114))
* wrap mcp/copilot-chat in (when) to prevent elpaca queuing on Emacs &lt;30 ([9fd39de](https://github.com/chiply/.zetta.d/commit/9fd39deb04dee749219b2151de4cc8fe61b869a3))


### Performance Improvements

* add Doom-inspired startup and runtime optimizations to early-init.el ([19b9fc7](https://github.com/chiply/.zetta.d/commit/19b9fc716857f3a25d4c6eb14806e6fec7a4fd12))


### Reverts

* remove editorconfig test package ([3a608b5](https://github.com/chiply/.zetta.d/commit/3a608b5f8db02847cb229c78ea50db765ee51743))


### Miscellaneous Chores

* reset versioning baseline to 0.0.0 ([5d23310](https://github.com/chiply/.zetta.d/commit/5d2331026f584a91812fb8f371b96ddc23fd502b))

## Changelog
