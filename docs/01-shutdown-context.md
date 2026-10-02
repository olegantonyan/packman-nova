# Packman shutdown: facts

## Announcement
- Sent 2026-08-27 23:58 CEST to the packman mailing list by Marc Schiffbauer, signed by Marc Schiffbauer and Stefan Botter.
  https://lists.links2linux.de/pipermail/packman/2026-August/018314.html
- "If no one is found who wishes to continue Packman, we will discontinue the project on 31/12/2026."
- Reasons stated: 25 years, project past its zenith, Flatpak reduced demand, the two operators lack time and energy. No legal or takedown reason.
- If nobody takes over: build servers and repository hosting are switched off; repos become inaccessible.
- Forum thread (9 pages by 2026-09-26): https://forums.opensuse.org/t/packman-discontinued-from-jan-1st-2027-but-heres-your-chance/195731

## Who did what
- Marc Schiffbauer: repo management, mail infra, hosting paid personally, domain owner. Keeps domain and list if successors exist.
- Stefan Botter: build servers since 2013, list moderation.
- Pascal Bleser: website, sponsors, mirrors (historical).
- Packagers still active: manfred-h (broadcom-wl, MakeMKV, handbrake, kodi), seife (ARM workers, OBS admin), detrei, jobermayr, and the `maintainers` group listed in `reference/pmbs/Essentials._meta.xml`.

## Infrastructure they run
- PMBS: Open Build Service on a Leap 16 VM, 1.3 TB disk, 10 GB RAM, 6 cores, on a rented Ryzen 9 5950X. Offered for transfer as a VM. Backups every 2 h, 3 years retention.
- Workers: 2 x86_64 VMs (4 cores, 24/32 GB) from Stefan, plus community workers (seife's aarch64, Raspberry Pis for armv7l).
- Repo server: i7-6700, 32 GB, ~700 GB RAID. Hosts website, master repo, rsync for mirrors, signing scripts. Traffic 800-900 GB/month. "Should be rebuilt."
- Offered to successors: the PMBS VM, the publishing and signing shell scripts, advice. Not offered: the signing private key (nobody has mentioned it).

## Signing key
- `PackMan Project (signing key) <packman@links2linux.de>`, RSA 4096, fingerprint `F887 5B88 0D51 8B6B 8C53 0D13 45A1 D067 1ABD 1AFB`.
- Expiry extended 2026-08-24 to 2027-01-01. Old `rpmkey-packman` builds still carried the expired key, causing user errors in Sep 2026.
- Copy in `reference/repo-metadata/packman-signing-key.asc`. We cannot and should not reuse it.

## Successor candidates (as of 2026-09-26, nothing decided)
- Christian "computersalat" (runs his own OBS): offered to host PMBS, take the workers, rebuild or merge the repo server. Endorsed by seife and manfred-h.
- seife: OBS admin help and continued aarch64 workers.
- manfred-h: packaging only; has the core set building in a private environment; publishing a "what is really needed" list.
- bmwiedemann (SUSE, Slowroll): limited time; suggests moving now-patent-free codecs (MPEG-4 ASP since Jul 2026) into Factory, and ffmpeg dlopen of restricted libs so only add-on codec packages remain outside openSUSE.
- Others: a student offering home hosting, an AI-pipeline proposal (declined), a company (Meterxpert) offering resources (no maintainer reply seen).

## Why Packman exists at all
openSUSE OBS has a banned-software list (https://en.opensuse.org/openSUSE:Packaging_guidelines#Banned_software). SUSE bears trademark liability, so patent-encumbered codecs (HEVC/H.265, AAC variants, AMR, DTS, some MPEG bits), DVD/Blu-ray decryption (libdvdcss, libaacs, libbdplus), and non-redistributable blobs (Widevine, Broadcom firmware, Flash) cannot be built there. Everything else in Packman is convenience (newer versions, apps Factory dropped).

## What users say they still need
HEVC decode/encode (x265, libde265, libheif HEIC from iPhones), ffmpeg with x264/x265/fdk-aac, vlc-codecs, gstreamer bad/ugly codec plugins, Packman's Mesa build for VA-API/Vulkan video on AMD (Extra project, not Essentials), libdvdcss/Blu-ray, broadcom-wl.

## Alternatives people are migrating to
VideoLAN repo (https://download.videolan.org/SuSE/) for vlc/ffmpeg/x264/x265, openSUSE OpenH264 repo, Flatpaks. VideoLAN does not ship Mesa or libheif with HEVC.
