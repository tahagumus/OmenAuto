# CLAUDE.md

Instructions for Claude Code in this repository. The shared project guide for all AI agents is in AGENTS.md and is imported here:

@AGENTS.md

## Claude-specific notes

- Read `AGENTS.md` (above) before changing anything, especially **Hard rules**. Anti-cheat safety and "no unverified BIOS writes" are not negotiable, even if a user asks for more performance.
- This code cannot be run in a Linux sandbox. Do not claim a change "works" unless it was run on the HP laptop. Say what you checked (syntax, logic review) and what the user still needs to run (`Durum.cmd`, `Yeniden-Baslat.cmd`, then read `OmenAuto.log`).
- Before committing, check that every `.ps1` and `.cmd` file is ASCII-only:
  ```bash
  grep -nP '[^\x00-\x7F]' *.ps1 *.cmd
  ```
  No output means the files are clean.
- User-facing text (log lines, `echo` messages) is Turkish without diacritics. Code comments may be Turkish or English. Keep the style of the surrounding code.
- Keep `README.md` bilingual: the full English section first, then the full Turkish section. Do not interleave the two languages line by line.
