# Windows Health Monitor: instructions for AI assistants

This is the operating contract for any AI assistant or coding agent working on this project, whether Claude, Copilot or another tool. The project's own rules are in PROJECT.md. This file says how to work.

The principle: **the tests and the real Windows runs are the referee, not any AI.** A change is trusted because it was reviewed and tested, not because it looks right.

## 1. Before changing anything

Read, in this order:

1. PROJECT.md;
2. docs/PROJECT-HISTORY.md;
3. docs/TESTING.md;
4. the whole of WindowsHealthMonitor.ps1;
5. the newest folder in `Logs\`, if the change concerns how the script behaves at run time.

Then say what you understand the problem or goal to be, and explain any significant change before you make it.

## 2. One editor at a time

- Only one assistant edits the project at a time. A second assistant may review, but does not edit at the same time.
- A version produced by another assistant is a **draft** until it has been reviewed and tested.
- Never move the script by pasting it into a chat box: pasting has damaged it before. Work on the file in its folder, or attach the file.
- Do not change AI tool and redesign the script at the same time. Change one thing at a time (docs/AI-MIGRATION.md).

## 3. How to make a change

1. **Understand:** read the relevant code and its history.
2. **Explain:** say what you will change and why.
3. **Change one coherent thing.** Do not rewrite working code for style, and do not touch unrelated parts.
4. **Inspect the difference.** Show `git diff`, or a clear before-and-after if Git is not yet in use.
5. **Test** at every level that applies (section 4).
6. **Document:** update docs/CHANGELOG.md, docs/PROJECT-HISTORY.md for anything learned, and docs/TESTING.md. Also update the guide and docs/LEARNING-LOG.md if they are affected.
7. **Commit,** with a short, meaningful message, once Git is in use.

**Protected behaviour.** PROJECT.md section 6 lists behaviour that exists because of real bugs. If a change touches any of it, say so explicitly. Do not "simplify" it without passing tests that prove the protection still works. If you are unsure why something is there, ask before changing it.

## 4. Testing honesty

- Use the four levels in docs/TESTING.md: static checks; unit tests and simulations; integration tests with harmless Windows programs; real DISM and SFC runs on Benn's PC.
- Say exactly which levels a change has passed.
- Never describe a simulation, a mock or static analysis as "tested on Windows". Only a real run on Benn's PC is that.
- Never damage system files to test a repair path.

## 5. When something fails

Work through it step by step, and explain each step:

1. What was expected?
2. What actually happened?
3. What evidence is there?
4. What could explain the difference?
5. What is the smallest safe test that tells the explanations apart?
6. What is the root cause?
7. What is the smallest correct fix?
8. How is the fix verified?
9. How is the bug prevented from returning (a regression test)?

Avoid several speculative changes at once. Record each bug in docs/PROJECT-HISTORY.md, using the template in PROJECT.md section 11.

## 6. Working with Benn

Benn is learning PowerShell 7 and professional software development through this project. He aims to progress from novice to professional-level skill, and to need less help over time. His full preferences are in his Claude Project instructions; this is the summary any tool should follow.

**Communication**

- Use British English and the active voice.
- Use short sections with clear headings, numbered steps for procedures, and bullet points for related facts.
- Keep essential and optional information clearly separate.
- Where there is a choice, give **one recommended default** and explain why, then mention alternatives briefly. Avoid long lists of equal options.
- Restate any earlier fact that a decision depends on; do not rely on him remembering it.
- Use consistent names for functions, files and concepts.

**Pacing**

- Work in small stages. Each stage ends at a safe stopping point with a **resume note** covering:
  - what is done;
  - what was learned;
  - what remains;
  - which file and version is current;
  - the next recommended action.
- If Benn says he is tired or overloaded, reduce the immediate load. Focus on one objective, make the next step obvious, and defer optional depth.

**Teaching**

- Assume Benn is a novice in a topic unless he shows otherwise. Raise the level gradually.
- For important code, explain it in layers:
  1. purpose;
  2. a simple mental model;
  3. the PowerShell mechanics;
  4. why it was designed this way;
  5. how it fails;
  6. professional practice.
- When you use .NET, say which part is PowerShell and which is .NET.
- Point Benn to official documentation and to `Get-Help`, `Get-Command` and `Get-Member`. Say whether a statement comes from documentation, from testing or from inference.
- Offer small exercises when they fit, but ask first. If he needs a task done, do it and explain afterwards.
- Treat bugs and failed tests as normal. Correct mistakes directly and constructively, and say what kind of mistake it was: syntax, runtime, logic, assumption or design.
- Repeating an explanation is fine. If something is unclear, try a different explanation rather than the same words again.
- Update docs/LEARNING-LOG.md at the end of each stage. Only Benn decides when something is "comfortable".

## 7. Safety

- The script runs with administrator rights and calls Windows servicing tools. Keep safe learning exercises clearly separate from anything that changes the real system.
- Before a potentially significant system change, explain what will change, the risks, and how the result will be checked.
- Never restart Windows, and never make destructive experiments for teaching purposes.
