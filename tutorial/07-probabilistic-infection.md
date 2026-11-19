# Probabilistic infection

Until now, every contact infected. In reality, a contact with an infectious person only
*sometimes* leads to an infection. In this lesson, chance comes into the model. From now on,
two runs of the same model can give a different epidemic.

## Flipping a coin

```epiql
distr::bernouilli(0.5)
```

`distr::bernouilli(0.5)` is a Bernouilli trial with probability 0.5: it holds with probability
0.5. You put it in the body of a rule,
like any other condition:

```epiql
Transition@now(p1, EXPOSED) <-
    Status@now(p1, SUSCEPTIBLE),
    Contact(p1, p2),
    Status@now(p2, INFECTIOUS),
    distr::bernouilli(0.5);
```

In words:

> A person `p1` changes to `EXPOSED` **if** `p1` is `SUSCEPTIBLE` today, **and** `p1` has
> contact with `p2`, **and** `p2` is `INFECTIOUS` today, **and** a coin flip says yes.

Here is the model of lesson 5, with this infection rule. `NumInfected` counts the people
who have been infected so far: everyone who is no longer `SUSCEPTIBLE`. The program runs for
14 timesteps, because with chance, the epidemic can take longer. And it runs 5 times at once,
so that you can compare the runs. Is the epidemic the same in every run?

```epiql run timesteps=14 runs=5
type State = SUSCEPTIBLE | EXPOSED | INFECTIOUS | RECOVERED;

input relation Persons(person_id: u32, age: u8);
input relation Household(person_id: u32, household_id: u32);
input relation School(person_id: u32, school_id: u32);
output temporal relation Status(person_id: u32, state: State);
temporal relation Transition(person_id: u32, state: State);
relation Contact(person: u32, other: u32);
output temporal relation NumInfected(num: u32);

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
    Status@now(p2, INFECTIOUS),
    distr::bernouilli(0.5);
Transition@now(p, INFECTIOUS) <- Status@now(p, EXPOSED);
Transition@now(p, RECOVERED) <- Status@now(p, INFECTIOUS);

# From one day to the next
Status@[now+1](p, s) <- Transition@now(p, s);
Status@[now+1](p, s) <- Status@now(p, s), not Transition@now(p, _);

# Counting
NumInfected@now(agg::count(p)) <- Status@now(p, s), s != SUSCEPTIBLE;
```

`NumInfected` has a column for each run, and *Chart* shows a line for each run. For
`Status`, the buttons *Run 1* to *Run 5* choose which run you see.

Each run flips new coins, so each run can give another epidemic. Sometimes person 2 infects
nobody at all, and the epidemic is over before it started. Sometimes it reaches household 3.
Persons 5 and 6 still never get ill: chance does not give them contacts they do not have. Run
the program again for five new runs.

A probability is a number between 0 and 1, written with a decimal point: `1.0`, not `1`.

## One coin for each contact

A rule with `distr::bernouilli` flips a coin for each way in which its body holds. Suppose
that person 8 has two infectious schoolmates, persons 3 and 4. Then the body holds twice for
person 8: once with `p2` = 3, and once with `p2` = 4. Each gets its own coin flip, so person 8
has two chances of being infected: the probability is 1 − 0.5 × 0.5 = 0.75. The more
infectious people someone meets, the more likely they get infected, as in reality.

And if both coins say yes? Then both give the row `(8, EXPOSED)`. A rule written with `<-`
eliminates duplicates, so `Transition` gets that row once.

## `<-` and `<--`

You can also use the longer arrow, `<--`. The
difference with `<-` is **duplicate elimination**: a rule with `<-` removes duplicate rows
from its result, a rule with `<--` does not.

Take the numbers of the households in `Household`:

```epiql
HouseholdIds(h) <- Household(p, h);
```

```data Household(person_id, household_id)
```

The body holds once for every row of `Household`, but the head drops `p`, so several rows
give the same household number:

| With `<-` | With `<--` |
| --- | --- |
| 1 | 1 |
| 2 | 1 |
| 3 | 1 |
| | 1 |
| | 2 |
| | 2 |
| | 3 |
| | 3 |

Now add a Bernouilli trial to the body:

```epiql
HouseholdIds(h) <- Household(p, h), distr::bernouilli(0.5);
```

EpiQL first does a trial for every row for which the body holds: eight trials, one for each
person. Only then does it eliminate duplicates. This is one possible outcome:

| person_id | household_id | trial |
| --- | --- | --- |
| 1 | 1 | yes |
| 2 | 1 | no |
| 3 | 1 | yes |
| 4 | 1 | no |
| 5 | 2 | no |
| 6 | 2 | no |
| 7 | 3 | yes |
| 8 | 3 | no |

| With `<-` | With `<--` |
| --- | --- |
| 1 | 1 |
| 3 | 1 |
| | 3 |

Household 1 is in the result with `<-` if at least one of its four trials says yes: that
happens with probability 1 − 0.5⁴ ≈ 0.94. Households 2 and 3 have two trials each, so
probability 1 − 0.5² = 0.75. If duplicates were eliminated before the trials, each household
would get a single trial, with probability 0.5. This is why person 8, with two infectious
schoolmates, has two chances of being infected.



## Drawing a value

`distr::bernouilli` says yes or no. Sometimes you want to draw one value out of several. In
the model for the Belgian population, nobody knows on day 0 who is ill: each person starts
`EXPOSED` with a small probability, and `SUSCEPTIBLE` otherwise:

```epiql
Transition@init(p, s) <-- Persons(p, _), s ~ distr::discrete(SUSCEPTIBLE, 0.75, EXPOSED, 0.25);
```

`s ~ distr::discrete(SUSCEPTIBLE, 0.75, EXPOSED, 0.25)` draws a value for the variable name
`s`: `SUSCEPTIBLE` with probability 0.75, and `EXPOSED` with probability 0.25. After each
value comes its probability, and together they add up to 1. In words:

> Person `p` changes to state `s` at the end of day 0 **if** `p` is in `Persons`, **and** `s`
> is drawn from: `SUSCEPTIBLE` with probability 0.75, `EXPOSED` with probability 0.25.

Every person gets their own draw. The rule gives one row per person, so `<--` is safe here.

There is also `distr::uniform`, which draws each of its values with the same probability:
`k ~ distr::uniform(2, 3, 4)` is 2, 3 or 4, each with probability one third.

## Try it yourself

**1.** With which probability in the infection rule do you get back the epidemic of lesson 5,
in every run? Change it and run the program to check.

```epiql run timesteps=14 runs=5
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
    Status@now(p2, INFECTIOUS),
    distr::bernouilli(0.5);
Transition@now(p, INFECTIOUS) <- Status@now(p, EXPOSED);
Transition@now(p, RECOVERED) <- Status@now(p, INFECTIOUS);

# From one day to the next
Status@[now+1](p, s) <- Transition@now(p, s);
Status@[now+1](p, s) <- Status@now(p, s), not Transition@now(p, _);
```

```expect Status@1
1, EXPOSED
2, RECOVERED
3, EXPOSED
4, EXPOSED
5, SUSCEPTIBLE
6, SUSCEPTIBLE
7, SUSCEPTIBLE
8, SUSCEPTIBLE
```

```expect Status@8
1, RECOVERED
2, RECOVERED
3, RECOVERED
4, RECOVERED
5, SUSCEPTIBLE
6, SUSCEPTIBLE
7, RECOVERED
8, RECOVERED
```

<details>
<summary>Show a solution</summary>

```epiql
distr::bernouilli(1.0)
```

A coin that always says yes: every contact infects, as in lesson 5. With `0.0`, nobody is
ever infected, and only person 2 is ever ill.

</details>

**2.** Infection is more likely at home, where people are close together for a long time,
than at school. Replace the infection rule with two rules: one for contacts at home, with
probability `1.0`, and one for contacts at school, with probability `0.0`. Use `Household`
and `School` directly in their bodies, instead of `Contact`. Who gets ill?

```epiql run timesteps=14 runs=5
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
    Status@now(p2, INFECTIOUS),
    distr::bernouilli(0.5);
Transition@now(p, INFECTIOUS) <- Status@now(p, EXPOSED);
Transition@now(p, RECOVERED) <- Status@now(p, INFECTIOUS);

# From one day to the next
Status@[now+1](p, s) <- Transition@now(p, s);
Status@[now+1](p, s) <- Status@now(p, s), not Transition@now(p, _);
```

```expect Status@1
1, EXPOSED
2, RECOVERED
3, EXPOSED
4, EXPOSED
5, SUSCEPTIBLE
6, SUSCEPTIBLE
7, SUSCEPTIBLE
8, SUSCEPTIBLE
```

```expect Status@13
1, RECOVERED
2, RECOVERED
3, RECOVERED
4, RECOVERED
5, SUSCEPTIBLE
6, SUSCEPTIBLE
7, SUSCEPTIBLE
8, SUSCEPTIBLE
```

<details>
<summary>Show a hint</summary>

Two people live together if `Household(p1, h), Household(p2, h), p1 != p2`, as in the rule for
`Contact`.

</details>

<details>
<summary>Show a solution</summary>

```epiql
Transition@now(p1, EXPOSED) <-
    Status@now(p1, SUSCEPTIBLE),
    Household(p1, h), Household(p2, h), p1 != p2,
    Status@now(p2, INFECTIOUS),
    distr::bernouilli(1.0);
Transition@now(p1, EXPOSED) <-
    Status@now(p1, SUSCEPTIBLE),
    School(p1, s), School(p2, s), p1 != p2,
    Status@now(p2, INFECTIOUS),
    distr::bernouilli(0.0);
```

Only household 1 gets ill: with probability `0.0`, the school never passes the disease on.
Now try more realistic probabilities, such as `0.5` at home and `0.2` at school, and run the
program again. In how many of the runs does the disease reach household 3?

The model for the Belgian population works in the same way, but takes the probability from
an input file, with a probability for each kind of place and each pair of ages.

</details>

**3.** Replace the first patient by a random start: replace the two rules for day 0 with the
rule with `distr::discrete` above. Who is ill on day 1, in each run? Does it happen that
nobody is?

The program also counts the persons in `Status` on each day, in `NumPersons`. However the
draws come out, `Status` is empty on day 0, and every person has exactly one state on every
day from day 1 on. So `NumPersons` must be 0 on day 0, and 8 on day 1, in every run.

```epiql run timesteps=14 runs=5
type State = SUSCEPTIBLE | EXPOSED | INFECTIOUS | RECOVERED;

input relation Persons(person_id: u32, age: u8);
input relation Household(person_id: u32, household_id: u32);
input relation School(person_id: u32, school_id: u32);
output temporal relation Status(person_id: u32, state: State);
temporal relation Transition(person_id: u32, state: State);
relation Contact(person: u32, other: u32);
output temporal relation NumPersons(num: u32);

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
    Status@now(p2, INFECTIOUS),
    distr::bernouilli(0.5);
Transition@now(p, INFECTIOUS) <- Status@now(p, EXPOSED);
Transition@now(p, RECOVERED) <- Status@now(p, INFECTIOUS);

# From one day to the next
Status@[now+1](p, s) <- Transition@now(p, s);
Status@[now+1](p, s) <- Status@now(p, s), not Transition@now(p, _);

# Counting
NumPersons@now(agg::count(p)) <- Status@now(p, _);
```

```expect NumPersons@0
0
```

```expect NumPersons@1
8
```

<details>
<summary>Show a solution</summary>

```epiql
Transition@init(p, s) <-- Persons(p, _), s ~ distr::discrete(SUSCEPTIBLE, 0.75, EXPOSED, 0.25);
```

Each person has a probability of 0.75 of starting susceptible. The probability that all eight
do, so that nobody is ever ill, is 0.75 multiplied by itself eight times: about 0.1. So about
one run in ten has no epidemic at all.

If you keep the old rules for day 0 as well, `NumPersons` is 8 on day 0, but more than 8 on day
1: the people who are drawn `EXPOSED` also keep their state of day 0.

</details>


## What you learned

- `distr::bernouilli(0.5)` in the body holds with probability 0.5. A probability is written
  with a decimal point.
- A rule flips a coin for each way in which its body holds: two infectious contacts give two
  chances of being infected.
- A rule with `<-` eliminates duplicates; a rule with `<--` does not. `<--` is faster, and
  safe when the rule cannot give duplicates. When in doubt, write `<-`.
- `s ~ distr::discrete(A, 0.75, B, 0.25)` draws a value for `s`: `A` with probability 0.75,
  `B` with probability 0.25. `distr::uniform` draws each value with the same probability.
- With chance, two runs of the same model can differ. Check what holds in every run.

In the next lesson, being exposed and being infectious last a realistic number of days.
