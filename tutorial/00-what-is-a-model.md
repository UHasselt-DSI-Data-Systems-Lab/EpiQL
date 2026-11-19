# What is an EpiQL model?

EpiQL is a language for describing how a disease spreads through a population, so that a
computer can simulate it. In this tutorial you build such a model step by step, for **Tiny
Town**: a town of only eight people, small enough to check every result by hand. At the end,
you will be able to read and change the model that is used for the Belgian population.

You do not need to have programmed before.

## Everything is a table

EpiQL works with tables. Here are the people of Tiny Town:

```data Persons(person_id, age)
```

Each row is one person: a number that identifies them, and their age. EpiQL calls a table
like this a **relation**, and this one is called `Persons`.

Every EpiQL model does three things:

1. It **reads** tables that you give it, such as `Persons`. These are its *input* relations.
2. It **derives** new tables from them, by following **rules** that you write.
3. It **shows** some of those new tables as its result. These are its *output* relations.

## Your first program

Here is a complete program. Press **Run** and look at the table that appears below it.

```epiql run
input relation Persons(person_id: u32, age: u8);
output relation Everyone(person_id: u32, age: u8);

Everyone(p, a) <- Persons(p, a);
```

The result, `Everyone`, is exactly the same table as `Persons`. That is not very useful yet,
but this short program already has every part that a big model has. Let's read it line by line.

**Line 1** says that there is an *input* relation called `Persons`, with two columns:
`person_id` and `age`. The words after the colons say what kind of numbers a column holds:
`u8` is an integer from 0 to 255, which is plenty for an age, and `u32` is an integer from 0
to about 4.3 billion, enough to give everyone in a country their own number. EpiQL has more
of these built-in types; the [overview of the built-in types](types.md) lists them all, with
their ranges.

**Line 2** says that there is a relation called `Everyone`, with the same two columns. The word
`output` means: show this table when the program is done.

**Line 4** is a **rule**. It says which rows are in `Everyone`. Read the arrow `<-` as "if":

> The row `(p, a)` is in `Everyone` **if** the row `(p, a)` is in `Persons`.

`p` and `a` are variable names that you choose. They stand for values: the row `(1, 42)` is in
`Persons`, so the rule says that `(1, 42)` is in `Everyone`, and the same goes for every other
row. The part on the left of the arrow is the rule's *head*: what the rule concludes. The part
on the right is its *body*: the condition for that.

A rule is a statement about the result, not an instruction. You do not tell EpiQL *how* to
find the rows; you describe *which* rows belong in the table, and EpiQL works them out.

Every declaration and every rule ends with a semicolon `;`.

## Try it yourself

Change the program below so that `Everyone` has only one column: the person's identifier. You have
to change two things: the declaration of `Everyone` on line 2, and the head of the rule on line 4.

```epiql run
input relation Persons(person_id: u32, age: u8);
output relation Everyone(person_id: u32, age: u8);

Everyone(p, a) <- Persons(p, a);
```

```expect Everyone
1
2
3
4
5
6
7
8
```

<details>
<summary>Show a solution</summary>

```epiql
input relation Persons(person_id: u32, age: u8);
output relation Everyone(person_id: u32);

Everyone(p) <- Persons(p, a);
```

</details>

Now try these, and run the program after each one:

- Rename `p` to `person` everywhere in the rule. Does the result change?
- Remove the semicolon at the end of the rule. EpiQL tells you that something is wrong, and
  points at the place where it noticed. Click the message to jump there.
- Write `Persons(p)` instead of `Persons(p, a)`. What does EpiQL say?

You can always go back to the program you started from with **Undo my changes**.

## What you learned

- A **relation** is a table. An `input` relation is given to the model; an `output`
  relation is shown when it is done.
- A **rule** says which rows are in a relation. Read it as "*head* is in the table **if**
  *body*". It describes the result; EpiQL works out the rows.
- The variable names in a rule, such as `p` and `a`, stand for values in a row. You choose them.
