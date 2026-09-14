# org-knowledge

Promote a note to a HyWiki page with the reason typed once; resurface a
page that has gone quiet; look at this day a year and a month ago.

| command                      | does                                                     |
|------------------------------|----------------------------------------------------------|
| `org-knowledge-promote`      | the heading at point becomes (or extends) `WikiWord.org`; the body moves verbatim; one line stays: `[[hy:WikiWord]] the reason.` |
| `org-knowledge-resurface`    | the page untouched longest (`org-knowledge-resurface-days`, 30), beside the rolo hits that mention it |
| `org-knowledge-on-this-day`  | the rolo for this day last year and last month           |
| `org-knowledge-problems`     | the headings of `FavouriteProblems.org`, for decoration  |

The reason is the one thing typed, and it is asked for before anything
is written: an empty reason aborts. The page always has a `#+title:`
line, written once; a second promotion to the same word appends. The
source keeps its heading and its text.

No org-roam, no renaming: the WikiWord is the address.

## Shape

| file                        | role                                     | needs Org |
|-----------------------------|------------------------------------------|-----------|
| `org-knowledge-core.el`     | WikiWords, page text, the source line, untouched pages, on this day | no |
| `org-knowledge.el`          | the commands over the wiki directory     | yes       |
| `test/org-knowledge-test.el`| ERT: the core, and promotion over a temp wiki | yes  |

```sh
emacs -Q --batch -L source/zettapkg/org-knowledge \
  -l source/zettapkg/org-knowledge/test/org-knowledge-test.el \
  -f ert-run-tests-batch-and-exit
```
