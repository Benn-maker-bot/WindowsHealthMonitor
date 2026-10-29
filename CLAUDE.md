# CLAUDE.md

This project keeps its rules in tool-neutral files, so that any AI assistant can work on it. Claude Code loads the two files below automatically through the `@` lines; other Claude surfaces should read them first.

@PROJECT.md
@AGENTS.md

## Notes that apply only to Claude

- **Simulation harness.** The bash files in `Tests\` (fake DISM and SFC) run only in Claude's Linux workspace. They are being replaced by Pester tests that run anywhere (docs/PLAN-2.5.md, stage 2).
- **Reference copies.** Benn's Claude Project "System Health Monitor" holds reference copies of the script and documents. The folder on the PC is the master; refresh the project copies whenever these files change.
- **Benn's full instructions.** The project instructions in that Claude Project are Benn's full statement of requirements and preferences. PROJECT.md and AGENTS.md summarise them for other tools. If they disagree, ask Benn.
