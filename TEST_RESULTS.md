# Verification results

Release verification: 10 November 2026, Ubuntu Linux, Godot `4.7.2.stable.official.ed1daf0bf`, GL Compatibility renderer on AMD Radeon 780M (Mesa 25.2.8), and PulseAudio.

| Suite | Result |
| --- | --- |
| Core gameplay, schedules, target matching, timing boundaries, statistics, history, geometry | 157,308 checks; 0 failures |
| Error classification, feedback lifetime, unchanged deadlines and statistics | 293 checks; 0 failures |
| Real rendering, mouse input, duplicate suppression, block transitions, results/history, resizing | 404 checks; 0 failures |
| Rendered red X, actual error input, feedback expiry, resizing | 31 checks; 0 failures |
| Real audio mixing, generated PCM, Mute/Unmute, silent stimuli and responses | 121 checks; 0 failures |
| Shape distinction | All 66 pairs passed; two rotated/reflected copy controls passed |
| Application independence | Passed; sibling source/cache and saved data unchanged |

**158,157 Godot assertions passed; zero failed.** Python checks also passed. Commands are in the README.

Coverage includes all 48 shape/color combinations, changing targets in four blocks, exact microsecond-to-millisecond calculations, omissions, false alarms, premature responses, duplicate suppression, history round trips and malformed/save-error handling. Rendered tests cover all twelve silhouettes at three drawing sizes, repeated pixel consistency, and layouts at 360 × 480, 800 × 900, and 1280 × 720.

Audio was captured from the actual UI audio bus using PulseAudio: click/start/completion output peaks were approximately −10.2 dBFS. Muted output was silent, and Unmute restored playback. Session sounds did not alter scoring or timing.

`screenshots/gameplay.png` is an unedited 800 × 900 Godot viewport capture taken by the rendered integration suite while the actual main scene was showing a gameplay stimulus. It was visually inspected for framing, legibility, and a visible abstract shape. The suite advances phase deadlines to exercise the complete session efficiently; it does not replace the game's scene or rendering.

The independence check verified concurrent launches and byte-for-byte preservation of the sibling project's source/cache and saved data. Completed test sessions used temporary history files. Its sibling comparison is optional when testing a standalone checkout. An obsolete development snapshot of the sibling project's generated caches was removed from the release.

No gameplay bugs were found in release verification, and gameplay code was preserved.

## Limitations

- Physical monitor/input latency and human shape discrimination are not established by automated tests. The contour threshold is a geometric regression check, not a clinical measure.
- Audio was verified through the system mixer rather than by a human listening test.
- Other operating systems and exported application packages were not tested.
- This application is for cognitive practice and experimentation, not clinical diagnosis.
