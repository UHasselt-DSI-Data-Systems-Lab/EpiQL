# EpiQL tutorial

The lessons the web interface shows under **Learn** (start `epiql-web`, then open the Learn tab). They teach
EpiQL by building a model of an epidemic in Tiny Town, a town of eight people
(`data/tiny-town.json`), one question at a time. They are written for readers without a
background in computer science.

## Writing a lesson

A lesson is a Markdown file named `NN-slug.md`; the numbers give the order, and its first
`# heading` is its title in the lesson list. The other Markdown files, except this README, are
reference pages, such as `types.md`: they are listed under **Reference**, by title, and are not
part of the sequence of lessons. Link to one with an ordinary Markdown link, such as
`[the built-in types](types.md)`; the link opens it in the Learn view, and also works when you
browse this folder on GitHub. The Learn view reads the files when a lesson is opened,
so an edit shows up when you open the lesson again.

Besides ordinary Markdown, a lesson can use these fenced blocks:

| Block | Becomes |
| --- | --- |
| ` ```epiql ` | A piece of a program, with syntax highlighting. |
| ` ```epiql run ` | A program the reader can edit and run. Add `timesteps=N` (default 1), `dataset=NAME` (default `tiny-town`) or `runs=N` (default 1, at most 10) after `run`. With several runs, a relation with one number per timestep is shown with a column and a line per run, any other one run at a time, and an `expect` block must hold in every run. A relation that changes over time is shown as a table per timestep, with a slider; one that holds a number per timestep (or per group and timestep) can also be shown as a chart. |
| ` ```data Persons(person_id, age) ` | The rows of an input file of Tiny Town, as a table with these column names. Leave the block empty. |
| ` ```expect Children ` | The rows (one per line, values separated by commas) that the runnable program just before it should produce in `Children`. After a run, the reader sees whether their table is right, but not these rows. When an exercise has more than one right answer, give one `expect` block per answer: the table is right if it matches any of them. For a relation that changes over time, `expect Status@3` is about timestep 3; plain `expect Status` about the last one. |

A hint or a solution goes in a `<details>` element, with a blank line after its `<summary>`.

## How the lessons are written

- Each lesson starts from a question about the town, and introduces only what is needed to answer it.
- Show the data, then the rule, then say in plain words what the rule means.
- Ask the reader to predict a result before they run it.
- Until the lesson that introduces chance, every result is exact, so it can be checked by hand.
- Avoid computer-science words. When one is needed, explain it the first time.
