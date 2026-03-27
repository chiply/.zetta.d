#!/usr/bin/env python3
"""Wrap long lines in .org files without breaking org syntax.

Usage: wrap-long-lines.py <directory> [--threshold 1000] [--width 80] [--dry-run]
"""

import argparse
import re
import textwrap
from pathlib import Path


def should_wrap(line: str, threshold: int) -> bool:
    """Return True if this line should be wrapped."""
    if len(line) <= threshold:
        return False
    # Preserve org syntax lines
    if re.match(r'^\*+ ', line):       # headings
        return False
    if re.match(r'^:[A-Z_]+:', line):  # property drawers
        return False
    if re.match(r'^#\+', line):        # directives
        return False
    if line.strip() == '':             # blank
        return False
    return True


def wrap_file(path: Path, threshold: int, width: int) -> bool:
    """Wrap long lines in a single file. Returns True if modified."""
    text = path.read_text(encoding='utf-8')
    lines = text.split('\n')
    changed = False
    out = []

    for line in lines:
        if should_wrap(line, threshold):
            wrapped = textwrap.fill(line, width=width, break_long_words=False,
                                    break_on_hyphens=False)
            out.append(wrapped)
            changed = True
        else:
            out.append(line)

    if changed:
        path.write_text('\n'.join(out), encoding='utf-8')

    return changed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    parser.add_argument('--threshold', type=int, default=1000)
    parser.add_argument('--width', type=int, default=80)
    parser.add_argument('--dry-run', action='store_true',
                        help='Show affected files without modifying')
    args = parser.parse_args()

    count = 0
    for path in sorted(args.directory.rglob('*readwise podcasts*.org')):
        if args.dry_run:
            text = path.read_text(encoding='utf-8')
            if any(should_wrap(l, args.threshold) for l in text.split('\n')):
                print(f'  {path}')
                count += 1
        else:
            if wrap_file(path, args.threshold, args.width):
                print(f'  wrapped: {path.name}')
                count += 1

    action = 'Would wrap' if args.dry_run else 'Wrapped long lines in'
    print(f'\n{action} {count} files.')


if __name__ == '__main__':
    main()
