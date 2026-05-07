# Module Reference

Each module is a directory under `modules/` containing one `.el` file per package configuration. Enable modules in `~/.zetta.el` via `zetta-modules!`.

## :core

Essential Emacs settings and built-in enhancements. Almost always required.

| File | Package | Description |
|------|---------|-------------|
| emacs.el | — | Core Emacs settings (encoding, backups, etc.) |
| simple.el | — | Kill ring, tab-bar format, history |
| utility.el | — | Bibliography paths, helper functions |
| interface.el | — | Font, scrolling, margins, auto-revert |
| desktop.el | desktop | Session persistence |
| remote.el | tramp | Remote file editing |
| security.el | — | Auth sources, GPG |
| keys.el | — | Additional keybinding setup |
| xref.el | xref | Cross-reference navigation |
| project.el | project | Project detection and management |
| persist.el | persist | Persistent variable storage |
| smerge-mode.el | smerge-mode | Merge conflict resolution |
| repeat-mode.el | repeat-mode | Repeatable key sequences |
| saveplace.el | saveplace | Remember cursor position in files |
| savehist.el | savehist | Minibuffer history persistence |
| comint.el | comint | Shell/REPL interaction |
| cleanup.el | — | Whitespace cleanup, buffer hygiene |
| buffer.el | — | Buffer management utilities |
| ibuffer.el | ibuffer | Enhanced buffer list |
| bufler.el | bufler | Rule-based buffer grouping |
| line-utils.el | — | Line manipulation utilities |
| helpful.el | helpful | Better help buffers |
| elisp-mode.el | — | Emacs Lisp enhancements |
| prose.el | — | Prose writing settings |

## :completion

Minibuffer completion framework. The default stack is Vertico + Consult + Orderless + Corfu + Embark.

| File | Package | Description |
|------|---------|-------------|
| completion.el | — | Base completion settings |
| cape.el | cape | Completion-at-point extensions |
| dabbrev.el | dabbrev | Dynamic abbreviation |
| recursion-indicator.el | recursion-indicator | Show minibuffer recursion depth |
| helm.el | helm | Helm framework (legacy) |
| marginalia.el | marginalia | Rich annotations in minibuffer |
| orderless.el | orderless | Space-separated completion matching |
| embark.el | embark | Contextual actions on completions |
| embark-consult.el | embark-consult | Embark + Consult integration |
| consult.el | consult | Search and navigation commands |
| tap.el | tap | Completion tap |
| tap-block.el | tap-block | Block completion |
| vertico.el | vertico | Vertical minibuffer completion UI |
| prescient.el | prescient | Frequency/recency sorting |
| mono-complete.el | mono-complete | Single-candidate completion |
| consult-gh.el | consult-gh | GitHub search via consult |
| consult-lsp.el | consult-lsp | LSP symbols via consult |
| consult-dash.el | consult-dash | Dash docsets via consult |
| consult-ls-git.el | consult-ls-git | Git file search via consult |
| corfu.el | corfu | In-buffer completion popup |

## :ui

Visual appearance, themes, modeline, and display management.

Key packages:
- **Themes**: modus-themes (default), ef-themes, doric-themes, nord, poet, and more
- **Icons**: all-the-icons (+ dired and ibuffer integrations)
- **Modeline**: telephone-line, awesome-tray
- **Visual aids**: rainbow-delimiters, hl-todo, beacon, symbol-overlay, highlight-indent-guides
- **Window**: ace-window integration, tab-line, popper (popup management)
- **Tree view**: treemacs (file explorer sidebar)
- **Fun**: nyan-mode (progress bar cat), parrot (animated parrot)

## :editor

Editing enhancements and modal editing.

Key packages:
- **Evil mode**: evil + evil-collection, evil-surround, evil-exchange, evil-anzu, evil-indent-plus
- **Structural**: smartparens (parentheses), vimish-fold (code folding)
- **Navigation**: avy (jump-to-char), ace-window, dumb-jump
- **Multi-cursor**: iedit, ace-mc
- **Undo**: undo-tree (visual undo history)
- **Snippets**: yasnippet via snippets.el
- **Text**: text-manipulation, move-text, hungry-delete, markdown-toc

## :lang

Language-specific configurations.

| File | Language | Features |
|------|----------|----------|
| python.el | Python | python-ts-mode, poetry venv, LSP, DAP |
| typescript-ts-mode.el | TypeScript | Tree-sitter mode |
| typescript-mode.el | TypeScript | Legacy mode |
| web-mode.el | HTML/CSS/JS | Multi-mode web editing |
| js2-mode.el | JavaScript | Enhanced JS mode |
| rjsx-mode.el | JSX/React | React component editing |
| yaml-mode.el, yaml.el, yaml-pro.el, yaml-path.el | YAML | Multiple YAML tools |
| terraform.el | Terraform | HCL editing + LSP |
| json-mode.el, jsonian.el | JSON | JSON editing |
| sql.el, sqlite.el | SQL | Database interaction |
| sh-script.el | Shell | Bash/Zsh scripting |
| csv-mode.el | CSV | Tabular data |
| treesit.el | — | Tree-sitter grammar management |
| emmet-mode.el | HTML | Emmet abbreviation expansion |
| graphviz-dot-mode.el | Graphviz | DOT graph language |
| svelte.el | Svelte | Svelte components |
| biome.el | — | Biome formatter/linter |
| ein.el | Jupyter | Jupyter notebook integration |

## :tools

Development tools and integrations.

Key packages:
- **Git**: magit, forge, git-gutter, git-link, git-timemachine, blamer, browse-at-remote, embark-vc
- **LSP**: lsp-mode, consult-lsp, lark
- **Docker**: docker, dockerfile-mode, docker-compose-mode
- **Diagnostics**: flycheck, flycheck-indicator
- **Compilation**: compile, multi-compile, fancy-compilation
- **File management**: dired + dired-subtree + dired-ranger
- **Search**: grep, ag, color-rg, wgrep (writable grep)
- **Testing**: python-pytest
- **Docs**: devdocs, know-your-http-well
- **Cloud**: kubernetes-el, kubel, gha (GitHub Actions)
- **Other**: jira, pr-review, detached, tokei, spotlight, ai, alert

## :app

Applications and utilities.

Key packages:
- **Reading**: elfeed (RSS), wombag (Wallabag), nov (EPUB), pocket-reader
- **Social**: mastodon, erc (IRC), md4rd (Reddit), eww (web browser)
- **Music**: spot4e (Spotify)
- **Bookmarks**: bookmark+, bookmark-in-project, dogears, bookmark-view
- **Writing**: olivetti (centered writing), activities (workspace management)
- **Reference**: define-word, mw-thesaurus, pubmed, sx (StackExchange)
- **Productivity**: whisper (speech-to-text), say (text-to-speech)
- **Fun**: flappy-fish, speed-type, spray (speed reading), key-quiz

## :org

Org-mode ecosystem.

| File | Package | Description |
|------|---------|-------------|
| org.el | org | Core org-mode configuration |
| org-ql.el | org-ql | Query language for org headings |
| org-capture.el | org-capture | Quick capture templates |
| org-ref.el | org-ref | Citation and bibliography |
| ob-mermaid.el | ob-mermaid | Mermaid diagrams in org |
| pdf-tools.el | pdf-tools | PDF viewing and annotation |
| biblio.el | biblio | Bibliography search and download |
| citar.el | citar | Citation insertion |
| org-remark.el | org-remark | Annotation highlights |
| org-tree-slide.el | org-tree-slide | Presentations from org |
| org-transclusion.el | org-transclusion | Content transclusion |

## :term

Terminal and process management.

| File | Package | Description |
|------|---------|-------------|
| shell.el | shell | Built-in shell configuration |
| foreman.el | foreman | Process manager integration |
| foreman-conf.el | — | Foreman configuration |
| vterm.el | vterm | Full terminal emulator |
