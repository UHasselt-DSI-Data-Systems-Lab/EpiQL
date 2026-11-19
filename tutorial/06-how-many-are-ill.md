# How many are ill?

For eight people, you can follow every person in the tables. For a country, you cannot: you want
numbers, such as how many people are infectious on each day. 

## Counting

```epiql
output temporal relation NumInfectious(num: u32);

NumInfectious@now(agg::count(p)) <- Status@now(p, INFECTIOUS);
```

`agg::count(p)` in the head is not a single value, but a count: the number of rows for which
the body holds. In words:

> On every day, `NumInfectious` holds the number of persons `p` who are `INFECTIOUS` on that
> day.

`NumInfectious` has one row on every day, with one number in it. Here is the model of the last
lesson with this rule added. Before you run it, use the table in "What happened" of the last
lesson to predict the numbers.

```epiql run timesteps=10
type State = SUSCEPTIBLE | EXPOSED | INFECTIOUS | RECOVERED;

input relation Persons(person_id: u32, age: u8);
input relation Household(person_id: u32, household_id: u32);
input relation School(person_id: u32, school_id: u32);
output temporal relation Status(person_id: u32, state: State);
temporal relation Transition(person_id: u32, state: State);
relation Contact(person: u32, other: u32);

# Who meets whom
Contact(p1, p2) <- Household(p1, h), Household(p2, h), p1 != p2;
Contact(p1, p2) <- School(p1, s), School(p2, s), p1 != p2;

# Day 0
Status@init(2, INFECTIOUS) <- Persons(2, _);
Status@init(p, SUSCEPTIBLE) <- Persons(p, _), p != 2;

# What changes
Transition@now(p1, EXPOSED) <-
    Status@now(p1, SUSCEPTIBLE),
    Contact(p1, p2),
    Status@now(p2, INFECTIOUS);
Transition@now(p, INFECTIOUS) <- Status@now(p, EXPOSED);
Transition@now(p, RECOVERED) <- Status@now(p, INFECTIOUS);

# From one day to the next
Status@[now+1](p, s) <- Transition@now(p, s);
Status@[now+1](p, s) <- Status@now(p, s), not Transition@now(p, _);

# Counting
output temporal relation NumInfectious(num: u32);
NumInfectious@now(agg::count(p)) <- Status@now(p, INFECTIOUS);
```

```expect NumInfectious@2
3
```

A relation with one number per day is shown as a table per day, like `Status`. *Chart*
shows the same numbers as a curve over time.

Mind what is counted: `agg::count` counts the rows for which the body holds. Here, that is one
row for every infectious person, so it counts people. In a body where the same person can
match in several ways, that person would be counted several times.

## Counting per group

An SEIR model is usually shown with four curves: one for each state. You could write four
rules, one per state. But you can also count per group:

```epiql
output temporal relation PerState(state: State, num: u32);

PerState@now(s, agg::count(p)) <- Status@now(p, s);
```

The head now has an ordinary variable name, `s`, next to the count. That makes a count for
every value of `s`:

> On every day, `PerState` holds, for every state `s`, the number of persons `p` who have state
> `s` on that day.

```epiql run timesteps=10
type State = SUSCEPTIBLE | EXPOSED | INFECTIOUS | RECOVERED;

input relation Persons(person_id: u32, age: u8);
input relation Household(person_id: u32, household_id: u32);
input relation School(person_id: u32, school_id: u32);
temporal relation Status(person_id: u32, state: State);
temporal relation Transition(person_id: u32, state: State);
relation Contact(person: u32, other: u32);

# Who meets whom
Contact(p1, p2) <- Household(p1, h), Household(p2, h), p1 != p2;
Contact(p1, p2) <- School(p1, s), School(p2, s), p1 != p2;

# Day 0
Status@init(2, INFECTIOUS) <- Persons(2, _);
Status@init(p, SUSCEPTIBLE) <- Persons(p, _), p != 2;

# What changes
Transition@now(p1, EXPOSED) <-
    Status@now(p1, SUSCEPTIBLE),
    Contact(p1, p2),
    Status@now(p2, INFECTIOUS);
Transition@now(p, INFECTIOUS) <- Status@now(p, EXPOSED);
Transition@now(p, RECOVERED) <- Status@now(p, INFECTIOUS);

# From one day to the next
Status@[now+1](p, s) <- Transition@now(p, s);
Status@[now+1](p, s) <- Status@now(p, s), not Transition@now(p, _);

# Counting
output temporal relation PerState(state: State, num: u32);
PerState@now(s, agg::count(p)) <- Status@now(p, s);
```

```expect PerState@2
INFECTIOUS, 3
RECOVERED, 1
SUSCEPTIBLE, 4
```

On day 1, nobody is infectious: the people who were infected on day 0 are still exposed. A group
without any rows gets no count at all, rather than a count of 0: on day 1, `PerState` has no
row for `INFECTIOUS`. Go to day 1 to see that. In the chart, such a day is a gap in the
line, and a count with a gap on both sides is a dot. (`NumInfectious` above did give 0,
because it has no groups: it always has exactly one count.)

`Status` is no longer an `output` relation here, so it is not shown. The model still works
out all of it, because `PerState` needs it.

## More than counting

Besides `agg::count`, there are `agg::sum`, `agg::min`, `agg::max` and `agg::avg`: the sum,
the smallest value, the largest value, and the average of a column.

## Try it yourself

**1.** Children are often counted apart. Add a relation `InfectiousChildren` with the number
of infectious persons younger than 18 on each day.

```epiql run timesteps=10
type State = SUSCEPTIBLE | EXPOSED | INFECTIOUS | RECOVERED;

input relation Persons(person_id: u32, age: u8);
input relation Household(person_id: u32, household_id: u32);
input relation School(person_id: u32, school_id: u32);
temporal relation Status(person_id: u32, state: State);
temporal relation Transition(person_id: u32, state: State);
relation Contact(person: u32, other: u32);

# Who meets whom
Contact(p1, p2) <- Household(p1, h), Household(p2, h), p1 != p2;
Contact(p1, p2) <- School(p1, s), School(p2, s), p1 != p2;

# Day 0
Status@init(2, INFECTIOUS) <- Persons(2, _);
Status@init(p, SUSCEPTIBLE) <- Persons(p, _), p != 2;

# What changes
Transition@now(p1, EXPOSED) <-
    Status@now(p1, SUSCEPTIBLE),
    Contact(p1, p2),
    Status@now(p2, INFECTIOUS);
Transition@now(p, INFECTIOUS) <- Status@now(p, EXPOSED);
Transition@now(p, RECOVERED) <- Status@now(p, INFECTIOUS);

# From one day to the next
Status@[now+1](p, s) <- Transition@now(p, s);
Status@[now+1](p, s) <- Status@now(p, s), not Transition@now(p, _);

# Counting
output temporal relation InfectiousChildren(num: u32);
```

```expect InfectiousChildren@2
2
```

<details>
<summary>Show a solution</summary>

```epiql
InfectiousChildren@now(agg::count(p)) <-
    Status@now(p, INFECTIOUS), Persons(p, age), age < 18;
```

</details>

**2.** How many people become infected on each day? Count the new infections, in a relation
`NewInfections`. Look carefully at the days: on which day does the count for person 8 come?

```epiql run timesteps=10
type State = SUSCEPTIBLE | EXPOSED | INFECTIOUS | RECOVERED;

input relation Persons(person_id: u32, age: u8);
input relation Household(person_id: u32, household_id: u32);
input relation School(person_id: u32, school_id: u32);
temporal relation Status(person_id: u32, state: State);
temporal relation Transition(person_id: u32, state: State);
relation Contact(person: u32, other: u32);

# Who meets whom
Contact(p1, p2) <- Household(p1, h), Household(p2, h), p1 != p2;
Contact(p1, p2) <- School(p1, s), School(p2, s), p1 != p2;

# Day 0
Status@init(2, INFECTIOUS) <- Persons(2, _);
Status@init(p, SUSCEPTIBLE) <- Persons(p, _), p != 2;

# What changes
Transition@now(p1, EXPOSED) <-
    Status@now(p1, SUSCEPTIBLE),
    Contact(p1, p2),
    Status@now(p2, INFECTIOUS);
Transition@now(p, INFECTIOUS) <- Status@now(p, EXPOSED);
Transition@now(p, RECOVERED) <- Status@now(p, INFECTIOUS);

# From one day to the next
Status@[now+1](p, s) <- Transition@now(p, s);
Status@[now+1](p, s) <- Status@now(p, s), not Transition@now(p, _);

# Counting
output temporal relation NewInfections(num: u32);
```

```expect NewInfections@0
3
```

<details>
<summary>Show a hint</summary>

A new infection is a row `(p, EXPOSED)` in `Transition`.

</details>

<details>
<summary>Show a solution</summary>

```epiql
NewInfections@now(agg::count(p)) <- Transition@now(p, EXPOSED);
```

Person 8 is counted on day 2: the day on which they are infected. They are exposed on day 3
and infectious on day 4, because `Transition` on one day gives `Status` on the next.

</details>

**3.** What is the average age of the infectious people on each day? Use `agg::avg(age)`. An
average is usually not an integer, so its column needs the type `f64` (see the
[built-in types](types.md)). What do you see for day 1?

```epiql run timesteps=10
type State = SUSCEPTIBLE | EXPOSED | INFECTIOUS | RECOVERED;

input relation Persons(person_id: u32, age: u8);
input relation Household(person_id: u32, household_id: u32);
input relation School(person_id: u32, school_id: u32);
temporal relation Status(person_id: u32, state: State);
temporal relation Transition(person_id: u32, state: State);
relation Contact(person: u32, other: u32);

# Who meets whom
Contact(p1, p2) <- Household(p1, h), Household(p2, h), p1 != p2;
Contact(p1, p2) <- School(p1, s), School(p2, s), p1 != p2;

# Day 0
Status@init(2, INFECTIOUS) <- Persons(2, _);
Status@init(p, SUSCEPTIBLE) <- Persons(p, _), p != 2;

# What changes
Transition@now(p1, EXPOSED) <-
    Status@now(p1, SUSCEPTIBLE),
    Contact(p1, p2),
    Status@now(p2, INFECTIOUS);
Transition@now(p, INFECTIOUS) <- Status@now(p, EXPOSED);
Transition@now(p, RECOVERED) <- Status@now(p, INFECTIOUS);

# From one day to the next
Status@[now+1](p, s) <- Transition@now(p, s);
Status@[now+1](p, s) <- Status@now(p, s), not Transition@now(p, _);

# Counting
output temporal relation AverageAge(age: f64);
```

```expect AverageAge@2
19.0
```

<details>
<summary>Show a hint</summary>

The age of a person is in `Persons`. Combine it with `Status@now`, as in exercise 1, and put
`agg::avg(age)` in the head.

</details>

<details>
<summary>Show a solution</summary>

```epiql
AverageAge@now(agg::avg(age)) <- Status@now(p, INFECTIOUS), Persons(p, age);
```

On day 2, persons 1, 3 and 4 are infectious, aged 42, 9 and 6: their average age is 19.

On day 1, `AverageAge` has no row at all. Nobody is infectious that day, and the average of
no ages at all does not exist. A count without groups is different: there, no rows give a
count of 0, as `NumInfectious` showed.

</details>

## What you learned

- `agg::count(p)` in the head counts the rows for which the body holds.
- With a variable name next to the count, such as `s` in `PerState@now(s, agg::count(p))`,
  there is a count for every value of that variable name.
- A group without any rows gets no count; a count without groups gives 0. An average,
  minimum or maximum of no rows at all gives no row.
- `agg::sum`, `agg::min`, `agg::max` and `agg::avg` work in the same way.

This is the end of the first part of the tutorial: a complete, if simple, epidemic model, whose
every outcome you could predict exactly. In the next part, chance comes in.
