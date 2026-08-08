;;; flamegraph.el --- Configure flamegraph -*- lexical-binding: t; -*-

;; Flame graphs for the Emacs profiler, and for folded-stacks files
;; from external profilers (perf, py-spy, rbspy).
;;
;; Workflow: M-x profiler-start … do the slow thing … M-x
;; profiler-stop, then M-x flamegraph-profiler-report.  In the graph:
;; RET/mouse-1 zooms into a frame, d describes it (parent, callees,
;; self-time, annotated source snippet), f jumps to the source, l/r
;; walk the navigation history.  External profiles come in via
;; M-x flamegraph-find-profile (for perf, fold with -F +srcline to
;; get source locations).

;; Package-Requires (emacs "30.1") — skip entirely on older Emacsen
;; (the CI matrix includes 29.4, where elpaca would fail the build).
(when (version<= "30.1" emacs-version)
  (use-package flamegraph
    :ensure (flamegraph :host github :repo "dgutov/emacs-flamegraph")
    :commands (flamegraph-profiler-report flamegraph-find-profile)))

;;; flamegraph.el ends here
