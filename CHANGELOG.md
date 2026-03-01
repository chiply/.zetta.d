# Changelog

## [0.1.3](https://github.com/chiply/.zetta.d/compare/v0.1.2...v0.1.3) (2026-03-01)


### Features

* auto-select best available audio device for whisper ([8d0c7cb](https://github.com/chiply/.zetta.d/commit/8d0c7cbe195fc0cdef78fffedd4fc49a8bd1aaaa))

## [0.1.2](https://github.com/chiply/.zetta.d/compare/v0.1.1...v0.1.2) (2026-03-01)


### Bug Fixes

* improve face contrast for light themes ([a5433b7](https://github.com/chiply/.zetta.d/commit/a5433b77365f75f22389f1c89d34ac38ee4a0556))

## [0.1.1](https://github.com/chiply/.zetta.d/compare/v0.1.0...v0.1.1) (2026-02-28)


### Features

* add base face overrides from brushup into user config ([9ea0fe6](https://github.com/chiply/.zetta.d/commit/9ea0fe6430c84b10c63109230128c8b4cc6bcb11))
* add blinker and keycast modules, overhaul tab-bar layout ([82d0992](https://github.com/chiply/.zetta.d/commit/82d09925feffa48e15882b5a144bce983fb66de8))
* add CI and release-please workflows ([fe5c53f](https://github.com/chiply/.zetta.d/commit/fe5c53fbd6a82b37223976114039291306307290))
* add editorconfig support ([735d795](https://github.com/chiply/.zetta.d/commit/735d795eb19e69a2a74cd3fa4b63b7e90f4f77ce))
* add gif-screencast module with ImageMagick 7 support ([073b7e1](https://github.com/chiply/.zetta.d/commit/073b7e131846d6f0135baedbb2fb0a075e296285))
* add system dependency guards to use-package declarations ([e016264](https://github.com/chiply/.zetta.d/commit/e0162646011b12f37d1db4c398ba63e3650097ab))
* generate elpaca lock file for reproducible builds ([51a3a09](https://github.com/chiply/.zetta.d/commit/51a3a09dd05712f11f6d86333e11ba160fa74499))
* **spot:** enable spot-mode in config ([7a3aa21](https://github.com/chiply/.zetta.d/commit/7a3aa21ffcb2298259190d0f1eb7a286ecd2bbc6))


### Bug Fixes

* add :wait t to which-key so repeatable-lite installs in CI ([dc589bb](https://github.com/chiply/.zetta.d/commit/dc589bb5ec109b4473bf622411c22d4ea6290c5c))
* add elpa to gitignore ([e9e5be1](https://github.com/chiply/.zetta.d/commit/e9e5be1a4801715d0133ac663798123b8b6aacae))
* add elpaca failure reasons to CI output and fail on package errors ([4773dbf](https://github.com/chiply/.zetta.d/commit/4773dbfcc9c38fd03ea39559cae781a8d08f58e1))
* add elpaca-wait after repeatable-lite install ([55c27a5](https://github.com/chiply/.zetta.d/commit/55c27a561041f4b389131b7f281e22ee53c0ad91))
* add explicit elpaca recipes for monorepo sub-packages ([45c930c](https://github.com/chiply/.zetta.d/commit/45c930c9d1d3aea09418fbc17bfafe727bbc2995))
* add missing prompts directory for gptel-prompts ([6a21dbc](https://github.com/chiply/.zetta.d/commit/6a21dbc00e1d1bb7563173aec566c51ccd56d99c))
* add progress logging to elpaca-wait in CI ([3779bc2](https://github.com/chiply/.zetta.d/commit/3779bc2549568f3bb8d56d032ee1f5607ef0b320))
* add repeatable-lite-wrap fallback macro for CI ([68d8ed1](https://github.com/chiply/.zetta.d/commit/68d8ed16195e7b17ce5fe24b5072b9ede820b337))
* byte-compile modules with packages on load-path ([5ffbc46](https://github.com/chiply/.zetta.d/commit/5ffbc4644c7fdb8c55fe69330a8d0aa11340fb69))
* cache elpaca directory and restore elpaca-wait in CI ([93131fe](https://github.com/chiply/.zetta.d/commit/93131feea583e6e830f76ac92e7dd81fb26bd5b8))
* correct typos in comments and docstrings ([c448063](https://github.com/chiply/.zetta.d/commit/c448063f83801f361f147462c0ea1c20a55c8777))
* eliminate first-run prompts for pdf-tools and snippets ([cabc688](https://github.com/chiply/.zetta.d/commit/cabc688282cea7c08b24c77e078f06a2f6ae275f))
* exclude minibuffer from tab-line to prevent redisplay errors ([530909b](https://github.com/chiply/.zetta.d/commit/530909b6a59991562efc10c4b5a45c2f49458dab))
* fail ci-test on serious errors (void-function, wrong-type-argument) ([c21fca7](https://github.com/chiply/.zetta.d/commit/c21fca7df1c3c2851ab34242be03a3b2ba4cff70))
* gracefully handle elpaca-wait timeout instead of aborting ([108b435](https://github.com/chiply/.zetta.d/commit/108b4353a00b4c9b0e464dd28e0188c93f0f67ca))
* guard horizontal-scroll-bar-mode with fboundp for batch/terminal ([99a7798](https://github.com/chiply/.zetta.d/commit/99a7798908a3673ee9be6d07608b62c7819f8d06))
* guard mcp/copilot-chat for Emacs 30+ (requires emacs 30.1) ([7eb808b](https://github.com/chiply/.zetta.d/commit/7eb808b0fc637bfaa287247d6a67c76e2eaee4de))
* guard mode-line/header-line against unloaded packages ([ee6ccf3](https://github.com/chiply/.zetta.d/commit/ee6ccf3efbcaedc492e0385876ff346281111158))
* guard recursion-indicator brushup style with facep check ([09d2d50](https://github.com/chiply/.zetta.d/commit/09d2d50a98f01d7717e1069c47e1e452daa9795f))
* guard repeatable-lite-wrap usage for CI compatibility ([ba89b54](https://github.com/chiply/.zetta.d/commit/ba89b54ebee9bd4669ff3e9b95992f0d8e6512dc))
* guard scroll-bar-mode for non-GUI Emacs in CI ([eb048bd](https://github.com/chiply/.zetta.d/commit/eb048bd20beb77176f4fb56f74660ee81bacd1f1))
* include lockfile in CI cache key ([1de4ed4](https://github.com/chiply/.zetta.d/commit/1de4ed4943562bc2a596efb1797cd9a766eb052b))
* make native compilation in `zetta install` block until complete ([fdf4213](https://github.com/chiply/.zetta.d/commit/fdf421360ba9a70583bd16c7b94bf4c3f6f8a550))
* misc changes ([1452a62](https://github.com/chiply/.zetta.d/commit/1452a62d593c459450596c208cd676e6b49859d2))
* preserve call-interactively return value in keycast advice ([043ef9f](https://github.com/chiply/.zetta.d/commit/043ef9f29d9b292acbb6f2abfb9a87890810f1da))
* remove elpaca-wait from ci-test to prevent CI hang ([2cb104a](https://github.com/chiply/.zetta.d/commit/2cb104a0109ef759219290ea105da4adea52fc07))
* repair zetta test daemon detection and keycast face warnings ([55cff64](https://github.com/chiply/.zetta.d/commit/55cff641d785db97d56525b5cbdb956a92999076))
* replace debug messages with proper return values in bootstrap-display.el ([6adf8e9](https://github.com/chiply/.zetta.d/commit/6adf8e947bd004584f02d79d843a02c653a9be54))
* resolve install errors and update repeatable-lite to v0.2.0 ([000d9c9](https://github.com/chiply/.zetta.d/commit/000d9c95ffc859636e7fa0b9755825cc944f6b19))
* serialize elpaca installs by module category to prevent queue overload ([f4ff264](https://github.com/chiply/.zetta.d/commit/f4ff26425e1f37f543c4dcbec33f53dc4cf85c09))
* set tempel-path to avoid directory read error ([434e7ef](https://github.com/chiply/.zetta.d/commit/434e7ef252f3b1fb3fa80b6497020d2fc0e72434))
* silence embark keymap binding errors for async-loaded packages ([e564e20](https://github.com/chiply/.zetta.d/commit/e564e20e6604fb9dbaad07ee9f4090aac61f8e2d))
* skip vterm in batch mode to prevent CI hang ([a7e6a1e](https://github.com/chiply/.zetta.d/commit/a7e6a1e076fcd0bc0f63ef71ab35a49ac995661b))
* startup fixes and optimizations ([aa2528a](https://github.com/chiply/.zetta.d/commit/aa2528af79163a3b3f47f903c1ae1d9150707a0c))
* stop clearing elpaca builds on stale cache restore ([dd8f542](https://github.com/chiply/.zetta.d/commit/dd8f542d9b75e4d70edcbcfe3aa0d45f8f8fceab))
* stream ci-test output in real-time for debugging ([8b8d8e0](https://github.com/chiply/.zetta.d/commit/8b8d8e0b7e702a1671fcbdfad305ab0393b26b4b))
* suppress first-run compilation prompts for pdf-tools and vterm ([4c93bf2](https://github.com/chiply/.zetta.d/commit/4c93bf2a3ed7ab6fdc796e5fa7758c4a140f50b3))
* switch magneto and touchtype to GitHub remotes ([df8637d](https://github.com/chiply/.zetta.d/commit/df8637d89fd4f5d3e8ee0fb04436dcc49009bce3))
* update magneto binding to use magneto-compose ([e3a531a](https://github.com/chiply/.zetta.d/commit/e3a531a81db97a37607e601e56a2dc4177ca6bbc))
* use :ensure nil for monorepo sub-packages to avoid deadlock ([6f72222](https://github.com/chiply/.zetta.d/commit/6f7222221eb9e17f6843f3e55df70073213a54d5))
* use :wait t in repeatable-lite recipe for CI cache compatibility ([3ea5d62](https://github.com/chiply/.zetta.d/commit/3ea5d62cdc0bfa89251543ebd9c6985be0d7dc85))
* use defvar for CI timer to avoid void-variable in dynamic scope ([7d5110a](https://github.com/chiply/.zetta.d/commit/7d5110ae0f25344f06d36f613e51e5c238a325b8))
* use internal capture and colon-safe filenames for gif-screencast ([6d2e6c9](https://github.com/chiply/.zetta.d/commit/6d2e6c9fd8f2a5c7e8ce9020b96caafbeee1319a))
* use real elpaca-wait with timer-based progress logging ([dcbf640](https://github.com/chiply/.zetta.d/commit/dcbf640c6a356cd4515d5fbb521054fff59ebe77))
* wrap mcp/copilot-chat in (when) to prevent elpaca queuing on Emacs &lt;30 ([25fcc08](https://github.com/chiply/.zetta.d/commit/25fcc0862251828e6d9d64a9ced4da8358a90583))


### Performance Improvements

* add Doom-inspired startup and runtime optimizations to early-init.el ([0eed275](https://github.com/chiply/.zetta.d/commit/0eed27503305a390ffb3f5033eac73d826eb9e55))


### Reverts

* remove editorconfig test package ([ae2beac](https://github.com/chiply/.zetta.d/commit/ae2beac6967f9989142e160025efcdf0347b6675))
