# Susceptible, infectious or recovered?

An epidemic model keeps track of the health of every person. The simplest models give each
person one of three states:

- **susceptible**: not (yet) infected, and can be infected;
- **infectious**: infected, and can infect others;
- **recovered**: no longer infectious, and immune.

This is the *SIR* model. To store the state of a person in a column, you need a type whose
values are these three states. EpiQL has no built-in type for that, so you define your own:

```epiql
type State = SUSCEPTIBLE | INFECTIOUS | RECOVERED;
```

This says that `State` is a type with exactly three values. The vertical bar `|` separates
them; read it as "or". A column of type `State` can only hold one of these three values.

By convention, values like `INFECTIOUS` are written in capitals. That keeps them apart from
relation names, which start with a capital (`Persons`), and from variable names, which are in
lower case (`p`, `age`).

## Who is ill?

Today, person 2 is ill, and everyone else in Tiny Town is still susceptible. This program
gives every person their state:

```epiql run
type State = SUSCEPTIBLE | INFECTIOUS | RECOVERED;

input relation Persons(person_id: u32, age: u8);
output relation Health(person_id: u32, state: State);

Health(2, INFECTIOUS) <- Persons(2, _);
Health(p, SUSCEPTIBLE) <- Persons(p, _), p != 2;
```

```expect Health
1, SUSCEPTIBLE
2, INFECTIOUS
3, SUSCEPTIBLE
4, SUSCEPTIBLE
5, SUSCEPTIBLE
6, SUSCEPTIBLE
7, SUSCEPTIBLE
8, SUSCEPTIBLE
```

In words:

> `(2, INFECTIOUS)` is in `Health` **if** person 2 is in `Persons`.
>
> `(p, SUSCEPTIBLE)` is in `Health` **if** `p` is in `Persons` **and** `p` is not 2.

Two things are new here.

**Values in the head.** The heads say which value goes into the `state` column. The first rule
has no variable names at all: its head says exactly which row it is about, and its body only
checks that person 2 exists.

**Several rules for the same relation.** Both rules are about `Health`. Each one says that
some rows are in `Health`, and `Health` holds all of them together: person 2 from the first
rule, everyone else from the second.

## Who is at risk?

A value of your own type can also be written into a row in the body. `Health(p2, INFECTIOUS)`
is about the rows of `Health` whose state is `INFECTIOUS`. Who is at risk of getting infected
at home?

```epiql
AtRisk(p1) <-
    Health(p1, SUSCEPTIBLE),
    Household(p1, h), Household(p2, h),
    Health(p2, INFECTIOUS);
```

> `p1` is in `AtRisk` **if** `p1` is `SUSCEPTIBLE`, **and** `p1` lives in the same household
> `h` as `p2`, **and** `p2` is `INFECTIOUS`.

```epiql run
type State = SUSCEPTIBLE | INFECTIOUS | RECOVERED;

input relation Persons(person_id: u32, age: u8);
input relation Household(person_id: u32, household_id: u32);
relation Health(person_id: u32, state: State);
output relation AtRisk(person_id: u32);

Health(2, INFECTIOUS) <- Persons(2, _);
Health(p, SUSCEPTIBLE) <- Persons(p, _), p != 2;

AtRisk(p1) <-
    Health(p1, SUSCEPTIBLE),
    Household(p1, h), Household(p2, h),
    Health(p2, INFECTIOUS);
```

```expect AtRisk
1
3
4
```

`Health` is declared here without `input` or `output`: it is a relation that the model uses
along the way, but does not show. Only `AtRisk` appears below the program.

Keep this rule in mind: in lesson 5, almost the same rule makes the disease spread.

## Try it yourself

**1.** Person 7 is ill too. Who is at risk now?

```epiql run
type State = SUSCEPTIBLE | INFECTIOUS | RECOVERED;

input relation Persons(person_id: u32, age: u8);
input relation Household(person_id: u32, household_id: u32);
relation Health(person_id: u32, state: State);
output relation AtRisk(person_id: u32);

Health(2, INFECTIOUS) <- Persons(2, _);
Health(p, SUSCEPTIBLE) <- Persons(p, _), p != 2;

AtRisk(p1) <-
    Health(p1, SUSCEPTIBLE),
    Household(p1, h), Household(p2, h),
    Health(p2, INFECTIOUS);
```

```expect AtRisk
1
3
4
8
```

<details>
<summary>Show a hint</summary>

Add a rule for person 7 like the one for person 2. Then make sure that person 7 is not also
susceptible: everyone who is susceptible must be different from 2 **and** from 7.

</details>

<details>
<summary>Show a solution</summary>

```epiql
Health(2, INFECTIOUS) <- Persons(2, _);
Health(7, INFECTIOUS) <- Persons(7, _);
Health(p, SUSCEPTIBLE) <- Persons(p, _), p != 2, p != 7;
```

</details>

**2.** In exercise 1, leave out `p != 7` and run the program again. Who is at risk now, and
why? Make `Health` an `output` relation to see what goes on.

<details>
<summary>Show the answer</summary>

Person 7 is now both `INFECTIOUS` and `SUSCEPTIBLE`: each of the two rules says that a row
for person 7 is in `Health`, and `Health` holds both. So person 7 is at risk of being infected
by themselves. A column of type `State` holds one value per row, but nothing stops a relation
from having two rows for the same person: the rules have to take care of that.

</details>

**3.** Change `INFECTIOUS` into `INFECTOUS` in one of the rules (a typing error) and run the
program. EpiQL does not know a value `INFECTOUS`, so it takes it for a variable name, and says
that this variable name is not defined. When you see that message about something in capitals,
check its spelling, and check that it is in the type.

**4.** Many diseases have a period in which someone is infected, but not yet infectious: they
are **exposed**. Add `EXPOSED` to the
type, and make person 1 exposed. Who is at risk now?

```epiql run
type State = SUSCEPTIBLE | INFECTIOUS | RECOVERED;

input relation Persons(person_id: u32, age: u8);
input relation Household(person_id: u32, household_id: u32);
relation Health(person_id: u32, state: State);
output relation AtRisk(person_id: u32);

Health(2, INFECTIOUS) <- Persons(2, _);
Health(p, SUSCEPTIBLE) <- Persons(p, _), p != 2;

AtRisk(p1) <-
    Health(p1, SUSCEPTIBLE),
    Household(p1, h), Household(p2, h),
    Health(p2, INFECTIOUS);
```

```expect AtRisk
3
4
```

<details>
<summary>Show a solution</summary>

```epiql
type State = SUSCEPTIBLE | EXPOSED | INFECTIOUS | RECOVERED;

Health(2, INFECTIOUS) <- Persons(2, _);
Health(1, EXPOSED) <- Persons(1, _);
Health(p, SUSCEPTIBLE) <- Persons(p, _), p != 2, p != 1;
```

Person 1 is no longer at risk: they are infected already. Only susceptible people can be.

</details>



## What you learned

- `type Name = A | B | C;` defines your own type, with exactly the values listed.
- Values are written in capitals, such as `INFECTIOUS`.
- A value can be written in the head of a rule, or in a row in its body.
- Several rules can be about the same relation; the relation holds the rows of all of them.
- A relation without `input` or `output` is used inside the model, but not shown.
- An "undefined variable name" in capitals usually is a misspelled value.

In the next lesson, the health of a person starts to change over time.
