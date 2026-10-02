# Beyond Essentials: the other Packman projects

Counts from PMBS on 2026-09-28 (`reference/pmbs/*.packages.xml`).

| project | packages | links to OBS | native | repo path | notes |
|---|---|---|---|---|---|
| Essentials | 69 (45 built for TW) | 15 | 54 | TW, Slowroll, Leap 16.0/16.1, SLE15, Factory(KMP) | this project's scope |
| Multimedia | 217 | 51 | 164 | path -> Essentials | apps: handbrake, kodi, MPlayer, obs-studio, avidemux3, MakeMKV, audacious/deadbeef bits, many perl-Audio-*, ladspa-*, vamp-* |
| Extra | 70 | | | path -> Essentials | **A_tw-Mesa / A_tw-Mesa:drivers** (HW video decode with all codecs: the second most requested Packman feature), yt-dlp, smplayer skins, rar, discord, chromium-ffmpeg-extra |
| Games | 29 | | | | chess engines (stockfish, crafty), scummvm, libretro cores |
| KMP | 3 | | | Kernel:stable | broadcom-wl, r8168, `gesammelte_werke` aggregate |
| SLE15 | many | | | SLE 15 SP7 | aggregated into Essentials/SLE_15 |

Package name lists: `reference/pmbs/Multimedia.package-names.txt`, `Extra.packages.xml`, `Games.packages.xml`.

Priorities if we expand, based on the mailing-list "what is needed" list (manfred-h, 2026-09-08/09): handbrake, kodi + kodi.binary-addons, MakeMKV, MPlayer, asunder; then Mesa (Extra) for AMD VA-API/Vulkan video. Mesa `_constraints` require ~20 GB RAM.
