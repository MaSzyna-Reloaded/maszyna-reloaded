# FINDINGS

Rules left by root causes found in the game, one line each; libreloaded's own are in
`vendor/libreloaded/FINDINGS.md`.

* 2026-10-15 - a resource is never `ResourceLoader.load()`ed in a `WorkerThreadPool` task: there it
  goes through a task of its own, and in flight over Stary Sącz one terrain region came back null
  every time (the same file loaded at once on the main thread and on a `Thread`). Read on a thread
  of your own (`WorldTerrainStreamer`), and never call a method on what a load returned unchecked -
  in a release build a null there is a SIGSEGV in the engine, not a script error.
