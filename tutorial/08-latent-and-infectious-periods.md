# Latent and infectious periods

So far, everyone was exposed for exactly one day, and infectious for exactly one day. Real
diseases take longer, and not equally long for everyone: the **latent period** (exposed, but
not yet infectious) and the **infectious period** last a number of days that differs from
person to person. In this lesson, a change can happen a number of days after another one.

## A change a few days later

```epiql
Transition@[now+3](p, RECOVERED) <- Transition@now(p, INFECTIOUS);
```

`@[now+3]` is the timestep 3 days after `now`. In words:

> Person `p` changes to `RECOVERED` 3 days after the day on which `p` changes to
> `INFECTIOUS`.

A change at the end of day `now` gives the new state from the next day on (lesson 4). So a
person who changes to `INFECTIOUS` on day 5 is infectious on days 6, 7 and 8, changes to
`RECOVERED` at the end of day 8, and is recovered from day 9 on: infectious for exactly 3
days.

Note the body: `Transition@now(p, INFECTIOUS)`, not `Status@now(p, INFECTIOUS)`. A person
*changes* to `INFECTIOUS` on one day only, but *is* infectious on several days. The rule
should plan the recovery once, on the day of the change. Exercise 2 shows what goes wrong
otherwise.

Because the delays start from a change, the first patient has to start with a change too.
As in exercise 2 of lesson 4, day 0 has the rules for `Transition@init` instead of
`Status@init`, so `Status` starts on day 1.

Here is the model of lesson 5, with a latent period of 2 days and an infectious period of 3
days. Every contact infects again, so that you can predict the outcome. Before you run it:
on which days is person 2 infectious? When are persons 1, 3 and 4 exposed?

```epiql run timesteps=20
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

# Day 0: the first states are changes
Transition@init(2, INFECTIOUS) <- Persons(2, _);
Transition@init(p, SUSCEPTIBLE) <- Persons(p, _), p != 2;

# What changes
Transition@now(p1, EXPOSED) <-
    Status@now(p1, SUSCEPTIBLE),
    Contact(p1, p2),
    Status@now(p2, INFECTIOUS);
Transition@[now+2](p, INFECTIOUS) <- Transition@now(p, EXPOSED);
Transition@[now+3](p, RECOVERED) <- Transition@now(p, INFECTIOUS);

# From one day to the next
Status@[now+1](p, s) <- Transition@now(p, s);
Status@[now+1](p, s) <- Status@now(p, s), not Transition@now(p, _);
```

```expect Status@4
1, INFECTIOUS
2, RECOVERED
3, INFECTIOUS
4, INFECTIOUS
5, SUSCEPTIBLE
6, SUSCEPTIBLE
7, SUSCEPTIBLE
8, SUSCEPTIBLE
```

<details>
<summary>What happened</summary>

| Days | Exposed | Infectious |
| --- | --- | --- |
| 1–3 | | 2 |
| 2–3 | 1, 3, 4 | |
| 4–6 | | 1, 3, 4 |
| 5–6 | 8 | |
| 7–9 | | 8 |
| 8–9 | 7 | |
| 10–12 | | 7 |

Persons 1, 3 and 4 are infected on day 1, the first day on which person 2 is infectious. The
epidemic is over on day 13.

</details>

## A delay drawn by chance

The number of days can also be a variable name, whose value is drawn:

```epiql
Transition@[now+k](p, INFECTIOUS) <-- Transition@now(p, EXPOSED), k ~ distr::uniform(1, 2, 3);
```

> Person `p` changes to `INFECTIOUS` `k` days after the day on which `p` changes to
> `EXPOSED`, **where** `k` is 1, 2 or 3, each with the same probability.

Every change to `EXPOSED` gets its own draw, so every person gets their own latent period.
`distr::discrete` gives the days different probabilities: with
`k ~ distr::discrete(2, 0.25, 3, 0.5, 4, 0.25)`, an infectious period of 3 days is twice as
likely as one of 2 or of 4 days. Both rules give one row for each row of `Transition`, so
`<--` is safe (lesson 7).


Here is the model with chance in the infection rule, as in lesson 7, and in both periods. It
runs 5 times, for 40 timesteps. How different are the epidemic curves?

```epiql run timesteps=40 runs=5
type State = SUSCEPTIBLE | EXPOSED | INFECTIOUS | RECOVERED;

input relation Persons(person_id: u32, age: u8);
input relation Household(person_id: u32, household_id: u32);
input relation School(person_id: u32, school_id: u32);
output temporal relation Status(person_id: u32, state: State);
temporal relation Transition(person_id: u32, state: State);
relation Contact(person: u32, other: u32);
output temporal relation NumInfectious(num: u32);

# Who meets whom
Contact(p1, p2) <- Household(p1, h), Household(p2, h), p1 != p2;
Contact(p1, p2) <- School(p1, s), School(p2, s), p1 != p2;

# Day 0: the first states are changes
Transition@init(2, INFECTIOUS) <- Persons(2, _);
Transition@init(p, SUSCEPTIBLE) <- Persons(p, _), p != 2;

# What changes
Transition@now(p1, EXPOSED) <-
    Status@now(p1, SUSCEPTIBLE),
    Contact(p1, p2),
    Status@now(p2, INFECTIOUS),
    distr::bernouilli(0.5);
Transition@[now+k](p, INFECTIOUS) <-- Transition@now(p, EXPOSED), k ~ distr::uniform(1, 2, 3);
Transition@[now+k](p, RECOVERED) <--
    Transition@now(p, INFECTIOUS),
    k ~ distr::discrete(2, 0.25, 3, 0.5, 4, 0.25);

# From one day to the next
Status@[now+1](p, s) <- Transition@now(p, s);
Status@[now+1](p, s) <- Status@now(p, s), not Transition@now(p, _);

# Counting
NumInfectious@now(agg::count(p)) <- Status@now(p, INFECTIOUS);
```

## Try it yourself

**1.** Make the infectious period 5 days instead of 3, in the model without chance. Who is
infectious on day 4 now? On which day is person 2 recovered? And is anyone else ill for longer?

```epiql run timesteps=20
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

# Day 0: the first states are changes
Transition@init(2, INFECTIOUS) <- Persons(2, _);
Transition@init(p, SUSCEPTIBLE) <- Persons(p, _), p != 2;

# What changes
Transition@now(p1, EXPOSED) <-
    Status@now(p1, SUSCEPTIBLE),
    Contact(p1, p2),
    Status@now(p2, INFECTIOUS);
Transition@[now+2](p, INFECTIOUS) <- Transition@now(p, EXPOSED);
Transition@[now+3](p, RECOVERED) <- Transition@now(p, INFECTIOUS);

# From one day to the next
Status@[now+1](p, s) <- Transition@now(p, s);
Status@[now+1](p, s) <- Status@now(p, s), not Transition@now(p, _);
```

```expect Status@4
1, INFECTIOUS
2, INFECTIOUS
3, INFECTIOUS
4, INFECTIOUS
5, SUSCEPTIBLE
6, SUSCEPTIBLE
7, SUSCEPTIBLE
8, SUSCEPTIBLE
```

<details>
<summary>Show a solution</summary>

```epiql
Transition@[now+5](p, RECOVERED) <- Transition@now(p, INFECTIOUS);
```

Person 2 is infectious on days 1 to 5, and recovered from day 6 on. Everyone who gets ill is
now ill for longer, but the same people get ill: in this model, everyone they meet is
infected on the first day anyway.

</details>

**2.** In the model below, which is the model without chance, the rule for `INFECTIOUS` uses
`Status@now(p, EXPOSED)` instead of `Transition@now(p, EXPOSED)`. `Transition` is an `output`
relation, so that you can see it. How many times does person 1 change to `INFECTIOUS`? And
how long is person 1 exposed?

```epiql run timesteps=20
type State = SUSCEPTIBLE | EXPOSED | INFECTIOUS | RECOVERED;

input relation Persons(person_id: u32, age: u8);
input relation Household(person_id: u32, household_id: u32);
input relation School(person_id: u32, school_id: u32);
output temporal relation Status(person_id: u32, state: State);
output temporal relation Transition(person_id: u32, state: State);
relation Contact(person: u32, other: u32);

# Who meets whom
Contact(p1, p2) <- Household(p1, h), Household(p2, h), p1 != p2;
Contact(p1, p2) <- School(p1, s), School(p2, s), p1 != p2;

# Day 0: the first states are changes
Transition@init(2, INFECTIOUS) <- Persons(2, _);
Transition@init(p, SUSCEPTIBLE) <- Persons(p, _), p != 2;

# What changes
Transition@now(p1, EXPOSED) <-
    Status@now(p1, SUSCEPTIBLE),
    Contact(p1, p2),
    Status@now(p2, INFECTIOUS);
Transition@[now+2](p, INFECTIOUS) <- Status@now(p, EXPOSED);
Transition@[now+3](p, RECOVERED) <- Transition@now(p, INFECTIOUS);

# From one day to the next
Status@[now+1](p, s) <- Transition@now(p, s);
Status@[now+1](p, s) <- Status@now(p, s), not Transition@now(p, _);
```

<details>
<summary>Show the answer</summary>

Person 1 changes to `INFECTIOUS` three times: on days 4, 5 and 6. The rule holds on every day
on which person 1 is exposed, and each of those days plans a change two days later. Person 1
is exposed on days 2, 3 and 4: one day longer than intended, because the change planned on
day 2 only takes effect on day 5. And the extra changes plan extra recoveries.

With a drawn delay, it is worse: each day draws its own delay, so a change planned late can
come after the person has recovered, and make them infectious again. So a delay should start
from a change: `Transition@now`, not `Status@now`.

</details>

**3.** In the model with chance, the periods are different in every run. But however the
draws come out, an epidemic in Tiny Town is over by day 40: nobody can be ill for more than
7 days, and the disease can pass from person to person at most five times. The program runs
for 45 timesteps. Write a rule
for `NumSick`, the number of people who are exposed or infectious on each day, and check
that it is 0 on the last day, in every run.

```epiql run timesteps=45 runs=5
type State = SUSCEPTIBLE | EXPOSED | INFECTIOUS | RECOVERED;

input relation Persons(person_id: u32, age: u8);
input relation Household(person_id: u32, household_id: u32);
input relation School(person_id: u32, school_id: u32);
output temporal relation Status(person_id: u32, state: State);
temporal relation Transition(person_id: u32, state: State);
relation Contact(person: u32, other: u32);
output temporal relation NumSick(num: u32);

# Who meets whom
Contact(p1, p2) <- Household(p1, h), Household(p2, h), p1 != p2;
Contact(p1, p2) <- School(p1, s), School(p2, s), p1 != p2;

# Day 0: the first states are changes
Transition@init(2, INFECTIOUS) <- Persons(2, _);
Transition@init(p, SUSCEPTIBLE) <- Persons(p, _), p != 2;

# What changes
Transition@now(p1, EXPOSED) <-
    Status@now(p1, SUSCEPTIBLE),
    Contact(p1, p2),
    Status@now(p2, INFECTIOUS),
    distr::bernouilli(0.5);
Transition@[now+k](p, INFECTIOUS) <-- Transition@now(p, EXPOSED), k ~ distr::uniform(1, 2, 3);
Transition@[now+k](p, RECOVERED) <--
    Transition@now(p, INFECTIOUS),
    k ~ distr::discrete(2, 0.25, 3, 0.5, 4, 0.25);

# From one day to the next
Status@[now+1](p, s) <- Transition@now(p, s);
Status@[now+1](p, s) <- Status@now(p, s), not Transition@now(p, _);
```

```expect NumSick
0
```

<details>
<summary>Show a hint</summary>

Count as in lesson 6: `agg::count(p)` in the head. A person is exposed or infectious if
their state `s` is neither `SUSCEPTIBLE` nor `RECOVERED`.

</details>

<details>
<summary>Show a solution</summary>

```epiql
NumSick@now(agg::count(p)) <- Status@now(p, s), s != SUSCEPTIBLE, s != RECOVERED;
```

`s in [EXPOSED, INFECTIOUS]` says the same: `s` is one of the values in the list.

</details>

## What you learned

- `@[now+3]` in the head is 3 timesteps after `now`; `@[now+k]` is `k` timesteps later, where
  `k` can be drawn with `distr::uniform` or `distr::discrete`.
- A delay should start from a change (`Transition@now`), which happens on one day, not from
  a state (`Status@now`), which lasts several days.
- Because the delays start from a change, the first patient starts with `Transition@init`.
- With chance, check facts that hold in every run, such as "the epidemic is over by day 40".

You now know most of what the model for the Belgian population uses. In the next lesson, you
read it from top to bottom, and meet the few parts that are still new.
