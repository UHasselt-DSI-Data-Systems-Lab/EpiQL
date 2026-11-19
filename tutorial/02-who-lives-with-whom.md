# Who lives with whom?

Many infections happen at home: people who live together are in close contact every day. To
model that, we need to know who lives with whom. Tiny Town has a second table for this:

```data Household(person_id, household_id)
```

Each row says that a person lives in a household. Persons 1, 2, 3 and 4 live together in
household 1, persons 5 and 6 in household 2, and persons 7 and 8 in household 3.

## Using two tables at once

Where does each child live? For that we need both tables: `Persons` knows the ages,
`Household` knows the households.

```epiql
ChildAt(p, h) <- Persons(p, age), age < 18, Household(p, h);
```

The variable name `p` appears in both `Persons(p, age)` and `Household(p, h)`. Using the **same variable name**
means: **the same value**. So both rows must be about the same person. In words:

> `(p, h)` is in `ChildAt` **if** person `p` has an age below 18 **and** lives in household `h`.

```epiql run
input relation Persons(person_id: u32, age: u8);
input relation Household(person_id: u32, household_id: u32);
output relation ChildAt(person_id: u32, household_id: u32);

ChildAt(p, h) <- Persons(p, age), age < 18, Household(p, h);
```

```expect ChildAt
3, 1
4, 1
8, 3
```

## Pairs of people

The same idea works within one table. Who lives in the same household as whom?

```epiql
SameHousehold(p1, p2) <- Household(p1, h), Household(p2, h);
```

In words:

> `(p1, p2)` is in `SameHousehold` **if** `p1` lives in household `h` **and** `p2` lives in
> that same household `h`.

Household 1 has four people, so how many pairs do you expect from it? And how many in total?
Run it and count.

```epiql run
input relation Household(person_id: u32, household_id: u32);
output relation SameHousehold(person1: u32, person2: u32);

SameHousehold(p1, p2) <- Household(p1, h), Household(p2, h);
```

There are 24 pairs: 16 from household 1, and 4 from each of the others. That includes pairs
like `(1, 1)`: nothing in the rule says that `p1` and `p2` must be different people, and
person 1 does live in the same household as person 1. Both `(1, 2)` and `(2, 1)` are there
too, because both fit the rule.

## Try it yourself

**1a.** A disease is passed on from one person to another, so a model needs pairs of two
*different* people. Change the rule so that someone is not paired with themselves. You should
get 16 pairs.

```epiql run
input relation Household(person_id: u32, household_id: u32);
output relation Housemates(person: u32, housemate: u32);

Housemates(p1, p2) <- Household(p1, h), Household(p2, h);
```

```expect Housemates
1, 2
1, 3
1, 4
2, 1
2, 3
2, 4
3, 1
3, 2
3, 4
4, 1
4, 2
4, 3
5, 6
6, 5
7, 8
8, 7
```

<details>
<summary>Show a hint</summary>

Add a condition that says that `p1` is not `p2`. "Not equal" is written `!=`.

</details>

**1b.** Every pair is still there twice: `(1, 2)` and `(2, 1)` are the same two people. When
you want to count the contacts in a household, each pair should appear only once. Change the
rule so that it does. You should get 8 pairs.

```epiql run
input relation Household(person_id: u32, household_id: u32);
output relation Housemates(person: u32, housemate: u32);

Housemates(p1, p2) <- Household(p1, h), Household(p2, h);
```

```expect Housemates
1, 2
1, 3
1, 4
2, 3
2, 4
3, 4
5, 6
7, 8
```

```expect Housemates
2, 1
3, 1
4, 1
3, 2
4, 2
4, 3
6, 5
8, 7
```

<details>
<summary>Show a hint</summary>

Of `(1, 2)` and `(2, 1)`, keep only one: for example the one in which the first number is the
smaller one.

</details>

<details>
<summary>Show a solution</summary>

```epiql
Housemates(p1, p2) <- Household(p1, h), Household(p2, h), p1 < p2;
```

`p1 < p2` also leaves out `(1, 1)`, because 1 is not less than 1, so the condition
`p1 != p2` is not needed. `p2 < p1` is just as right: it keeps `(2, 1)` instead of `(1, 2)`.

</details>

**2.** Which adults (18 or older) live with a child? You need `Persons` twice: once for the
adult, and once for the child.

```epiql run
input relation Persons(person_id: u32, age: u8);
input relation Household(person_id: u32, household_id: u32);
output relation LivesWithChild(person_id: u32);

```

```expect LivesWithChild
1
2
7
```

<details>
<summary>Show a hint</summary>

Give the adult and the child different variable names, such as `a` and `c`, and different
variable names for their ages. They live in the same household, so they share the variable
name `h`.

</details>

<details>
<summary>Show a solution</summary>

```epiql
LivesWithChild(a) <-
    Persons(a, age_a), age_a >= 18,
    Household(a, h), Household(c, h),
    Persons(c, age_c), age_c < 18;
```

A rule may be spread over several lines; only the semicolon ends it.

Person 1 lives with two children (3 and 4), but appears only once in `LivesWithChild`. A
rule written with `<-` never gives the same row twice. (Later, you will meet an arrow that
keeps such repeated rows.)

</details>

## When you don't need a value

Sometimes a rule does not care about a column. Which households are there?

```epiql run
input relation Household(person_id: u32, household_id: u32);
output relation Households(household_id: u32);

Households(h) <- Household(_, h);
```

The underscore `_` means "any value, I don't need it". Each household appears once, even
though four people live in household 1, for the same reason as above.

## What you learned

- Using the **same variable name** in two places means: **the same value**. This is how a rule combines
  rows of different tables, or two rows of the same table.
- The result holds **every** row that fits the rule. Add conditions to leave out the rows you
  don't want, such as `p1 != p2`.
- `_` stands for a value you don't need.
- A rule written with `<-` never gives the same row twice.
