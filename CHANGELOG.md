# Changelog

## [0.2.0](https://github.com/chiply/.zetta.d/compare/v0.1.39...v0.2.0) (2026-07-25)


### ⚠ BREAKING CHANGES

* existing installs keep working untouched until they pull this commit, then converge automatically on next start (elpaca re-clones into sources/ and all packages rebuild); a full `bin/zetta install` is the recommended migration path.

### Features

* prebuilt package stores -- CI-published, lock-bound, auto-consumed ([#124](https://github.com/chiply/.zetta.d/issues/124)) ([76360ac](https://github.com/chiply/.zetta.d/commit/76360aceb09b93ef46a2b1753b8e64133e5a8880))
* treeless clones for lock-pinned recipes ([#123](https://github.com/chiply/.zetta.d/issues/123)) ([f4397a8](https://github.com/chiply/.zetta.d/commit/f4397a85a09e01fb21369f367335aae34607e2d1))
* upgrade elpaca pin 1508298 -&gt; 7484867 (2026-07-21 master) ([#121](https://github.com/chiply/.zetta.d/issues/121)) ([dbc4d23](https://github.com/chiply/.zetta.d/commit/dbc4d2373569f560b9b9b7ab5396fbee98bec78d))


### Bug Fixes

* **ci:** package-step resilience — orphan kill, tar tolerance, 150-min ceiling ([#125](https://github.com/chiply/.zetta.d/issues/125)) ([b4aab85](https://github.com/chiply/.zetta.d/commit/b4aab8592a453c9cbc4c1e072ac232a211797059))

## [0.1.39](https://github.com/chiply/.zetta.d/compare/v0.1.38...v0.1.39) (2026-07-23)


### Bug Fixes

* purge eln-cache and stale .elc before install phase 1 ([#119](https://github.com/chiply/.zetta.d/issues/119)) ([80156f7](https://github.com/chiply/.zetta.d/commit/80156f73710cc553b08d842e42719005d8006c8a))

## [0.1.38](https://github.com/chiply/.zetta.d/compare/v0.1.37...v0.1.38) (2026-07-23)


### Bug Fixes

* daemon startup crash + resolve every startup warning at the root ([#117](https://github.com/chiply/.zetta.d/issues/117)) ([f773711](https://github.com/chiply/.zetta.d/commit/f7737110ee278133039445d50080a2417c3d36f7))

## [0.1.37](https://github.com/chiply/.zetta.d/compare/v0.1.36...v0.1.37) (2026-07-23)


### Bug Fixes

* require elpaca in bootstrap-elpaca — compiled bootstrap crashed startup ([#114](https://github.com/chiply/.zetta.d/issues/114)) ([7c10763](https://github.com/chiply/.zetta.d/commit/7c10763b35843b7e6a20c5fb807b2fd2297e9180))

## [0.1.36](https://github.com/chiply/.zetta.d/compare/v0.1.35...v0.1.36) (2026-07-23)


### Features

* typst live-preview module; hyperbole keys; mode-line git-info cache ([#112](https://github.com/chiply/.zetta.d/issues/112)) ([80423ad](https://github.com/chiply/.zetta.d/commit/80423ade8de2f5bcb5ec6d969684705fbb625c46))


### Bug Fixes

* **ci:** survive cold elpaca caches — no git prompts, guard repeatable use ([#109](https://github.com/chiply/.zetta.d/issues/109)) ([51557bc](https://github.com/chiply/.zetta.d/commit/51557bca80d87483900f69638d19f7abee9155ac))
* self-heal elfeed-org startup "database format is outdated" ([#107](https://github.com/chiply/.zetta.d/issues/107)) ([0a5def3](https://github.com/chiply/.zetta.d/commit/0a5def37282511d128faf8715333c3516f72d8c3))

## [0.1.35](https://github.com/chiply/.zetta.d/compare/v0.1.34...v0.1.35) (2026-07-22)


### Features

* **irs:** pipeline, server lifecycle and image search from Emacs ([#106](https://github.com/chiply/.zetta.d/issues/106)) ([0c2724a](https://github.com/chiply/.zetta.d/commit/0c2724addb4746f74f412dc9d5a31363414c9d1e))

## [0.1.34](https://github.com/chiply/.zetta.d/compare/v0.1.33...v0.1.34) (2026-07-14)


### Features

* HyWiki alias disambiguation/plurals/wikify, dag arrows & cleanup, single-letter WikiWords ([#103](https://github.com/chiply/.zetta.d/issues/103)) ([d91d8db](https://github.com/chiply/.zetta.d/commit/d91d8db7e36ee12507eaf348a63f8875da7e7f90))
* irs client — corpus search via the irs backend ([#102](https://github.com/chiply/.zetta.d/issues/102)) ([56695ee](https://github.com/chiply/.zetta.d/commit/56695eebd5d99c89e54b78946b481b2990d2e36d))
* pdfnote — sync native PDF annotations into Logseq notes ([#105](https://github.com/chiply/.zetta.d/issues/105)) ([d823aa4](https://github.com/chiply/.zetta.d/commit/d823aa4992565c137573b44eeff969936eed5b09))

## [0.1.33](https://github.com/chiply/.zetta.d/compare/v0.1.32...v0.1.33) (2026-07-05)


### Bug Fixes

* HyWiki navigation/completion + Corfu icon-row clipping at high text scale ([#100](https://github.com/chiply/.zetta.d/issues/100)) ([3829699](https://github.com/chiply/.zetta.d/commit/3829699d8eb285658994a0afd47bdf5a31a296dd))

## [0.1.32](https://github.com/chiply/.zetta.d/compare/v0.1.31...v0.1.32) (2026-07-04)


### Bug Fixes

* HyWiki empty-dir WikiWord flicker + hidden window vertical-border ([#98](https://github.com/chiply/.zetta.d/issues/98)) ([6ce06a0](https://github.com/chiply/.zetta.d/commit/6ce06a0f07edd0bad786c3f6b3df2023066106bb))

## [0.1.31](https://github.com/chiply/.zetta.d/compare/v0.1.30...v0.1.31) (2026-07-04)


### Features

* **svg-margin:** text-renderer glyph fallback and fixed-lane commands ([#96](https://github.com/chiply/.zetta.d/issues/96)) ([d3ae6ce](https://github.com/chiply/.zetta.d/commit/d3ae6ce1428a791bcf6eeb19abfc81c3ff4fc8d0))

## [0.1.30](https://github.com/chiply/.zetta.d/compare/v0.1.29...v0.1.30) (2026-07-04)


### Features

* **hywiki-alias:** hyphenated forms, manual aliases, and composite WikiWords ([#94](https://github.com/chiply/.zetta.d/issues/94)) ([aafc388](https://github.com/chiply/.zetta.d/commit/aafc388e448782a85cfa461d6e9239a5b5cd4b9a))

## [0.1.29](https://github.com/chiply/.zetta.d/compare/v0.1.28...v0.1.29) (2026-07-03)


### Features

* **hywiki-alias:** distinguish WikiWords that are also links ([#93](https://github.com/chiply/.zetta.d/issues/93)) ([7557946](https://github.com/chiply/.zetta.d/commit/75579465902e48e2d4bc08153c58dd1ccaa920ac))


### Bug Fixes

* **hywiki-alias:** highlight the exact WikiWord form HyWiki misses ([#91](https://github.com/chiply/.zetta.d/issues/91)) ([dfbcbc5](https://github.com/chiply/.zetta.d/commit/dfbcbc5d034d2283743b43b1d5bd6f530a521ac5))

## [0.1.28](https://github.com/chiply/.zetta.d/compare/v0.1.27...v0.1.28) (2026-07-03)


### Features

* **hywiki-alias:** alias single-word WikiWords by default ([#90](https://github.com/chiply/.zetta.d/issues/90)) ([b35ab73](https://github.com/chiply/.zetta.d/commit/b35ab73a98c9f25af02c7fcc643bb763ddc1de39))


### Bug Fixes

* **hywiki-alias:** highlight a new WikiWord's aliases immediately ([#88](https://github.com/chiply/.zetta.d/issues/88)) ([b601954](https://github.com/chiply/.zetta.d/commit/b601954b775edb252324c7746d565f129eff19b0))

## [0.1.27](https://github.com/chiply/.zetta.d/compare/v0.1.26...v0.1.27) (2026-07-02)


### Features

* **hywiki-alias:** derive case/space aliases for HyWikiWords ([#85](https://github.com/chiply/.zetta.d/issues/85)) ([5048459](https://github.com/chiply/.zetta.d/commit/50484597e2882f11acf68c7d739a22a9adc0a446))

## [0.1.26](https://github.com/chiply/.zetta.d/compare/v0.1.25...v0.1.26) (2026-07-01)


### Features

* **hywiki-graph:** text graph view of HyWiki word links ([#81](https://github.com/chiply/.zetta.d/issues/81)) ([22b8cf6](https://github.com/chiply/.zetta.d/commit/22b8cf6ec4be5ad0e46844abd344f240f6161dde))


### Bug Fixes

* **copilot:** scope copilot-mode to real code editing ([#79](https://github.com/chiply/.zetta.d/issues/79)) ([56f4053](https://github.com/chiply/.zetta.d/commit/56f40535db7355fbccafc9fb6682dcad451468db))
* **elfeed:** recover background updates from a negative curl queue counter ([f792e5c](https://github.com/chiply/.zetta.d/commit/f792e5c55068e6358be52a89eddbe05558ea2eaf))
* **embark-vc:** make forge PR the default embark target so `r` opens pr-review ([88bb6f5](https://github.com/chiply/.zetta.d/commit/88bb6f5dc268cb2acfea619fd616f54ec7a234af))
* **hyrolo:** re-root consult-grep handoff for directory search paths ([#80](https://github.com/chiply/.zetta.d/issues/80)) ([f9da21f](https://github.com/chiply/.zetta.d/commit/f9da21f8821f16ac08b3258be021b09f246c0513))

## [0.1.25](https://github.com/chiply/.zetta.d/compare/v0.1.24...v0.1.25) (2026-06-26)


### Features

* **tab-line:** per-tab padding and a subtle inactive-tab background ([#77](https://github.com/chiply/.zetta.d/issues/77)) ([624f35a](https://github.com/chiply/.zetta.d/commit/624f35adf927e86680fb4ce507b2e1f9ed161568))


### Bug Fixes

* **elfeed:** enable protocol before elfeed-org to stop direct-fetch fallback ([#75](https://github.com/chiply/.zetta.d/issues/75)) ([af19e49](https://github.com/chiply/.zetta.d/commit/af19e498f70b44d1612cbcea97267ddfa56fc80f))
* **pdf-tools:** hide hl-line band and evil cursor over the PDF page ([#78](https://github.com/chiply/.zetta.d/issues/78)) ([03d235a](https://github.com/chiply/.zetta.d/commit/03d235aad074ec9a4ae97cd62a30ba85fcb58013))

## [0.1.24](https://github.com/chiply/.zetta.d/compare/v0.1.23...v0.1.24) (2026-06-25)


### Features

* **ui:** circled-number glyphs, coloured active space, modal glyphs, tab-line polish ([#73](https://github.com/chiply/.zetta.d/issues/73)) ([c2d2a00](https://github.com/chiply/.zetta.d/commit/c2d2a00f33001f192beba5a4445dde824048b4d3))

## [0.1.23](https://github.com/chiply/.zetta.d/compare/v0.1.22...v0.1.23) (2026-06-25)


### Bug Fixes

* **elfeed:** unjam stuck curl queue before background pulls ([#71](https://github.com/chiply/.zetta.d/issues/71)) ([b3f822f](https://github.com/chiply/.zetta.d/commit/b3f822f285dcd4ceca97e2d4cedc782ae381226a))
* **svg-margin:** keep the left fringe for line-wrap indicators ([#70](https://github.com/chiply/.zetta.d/issues/70)) ([089f7a7](https://github.com/chiply/.zetta.d/commit/089f7a78b89346b4a06531bf7ea3d958bdaf3ca0))

## [0.1.22](https://github.com/chiply/.zetta.d/compare/v0.1.21...v0.1.22) (2026-06-16)


### Bug Fixes

* **svg-margin:** use the installed Terminess Nerd Font for margin icons ([#68](https://github.com/chiply/.zetta.d/issues/68)) ([d506f7f](https://github.com/chiply/.zetta.d/commit/d506f7f57399f4cb8a44fd616a83273603b58c4d))

## [0.1.21](https://github.com/chiply/.zetta.d/compare/v0.1.20...v0.1.21) (2026-06-16)


### Bug Fixes

* **svg-margin:** draw wrap + scroll indicators in the fringe, not the margin ([#63](https://github.com/chiply/.zetta.d/issues/63)) ([8b63722](https://github.com/chiply/.zetta.d/commit/8b63722bef7b14f5f6170a7aec3624c038af821c))

## [0.1.20](https://github.com/chiply/.zetta.d/compare/v0.1.19...v0.1.20) (2026-06-16)


### Features

* **consult:** keep tab-line steady during jump preview (ripgrep/grep/line) ([3d3f47b](https://github.com/chiply/.zetta.d/commit/3d3f47b029413ce2f7974dfba0dc14c79e0f774f))
* **consult:** keep the tab-line present during buffer preview ([f71d06c](https://github.com/chiply/.zetta.d/commit/f71d06cd9027ab482d08692f7ad2de37e21cd3ac))
* **consult:** option to keep tab-line during elfeed preview ([d4ec49a](https://github.com/chiply/.zetta.d/commit/d4ec49a46feb9fd34ee9e687086de1136dd49268))
* **elfeed:** add zetta-elfeed-prune to shrink the db ([7b7d9ad](https://github.com/chiply/.zetta.d/commit/7b7d9ad4a81f6e9ca4f77ca2986b820877f2a150))
* **elfeed:** background auto-update via elfeed-update-background ([03f5026](https://github.com/chiply/.zetta.d/commit/03f5026267eaea1cec8c815fbce5952c273e3f31))
* **elfeed:** tab-bar refresh indicator + 5min interval ([8fd4067](https://github.com/chiply/.zetta.d/commit/8fd4067740c58a5308eccc92c0aaf44e979d803b))
* **embark-scope:** expand-region nesting levels as expansion targets ([5bd69e4](https://github.com/chiply/.zetta.d/commit/5bd69e4f0da4a4011ce728de83f30f2f7d3baad5))
* **embark:** file-candidate subwords as cyclable identifier targets ([2a56cf3](https://github.com/chiply/.zetta.d/commit/2a56cf3578a9866860d048dcfb043e3f464e9881))
* **embark:** show target type in the minibuffer indicator ([1257796](https://github.com/chiply/.zetta.d/commit/1257796ba284a72a766e93087aa932a575144e13))
* **svg-margin:** rewrite scroll indicator (window-anchored, synchronous) ([eacee7a](https://github.com/chiply/.zetta.d/commit/eacee7a0f2ed33b87d675666aa3646abd4e74f02))
* **svg-margin:** right-margin wrap indicator, reclaim right fringe ([d5ea303](https://github.com/chiply/.zetta.d/commit/d5ea3032ec422fb61df7f2909bc821888116e9ce))
* **tab-bar:** major-mode masthead icon, full-height clock, drop sun/moon/date ([e1017bb](https://github.com/chiply/.zetta.d/commit/e1017bb6971fb82175b3900263c68e36499f8df1))
* **tab-bar:** show +N new elfeed entries from the last pull ([6db27ab](https://github.com/chiply/.zetta.d/commit/6db27abfeb0cea84889f6a5ae1353e66ca40fd1b))
* **tab-bar:** truncate Spotify cluster so it never reaches the centre clock ([55cf79d](https://github.com/chiply/.zetta.d/commit/55cf79dca79c3d5ffdea5e987ce19af0ad640de5))


### Bug Fixes

* **consult:** make preview tab-line advice binding-robust ([09d47dd](https://github.com/chiply/.zetta.d/commit/09d47ddc3ef987619976e6090cc71b53d9999039))
* **consult:** make preview tab-line advice binding-robust ([f3ec986](https://github.com/chiply/.zetta.d/commit/f3ec9867af64875befc363f71c979e7705785b86))
* **consult:** re-hide tab-line on every elfeed preview ([faaa2d3](https://github.com/chiply/.zetta.d/commit/faaa2d3798228a590f897528f387f4c700bd8539))
* **elfeed:** debounce search refresh during updates (THE freeze fix) ([8213aa3](https://github.com/chiply/.zetta.d/commit/8213aa361d6005c8df89322c93c677a7d75bd65d))
* **elfeed:** load elfeed-org after elfeed-protocol (fixes Fever sync) ([1a59b58](https://github.com/chiply/.zetta.d/commit/1a59b580e9bc9d55f7099c42168a4a32cd458a26))
* **elfeed:** stop elfeed-score stats writes freezing updates ([f0f7091](https://github.com/chiply/.zetta.d/commit/f0f7091b5f28c9f9ee34f0ca5db57e1f993d8fd2))
* **elfeed:** stop tab-line flashing on every consult preview ([a52235c](https://github.com/chiply/.zetta.d/commit/a52235cfe96e484897dbcf9a7ccfd4f269069937))


### Performance Improvements

* **elfeed:** cap search buffer at 500 entries ([f8606fe](https://github.com/chiply/.zetta.d/commit/f8606fe09b2d16395cb94fe6e7321f82ddd0225b))
* **gc:** defer collection to idle via gcmh ([616f87d](https://github.com/chiply/.zetta.d/commit/616f87d1a9231550e3ab1c564f0a01656deccd3c))

## [0.1.19](https://github.com/chiply/.zetta.d/compare/v0.1.18...v0.1.19) (2026-06-14)


### Bug Fixes

* **elfeed:** manual preview for zetta-consult-elfeed to stop the freeze ([#58](https://github.com/chiply/.zetta.d/issues/58)) ([aae5188](https://github.com/chiply/.zetta.d/commit/aae51889065d438e1be051459b80e50d95de431f))
* **svg-margin:** don't abort compilation when the package isn't built yet ([#59](https://github.com/chiply/.zetta.d/issues/59)) ([562e123](https://github.com/chiply/.zetta.d/commit/562e12394b1ca7465ee799204a99910109c50109))

## [0.1.18](https://github.com/chiply/.zetta.d/compare/v0.1.17...v0.1.18) (2026-06-14)


### Bug Fixes

* **consult:** hide the tab-line during buffer preview ([#56](https://github.com/chiply/.zetta.d/issues/56)) ([95bced6](https://github.com/chiply/.zetta.d/commit/95bced60461da35d883f310f7440587b9fbc62d1))

## [0.1.17](https://github.com/chiply/.zetta.d/compare/v0.1.16...v0.1.17) (2026-06-13)


### Features

* **elfeed:** incremental updates by default + background auto-update ([#53](https://github.com/chiply/.zetta.d/issues/53)) ([862163f](https://github.com/chiply/.zetta.d/commit/862163fc694c2a5a1f64d8f89900e571c1e9eaf6))
* **keycast,vertico:** accurate command reporting for embark/repeatable chains ([#52](https://github.com/chiply/.zetta.d/issues/52)) ([3533052](https://github.com/chiply/.zetta.d/commit/353305292295ad9a560882b18c12eafc1639d881))

## [0.1.16](https://github.com/chiply/.zetta.d/compare/v0.1.15...v0.1.16) (2026-06-12)


### Features

* **svg-margin:** margin scrollbar provider replacing yascroll's fringe thumb ([#50](https://github.com/chiply/.zetta.d/issues/50)) ([925081d](https://github.com/chiply/.zetta.d/commit/925081d9e543b9d352ba7758d64ccf61ad7fab02))

## [0.1.15](https://github.com/chiply/.zetta.d/compare/v0.1.14...v0.1.15) (2026-06-12)


### Features

* **svg-bench:** add CPU-profiling companion for flamegraphs ([#47](https://github.com/chiply/.zetta.d/issues/47)) ([dde387b](https://github.com/chiply/.zetta.d/commit/dde387bffcf036e91ee03be42b4ad83b7dd4b0a1))
* **ui:** tab-bar sun/moon/clock cluster + circled tab-line numbers ([#49](https://github.com/chiply/.zetta.d/issues/49)) ([a583eb8](https://github.com/chiply/.zetta.d/commit/a583eb8178f84742fae18f1fc1c2db83ecb7ffa3))

## [0.1.14](https://github.com/chiply/.zetta.d/compare/v0.1.13...v0.1.14) (2026-06-11)


### Features

* **svg-bench:** bounce three purple icons in the line animation ([#45](https://github.com/chiply/.zetta.d/issues/45)) ([64ab1eb](https://github.com/chiply/.zetta.d/commit/64ab1eb3e138be1129fe5f3224ccb6aa16fbcb1c))

## [0.1.13](https://github.com/chiply/.zetta.d/compare/v0.1.12...v0.1.13) (2026-06-09)


### Features

* **svg-bench:** add self-contained SVG-vs-native render benchmark ([#43](https://github.com/chiply/.zetta.d/issues/43)) ([6b9b475](https://github.com/chiply/.zetta.d/commit/6b9b475b60dfb26063002cc70fcd9a7a562ba8b2))

## [0.1.12](https://github.com/chiply/.zetta.d/compare/v0.1.11...v0.1.12) (2026-06-08)


### Bug Fixes

* **ui:** clear buffer-local SVG mode line when reverting to telephone-line ([#40](https://github.com/chiply/.zetta.d/issues/40)) ([09e32e0](https://github.com/chiply/.zetta.d/commit/09e32e0b1389366d3280d8816b46e57d45938633))
* **ui:** toggle SVG header line to native breadcrumbs, not nothing ([#37](https://github.com/chiply/.zetta.d/issues/37)) ([bfe5fb0](https://github.com/chiply/.zetta.d/commit/bfe5fb0d5a9629b92a54db6f42fb08e761bdf053))
* **ui:** toggle SVG tab bar to the stock tab-bar.el tabs ([#39](https://github.com/chiply/.zetta.d/issues/39)) ([1c6fea8](https://github.com/chiply/.zetta.d/commit/1c6fea835f81e45a42d7f5cbdddaf236991350ee))

## [0.1.11](https://github.com/chiply/.zetta.d/compare/v0.1.10...v0.1.11) (2026-06-08)


### Features

* **ui:** adopt published svg-line and svg-margin packages from GitHub ([#35](https://github.com/chiply/.zetta.d/issues/35)) ([5137e23](https://github.com/chiply/.zetta.d/commit/5137e2331db2b040b21f4af9e41124663eba0bb5))

## [0.1.10](https://github.com/chiply/.zetta.d/compare/v0.1.9...v0.1.10) (2026-06-07)


### Features

* clickable, hover-aware indicators in the SVG bars and margins ([799780b](https://github.com/chiply/.zetta.d/commit/799780be79035e928aa19b282a56357dabeef8a9))
* **config:** clickable indicators in mode-line, tab-bar and header-line ([68ef349](https://github.com/chiply/.zetta.d/commit/68ef349481e9b47170e2a2de396d60303da722a0))
* **config:** show help-echo in the echo area (no tooltip frame) ([07378be](https://github.com/chiply/.zetta.d/commit/07378beb2a9e747a3d242af3a8fbdeb7396161ec))
* **svg-line:** interactive lines-layout segments (click, menu, hover) ([a6b0378](https://github.com/chiply/.zetta.d/commit/a6b0378c2eab9b017a066c751ea1b0da455407d3))
* **svg-line:** interactive tab-line (click to switch, menu, hover) ([7c9ae4f](https://github.com/chiply/.zetta.d/commit/7c9ae4f2c791850a98e6004578c9bd36c0caca70))
* **svg-margin:** background-on-hover via show-help-function ([fec85ed](https://github.com/chiply/.zetta.d/commit/fec85ed3364c5bb22bb1f3ec51bc91de5b8e2c7b))
* **svg-margin:** contrasting background on the hover help ([c3f0cf5](https://github.com/chiply/.zetta.d/commit/c3f0cf5e8b0e6a0abbdd9bcd30ced637eab6328f))
* **svg-margin:** hover tooltip "click to …" + gutter hover highlight ([e0e7775](https://github.com/chiply/.zetta.d/commit/e0e7775cec501825284366e55f7ae39ef0e742dd))
* **svg-margin:** margin click dispatch, right-click menus, action sets ([482df13](https://github.com/chiply/.zetta.d/commit/482df130f75864c606b3aa76e8fa7dd03d3489ac))
* **svg-margin:** per-indicator clickability + tooltips via image map ([ef6f5b2](https://github.com/chiply/.zetta.d/commit/ef6f5b2ec95a409b9d47109378f42e6496f3a368))


### Bug Fixes

* **svg-line:** defer hover re-render to avoid degrading other lines ([3cce576](https://github.com/chiply/.zetta.d/commit/3cce5766844853962f1592f671c89fe509159092))
* **svg-line:** tab-line hover + tooltip via string-level help-echo ([7dcd7d8](https://github.com/chiply/.zetta.d/commit/7dcd7d89b6a25ee49e8d329327b032cceeb610e1))
* **svg-margin:** drop non-working mouse-face hover highlight ([da6d7cd](https://github.com/chiply/.zetta.d/commit/da6d7cdc60bcf983b3129042718a370fabdc5cf7))
* **svg-margin:** face the per-area help too (background shows over indicator) ([906ea4e](https://github.com/chiply/.zetta.d/commit/906ea4e9e0b1cd03cc967bd709521cc6ff5bf953))
* **svg-margin:** reliable "click to …" tooltip; accept no margin cursor change ([fcb2532](https://github.com/chiply/.zetta.d/commit/fcb25328b4af3f9ae907112c315d04d1ef127c1d))
* **svg-margin:** unique hot-spot ids so hover tracks same-type indicators ([4a27ac2](https://github.com/chiply/.zetta.d/commit/4a27ac28227a6430f344baa8bb6513f53491aa79))

## [0.1.9](https://github.com/chiply/.zetta.d/compare/v0.1.8...v0.1.9) (2026-06-06)


### Features

* SVG line styling — icons, nerd-font glyphs, faces, text-scale + svg-line MELPA prep ([08b6f9c](https://github.com/chiply/.zetta.d/commit/08b6f9c06574e91c46c6a76e54a402bd43adda6a))

## [0.1.8](https://github.com/chiply/.zetta.d/compare/v0.1.7...v0.1.8) (2026-06-06)


### Features

* **config:** set svg-margin minimum widths (left 4, right 2); fix symbol provider ([451e7ba](https://github.com/chiply/.zetta.d/commit/451e7baae1b5a1b501f70539aa047a8b0bf06691))
* **config:** wire svg-margin into my config as a ui module ([6320873](https://github.com/chiply/.zetta.d/commit/632087379ef051772c707802fec94af332ab6160))
* svg-margin — multi-provider SVG margin gutter + config wiring ([e464872](https://github.com/chiply/.zetta.d/commit/e46487230263465907c73106ceafb1a1addf6252))
* **svg-margin:** add five more example providers ([37fe646](https://github.com/chiply/.zetta.d/commit/37fe646b95174a43e0fcb2244b975d9e36ea8542))
* **svg-margin:** example providers for git-gutter, bookmarks; fix diff-hl ([e01aa44](https://github.com/chiply/.zetta.d/commit/e01aa44d58ec3469108cf5d84810d3f480e35536))
* **svg-margin:** make example provider sides configurable (left/right) ([50d4d8a](https://github.com/chiply/.zetta.d/commit/50d4d8aa62fdfb92f09ddd4efdc2c3d03e12c05c))
* **svg-margin:** new package — multi-provider SVG margin gutter ([1e1a05b](https://github.com/chiply/.zetta.d/commit/1e1a05ba907ad9a911f951382db80d62452a869d))
* **svg-margin:** reserve a minimum margin width to stop buffer shifting ([dfe6ac5](https://github.com/chiply/.zetta.d/commit/dfe6ac594a383c889fb2e9fd0c238eeb7f599e85))


### Bug Fixes

* **svg-margin:** address pre-publication review (portability, config, docs) ([45bef2e](https://github.com/chiply/.zetta.d/commit/45bef2e0737e077a4883b9339cddc17fa222dea8))
* **svg-margin:** only reclaim the left fringe in the example setup ([ce22c2a](https://github.com/chiply/.zetta.d/commit/ce22c2a2f977e16fa3ad71129f7c8438c4099e25))
* **svg-margin:** render marks correctly and stop margin flicker ([f8babed](https://github.com/chiply/.zetta.d/commit/f8babedee9d8243280e99468cc40baa56433067b))

## [0.1.7](https://github.com/chiply/.zetta.d/compare/v0.1.6...v0.1.7) (2026-06-05)


### Features

* **ui:** SVG line engine (svg-line) for tab-bar, mode-line, tab-line, header-line ([8876b21](https://github.com/chiply/.zetta.d/commit/8876b21813570fbaea893835978cf4fd6bada4ac))
* **ui:** SVG line engine (svg-line) for tab-bar, mode-line, tab-line, header-line ([184958c](https://github.com/chiply/.zetta.d/commit/184958c1084b2ec7782adfbcb99714238bba59ef))

## [0.1.6](https://github.com/chiply/.zetta.d/compare/v0.1.5...v0.1.6) (2026-06-02)


### Features

* **isr:** semantic + generative ISR demos and fixes ([685e989](https://github.com/chiply/.zetta.d/commit/685e98956b89139fd40ab97104487ca9af1bcb5f))
* **isr:** semantic + generative ISR demos and supporting fixes ([f14a3d8](https://github.com/chiply/.zetta.d/commit/f14a3d87027c77d9496465409788b8d84b9787ee))

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
