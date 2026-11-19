# Who lives in Tiny Town?

A disease does not affect everyone in the same way. Children go to school, adults go to work,
and older people are more likely to become seriously ill. So the first thing a model needs is a
way to filter groups of people. Here is the town again:

```data Persons(person_id, age)
```

## Selecting the children

This rule picks out everyone younger than 18:

```epiql
Children(p) <- Persons(p, age), age < 18;
```

In words:

> `p` is in `Children` **if** there is a row `(p, age)` in `Persons` **and** `age` is less
> than 18.

The comma in the body means "and": everything in the body must be true. `age < 18` is a
**condition**: only the people for whom it holds are in `Children`.

Before you press **Run**, look at the table above: which person numbers do you expect?

```epiql run
input relation Persons(person_id: u32, age: u8);
output relation Children(person_id: u32);

Children(p) <- Persons(p, age), age < 18;
```

```expect Children
3
4
8
```

## Comparing numbers

These are the comparisons you can use in a condition:

| You write | It means |
| --- | --- |
| `age < 18` | less than 18 |
| `age <= 18` | 18 or less |
| `age > 64` | more than 64 |
| `age >= 65` | 65 or more |
| `age = 9` | exactly 9 |
| `age != 9` | anything but 9 |

"Exactly" is a single `=`. If you have programmed before, you may be used to writing `==`;
EpiQL does not understand that.

A program can have several rules. This one makes two groups at once; each rule is about its own
relation:

```epiql run
input relation Persons(person_id: u32, age: u8);
output relation Children(person_id: u32);
output relation Elderly(person_id: u32);

Children(p) <- Persons(p, age), age < 18;
Elderly(p)  <- Persons(p, age), age >= 65;
```

## Try it yourself

**1.** Make a relation `Adults` with everyone aged 18 to 64. You need two conditions,
separated by a comma. The program below has only one of them yet: run it first, to see that its
answer is not right.

```epiql run
input relation Persons(person_id: u32, age: u8);
output relation Adults(person_id: u32);

Adults(p) <- Persons(p, age), age >= 18;
```

```expect Adults
1
2
7
```

<details>
<summary>Show a hint</summary>

People who are 18 or older **and** younger than 65: add `, age < 65` before the semicolon.

</details>

**2.** Who is exactly 9 years old? Make a relation `Nine` with their identifier.

```epiql run
input relation Persons(person_id: u32, age: u8);
output relation Nine(person_id: u32);

```

```expect Nine
3
```

<details>
<summary>Show a solution</summary>

```epiql
Nine(p) <- Persons(p, age), age = 9;
```

</details>

> **Write the value in the row.** A condition of the form *variable name* `=` *value*, such as
> `age = 9`, is usually not written as a condition. Instead, you put the value in the row, in
> the place of the variable name, and leave the condition out. These two rules mean the same:
>
> ```epiql
> Nine(p) <- Persons(p, age), age = 9;
> Nine(p) <- Persons(p, 9);
> ```
>
> The second reads: "`p` is in `Nine` if there is a row `(p, 9)` in `Persons`". It is shorter,
> and it is how you will find it in most models. Only `=` can be written this way: for `<`,
> `>=`, `!=` and the others you still need a condition.

**3.** What do you expect for `age > 100`? Change one of the programs above, and run it.

## What you learned

- A **condition**, such as `age < 18`, must be true for a row to be in the result.
- A comma in the body means "and".
- "Exactly" is written with a single `=`.
- Instead of a condition `age = 9`, you usually write the value in the row: `Persons(p, 9)`.
- A program can have many rules, each saying which rows are in a relation.
