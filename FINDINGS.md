# FINDINGS

Rules left by root causes found in the game, one line each; libmaszyna's own are in
`vendor/libmaszyna/FINDINGS.md`.

* 2026-10-15 - a resource is never `ResourceLoader.load()`ed in a `WorkerThreadPool` task: there it
  goes through a task of its own, and in flight over Stary Sącz one terrain region came back null
  every time (the same file loaded at once on the main thread and on a `Thread`). Read on a thread
  of your own (`WorldTerrainStreamer`), and never call a method on what a load returned unchecked -
  in a release build a null there is a SIGSEGV in the engine, not a script error.
* 2026-10-15 - a Terrain3D takes its camera once, on its first frame, and with none it stops
  moving its mesh for good: the player makes its camera after the world has loaded, so the mesh
  stayed at (0,0,0) and the terrain by the player was its coarse levels (vertices 16-64 m apart) -
  tracks hung over embankments that were exact in the data. The Terrain3D is given the player's
  camera by `camera_changed`, connected in the scene (`world_pck.tscn`).
