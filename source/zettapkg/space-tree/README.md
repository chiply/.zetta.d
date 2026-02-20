# space-tree

Tree-based workspace management for Emacs.

## Overview

space-tree is a library for managing spaces (workspaces) in Emacs. It is inspired by the concept of "workspaces" supported in most major operating systems' window managers, and is intended to be a lightweight but flexible alternative to packages like `tab-bar-mode` and `eyebrowse`.

### Key Features

- **Tree-based structure**: Organize spaces hierarchically with branches of mixed and arbitrary depth
- **Modeline indicator**: Visual indication of the current space and context in the space-tree
- **Navigation commands**: Create, switch, copy, paste, and manage spaces

## Installation

### Using straight.el

```elisp
(straight-use-package
 '(space-tree :type git :host github :repo "chiply/space-tree"))
```

### Using use-package with straight

```elisp
(use-package space-tree
  :straight (:host github :repo "chiply/space-tree")
  :config
  (space-tree-init))
```

### Manual Installation

1. Clone the repository
2. Add to your load-path
3. Require the package

```elisp
(add-to-list 'load-path "/path/to/space-tree")
(require 'space-tree)
(space-tree-init)
```

## Usage

### Basic Commands

| Command | Description |
|---------|-------------|
| `space-tree-init` | Initialize or reset space-tree |
| `space-tree-switch-or-create` | Switch to a space or create it if it doesn't exist |
| `space-tree-create-space-current-level` | Create a new space at the current level |
| `space-tree-create-space-top-level` | Create a new space at the top level |
| `space-tree-delete-space` | Delete a space |
| `space-tree-go-right` | Switch to the next space to the right |
| `space-tree-go-left` | Switch to the next space to the left |
| `space-tree-go-to-last-space` | Switch to the most recently visited space |
| `space-tree-switch-space-by-name` | Switch to a named space |
| `space-tree-name-current-space` | Name the current space |
| `space-tree-copy-workspace` | Copy the current workspace |
| `space-tree-paste-workspace` | Paste the copied workspace |

### Modeline

Add `space-tree-modeline-lighter` to your modeline to see the current space:

```elisp
(setq-default mode-line-format
              '(...
                (:eval (space-tree-modeline-lighter))
                ...))
```

## Example Configuration

Here's an example configuration using `general.el` for keybindings:

```elisp
(use-package space-tree
  :straight (:host github :repo "chiply/space-tree")
  :config
  (space-tree-init)

  ;; Top-level spaces with Super key + number
  (general-define-key
   "s-1" (lambda () (interactive) (space-tree-switch-or-create '(1)))
   "s-2" (lambda () (interactive) (space-tree-switch-or-create '(2)))
   "s-3" (lambda () (interactive) (space-tree-switch-or-create '(3)))
   "s-4" (lambda () (interactive) (space-tree-switch-or-create '(4)))
   "s-5" (lambda () (interactive) (space-tree-switch-or-create '(5)))
   "s-6" (lambda () (interactive) (space-tree-switch-or-create '(6)))
   "s-7" (lambda () (interactive) (space-tree-switch-or-create '(7)))
   "s-8" (lambda () (interactive) (space-tree-switch-or-create '(8)))
   "s-9" (lambda () (interactive) (space-tree-switch-or-create '(9)))

   ;; Second level (within current top-level space)
   "s-a" (lambda () (interactive) (space-tree-switch-or-create `(,(nth 0 space-tree-current-address) 1)))
   "s-s" (lambda () (interactive) (space-tree-switch-or-create `(,(nth 0 space-tree-current-address) 2)))
   "s-d" (lambda () (interactive) (space-tree-switch-or-create `(,(nth 0 space-tree-current-address) 3)))
   "s-f" (lambda () (interactive) (space-tree-switch-or-create `(,(nth 0 space-tree-current-address) 4)))
   "s-g" (lambda () (interactive) (space-tree-switch-or-create `(,(nth 0 space-tree-current-address) 5)))

   ;; Third level (within current second-level space)
   "s-A" (lambda () (interactive) (space-tree-switch-or-create `(,(nth 0 space-tree-current-address) ,(nth 1 space-tree-current-address) 1)))
   "s-S" (lambda () (interactive) (space-tree-switch-or-create `(,(nth 0 space-tree-current-address) ,(nth 1 space-tree-current-address) 2)))
   "s-D" (lambda () (interactive) (space-tree-switch-or-create `(,(nth 0 space-tree-current-address) ,(nth 1 space-tree-current-address) 3)))
   "s-F" (lambda () (interactive) (space-tree-switch-or-create `(,(nth 0 space-tree-current-address) ,(nth 1 space-tree-current-address) 4)))
   "s-G" (lambda () (interactive) (space-tree-switch-or-create `(,(nth 0 space-tree-current-address) ,(nth 1 space-tree-current-address) 5)))

   ;; Navigation
   "M-S-<tab>" 'space-tree-switch-space-by-name
   "M-<tab>" 'space-tree-go-to-last-space
   "C-M-<tab>" 'space-tree-go-right
   "C-M-S-<tab>" 'space-tree-go-left

   ;; Delete current space
   "s-_" (lambda () (interactive) (space-tree-delete-space space-tree-current-address)))

  ;; Evil/vim-style bindings
  (general-define-key
   :states '(normal visual)
   :keymaps 'override
   "gt" 'space-tree-switch-current-level
   "gT" 'space-tree-switch-space-by-digit-arg
   "g+" 'space-tree-create-space-top-level
   "gn" 'space-tree-create-space-current-level))
```

## Customization

### `space-tree-start-at-0`

If non-nil, the first space will be numbered 0. Otherwise, the first space will be numbered 1.

```elisp
(setq space-tree-start-at-0 t)
```

## How It Works

space-tree organizes workspaces in a tree structure. Each node in the tree can have multiple children, allowing for hierarchical organization:

```
Space 1
├── Space 1.1
│   ├── Space 1.1.1
│   └── Space 1.1.2
├── Space 1.2
└── Space 1.3
Space 2
├── Space 2.1
└── Space 2.2
Space 3
```

Each space stores its own window configuration, which is restored when you switch to that space.

## Dependencies

- Emacs 29.1+
- [ht](https://github.com/Wilfred/ht.el) (2.3+)
- [dash](https://github.com/magnars/dash.el) (2.19+)

## License

MIT License. See [LICENSE](LICENSE) for details.
