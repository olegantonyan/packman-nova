# packman-nova

Independent rebuild of Packman Essentials for Tumbleweed. `README.md` is the index; `docs/` holds findings and the
tool docs, `reference/` the raw evidence. Before proposing packaging changes read `docs/02`, `docs/04`, `docs/07`;
before touching the CLI read `docs/12-tool-design.md` and `docs/12-tool.md`. Facts in `docs/` were verified against
live PMBS, openSUSE OBS and mirror data in 2026-09; re-verify anything time-sensitive (Packman deadline, successor
status) before relying on it. Keep docs terse; put new evidence under `reference/`.

- Tests: `bundle exec rake` (unit tests + rubocop, must stay green). End to end: `PACKMAN_NOVA_INTEGRATION=1 PACKMAN_NOVA_SMOKE_ROOT=<big disk> bundle exec rake integration_test` (builds fdk-aac, ~2.5 min).
- Style: `# frozen_string_literal: true`, `::Const`, one class per file mirroring the namespace, keyword args, no code comments, no rubocop-disable.
- `.env` holds `GPG_PRIVATE_KEY_BASE64` (the production signing key) and the workdir path. Never print, log or copy it; never commit `.env`.
- Do not commit `out/`, `.cache/` or anything from the workdir. Long builds: run in the background and poll.
