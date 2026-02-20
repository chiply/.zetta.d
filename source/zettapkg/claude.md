# Deploying Elisp Packages as Open Source Projects

This guide documents best practices for deploying Emacs Lisp packages from this monorepo as standalone open source projects on GitHub. Based on lessons learned from deploying `spot.el`.

## Project Structure

```
package-name/
├── .github/
│   └── workflows/
│       ├── ci.yml              # Main CI workflow
│       └── release.yml         # Release-please workflow
├── package-name.el             # Main entry point
├── package-name-*.el           # Supporting modules
├── Eask                        # Build configuration
├── .gitignore
├── LICENSE
├── README.md
├── version.txt                 # For release-please
├── release-please-config.json
└── .release-please-manifest.json
```

## Eask Configuration

### Basic Template

```elisp
; -*- lexical-binding: t -*-

(package "package-name"
         "0.1.0"
         "Short description without 'for Emacs'")  ; Don't include "for Emacs" - it's redundant

(website-url "https://github.com/username/package-name")
(keywords "relevant" "keywords")

(package-file "package-name.el")

;; List files explicitly if you need to exclude optional integrations
;; Eask does NOT support (:exclude ...) syntax
(files "package-name.el"
       "package-name-core.el"
       "package-name-utils.el")
;; OR use wildcard if all .el files should be included:
;; (files "*.el")

(script "test" "echo \"No tests yet\"")

(source "gnu")
(source "melpa")

(depends-on "emacs" "29.1")  ; Match your actual minimum version
(depends-on "dependency" "version")

(development
 (depends-on "package-lint"))
```

### Key Points

1. **Always include lexical-binding cookie** at the top: `; -*- lexical-binding: t -*-`
2. **Package description should NOT include "for Emacs"** - package-lint will warn
3. **List files explicitly** if you have optional integrations to exclude
4. **Match Emacs version to dependencies** - check what your dependencies require (e.g., `consult` requires Emacs 29.1+)

## Elisp File Headers

### Main Package File

```elisp
;;; package-name.el --- Short description -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Your Name

;; Author: Your Name <email@example.com>
;; Maintainer: Your Name <email@example.com>
;; URL: https://github.com/username/package-name
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1") (dep1 "1.0") (dep2 "2.0"))
;; Keywords: relevant, keywords

;;; Commentary:
;; Description of the package.

;;; Code:

(require 'package-name-utils)
;; ... requires ...

;; ... code ...

(provide 'package-name)

;;; package-name.el ends here
```

## Package-Lint Requirements

### Function Naming

All public and private functions MUST have the package prefix:

```elisp
;; WRONG - will fail package-lint
(defun alist-get-chain (symbols alist) ...)

;; CORRECT
(defun package-name--alist-get-chain (symbols alist) ...)
```

### Avoiding Load-Time Errors

#### Problem: Void variable at load time

When your package extends another package (e.g., marginalia), don't require it if you only need to register with it:

```elisp
;; WRONG - causes "void variable" error during byte compilation
(require 'marginalia)
(add-to-list 'marginalia-annotator-registry '(category my-annotator))

;; CORRECT - declare variable and defer registration
(defvar marginalia-annotator-registry)

(with-eval-after-load 'marginalia
  (add-to-list 'marginalia-annotator-registry '(category my-annotator)))
```

#### Problem: Free variable warnings

Declare variables from other packages that you reference:

```elisp
;; Add near top of file, after requires
(defvar url-http-end-of-headers)  ; From url-http
```

#### Problem: Unknown function warnings

Use `declare-function` for functions defined in other files of your package:

```elisp
;; In package-name-actions.el, referencing function from package-name-embark.el
(declare-function package-name--add-to-list "package-name-embark" (item))
```

## GitHub Actions CI

### ci.yml

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions:
  contents: read

jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, macos-latest]
        emacs-version:
          - 29.4
          - snapshot

    steps:
      - uses: actions/checkout@v4

      - name: Set up Emacs
        uses: jcs090218/setup-emacs@master
        with:
          version: ${{ matrix.emacs-version }}

      - name: Set up Eask
        uses: emacs-eask/setup-eask@master
        with:
          version: 'snapshot'

      - name: Install dependencies
        run: eask install-deps

      - name: Byte compile
        run: eask compile

      - name: Package lint
        run: eask lint package
        continue-on-error: true  # Don't fail CI on lint warnings

      - name: Checkdoc
        run: eask lint checkdoc
        continue-on-error: true  # Don't fail CI on doc warnings
```

### Key Points

1. **Test multiple Emacs versions** - at minimum: latest stable + snapshot
2. **Test multiple OS** - ubuntu-latest and macos-latest
3. **Use `continue-on-error: true`** for lint steps if you want warnings visible but non-blocking

## Release Please Configuration

### release.yml

```yaml
name: Release

on:
  push:
    branches: [main]

permissions:
  contents: write
  pull-requests: write

jobs:
  release-please:
    runs-on: ubuntu-latest
    steps:
      - uses: googleapis/release-please-action@v4
        id: release
        with:
          # Use manifest mode - don't use deprecated release-type/package-name inputs
          config-file: release-please-config.json
          manifest-file: .release-please-manifest.json

      - uses: actions/checkout@v4
        if: ${{ steps.release.outputs.release_created }}

      - name: Update version in Elisp files
        if: ${{ steps.release.outputs.release_created }}
        run: |
          VERSION="${{ steps.release.outputs.major }}.${{ steps.release.outputs.minor }}.${{ steps.release.outputs.patch }}"
          for file in *.el; do
            sed -i "s/;; Version: .*/;; Version: ${VERSION}/" "$file"
          done
          sed -i "s/\"[0-9]*\.[0-9]*\.[0-9]*\"/\"${VERSION}\"/" Eask

      - name: Commit version bump
        if: ${{ steps.release.outputs.release_created }}
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add -A
          git diff --staged --quiet || git commit -m "chore: bump version to ${{ steps.release.outputs.tag_name }}"
          git push
```

### release-please-config.json

```json
{
  "$schema": "https://raw.githubusercontent.com/googleapis/release-please/main/schemas/config.json",
  "packages": {
    ".": {
      "release-type": "simple",
      "package-name": "package-name",
      "bump-minor-pre-major": true,
      "bump-patch-for-minor-pre-major": true,
      "include-component-in-tag": false,
      "include-v-in-tag": true
    }
  }
}
```

### .release-please-manifest.json

```json
{
  ".": "0.1.0"
}
```

### version.txt

```
0.1.0
```

### Repository Settings Required

For release-please to create PRs, enable in repo settings:

**Settings → Actions → General → Workflow permissions:**
- Enable "Allow GitHub Actions to create and approve pull requests"

## Conventional Commits

Release-please parses conventional commits to determine version bumps:

- `fix:` → patch bump (0.0.x)
- `feat:` → minor bump (0.x.0)
- `feat!:` or `BREAKING CHANGE:` → major bump (x.0.0)

Examples:
```
fix: resolve byte compilation error
feat: add new search functionality
feat!: change API for search function
docs: update README
chore: update dependencies
ci: fix GitHub Actions workflow
```

## MELPA Submission

Once your package is ready (CI passing, no package-lint errors), you can submit to MELPA.

### Prerequisites

Before submitting, ensure:

- [ ] Package byte-compiles cleanly (no errors)
- [ ] Package-lint passes (no errors; warnings are acceptable)
- [ ] All functions have package prefix
- [ ] No private functions have `;;;###autoload` (use `package-` prefix for public autoloaded functions)
- [ ] README has installation and usage instructions
- [ ] LICENSE file exists
- [ ] Package-Requires header matches actual dependencies

### MELPA Recipe Format

Create a recipe file for your package. The recipe tells MELPA how to build your package.

**Basic recipe:**

```elisp
(package-name :fetcher github
              :repo "username/package-name")
```

**With file exclusions** (for optional integrations):

```elisp
(package-name :fetcher github
              :repo "username/package-name"
              :files ("*.el" (:exclude "package-name-optional.el")))
```

**Example for spot.el:**

```elisp
(spot :fetcher github
      :repo "chiply/spot.el"
      :files ("*.el" (:exclude "spot-consult-omni.el")))
```

### Submission Process

1. **Fork the MELPA repository**
   ```bash
   gh repo fork melpa/melpa --clone
   cd melpa
   ```

2. **Create your recipe file**
   ```bash
   # Create recipes/package-name (no file extension)
   cat > recipes/package-name << 'EOF'
   (package-name :fetcher github
                 :repo "username/package-name")
   EOF
   ```

3. **Test the recipe locally**
   ```bash
   # This builds the package using your recipe
   make recipes/package-name
   ```

4. **Commit and push**
   ```bash
   git add recipes/package-name
   git commit -m "Add package-name"
   git push origin master
   ```

5. **Create a pull request**
   - Go to https://github.com/melpa/melpa/pulls
   - Click "New pull request"
   - Select your fork
   - Title: `Add package-name`
   - Description should include:
     - Brief description of the package
     - Link to the repository
     - Confirmation that you're the maintainer or have permission

### MELPA Review Process

MELPA maintainers will review your PR and may request changes:

- **Recipe syntax** - Ensure it's correct
- **Package quality** - No byte-compile errors
- **Naming conflicts** - Package name must be unique
- **Documentation** - README should explain the package

### Acceptable Package-Lint Warnings

Some warnings are acceptable and won't block MELPA acceptance:

1. **`with-eval-after-load` warning** - When used to register with other packages (like marginalia annotators), this is the correct pattern.

2. **Checkdoc warnings** - Minor documentation style issues are usually acceptable.

### After Acceptance

Once merged, your package will be available on MELPA within a few hours. Users can install with:

```elisp
(use-package package-name
  :ensure t)
```

### Updating Your Package

MELPA automatically builds from your repository's default branch. To release updates:

1. Push changes to your main branch
2. MELPA rebuilds automatically (usually within 24 hours)
3. Users get updates via `M-x package-upgrade` or `M-x package-upgrade-all`

### Recipe Reference

| Field | Description |
|-------|-------------|
| `:fetcher` | `github`, `gitlab`, `codeberg`, `sourcehut`, or `git` |
| `:repo` | Repository path (e.g., `"username/repo"`) |
| `:url` | Full URL (for `:fetcher git` only) |
| `:branch` | Branch name (default: default branch) |
| `:files` | Files to include (default: `("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo" "lisp/*.el" (:exclude ".dir-locals.el" "test.el" "tests.el" "*-test.el" "*-tests.el" "LICENSE" "README*" "*-pkg.el"))`) |
| `:old-names` | Previous names if package was renamed |

## Common Issues and Solutions

### "Symbol's value as variable is void"

**Cause**: Requiring a package that defines a variable, but accessing it at load time before the package initializes.

**Solution**: Use `defvar` to declare the variable and `with-eval-after-load` for code that uses it.

### "doesn't start with package's prefix"

**Cause**: Function or variable name doesn't start with your package name.

**Solution**: Rename to include prefix. Use `package--` for private, `package-` for public.

### "Package 'emacs-X.Y' is unavailable"

**Cause**: A dependency requires a newer Emacs version than specified.

**Solution**: Update `(depends-on "emacs" "X.Y")` in Eask and `Package-Requires` in main .el file.

### CI shows error annotations but jobs pass

**Cause**: `continue-on-error: true` allows the job to pass, but errors are still shown as annotations.

**Solution**: Fix the underlying lint issues, or accept that annotations will appear.

### Release-please can't create PRs

**Cause**: GitHub Actions doesn't have permission to create PRs.

**Solution**: Enable "Allow GitHub Actions to create and approve pull requests" in repo settings.

## Checklist for New Projects

### Package Quality
- [ ] Create Eask with lexical-binding cookie
- [ ] Ensure all functions have package prefix
- [ ] Package description doesn't include "for Emacs"
- [ ] Emacs version matches dependency requirements
- [ ] All variables from other packages are declared with `defvar`
- [ ] Functions from other files use `declare-function`
- [ ] No private functions (`--`) have `;;;###autoload`
- [ ] Package byte-compiles without errors
- [ ] Package-lint passes without errors

### Documentation
- [ ] README with installation instructions
- [ ] README with usage examples
- [ ] LICENSE file exists
- [ ] Package-Requires header matches Eask dependencies

### CI/CD
- [ ] CI workflow tests multiple Emacs versions and OS
- [ ] Release-please config uses manifest mode
- [ ] version.txt exists for simple release type
- [ ] Repository allows GitHub Actions to create PRs

### MELPA Submission
- [ ] All above items complete
- [ ] Recipe file created and tested locally
- [ ] PR submitted to melpa/melpa repository
