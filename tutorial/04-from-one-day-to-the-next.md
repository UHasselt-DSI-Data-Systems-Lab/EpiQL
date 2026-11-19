# From one day to the next

EpiQL simulates time in discrete timesteps 
numbered 0, 1, 2, and so on. In this tutorial, one timestep is one day.

Some relations are the same throughout the simulation: Tiny Town's people and households do
not change. But the state of a person does change from day to day. A relation whose rows
can be different at every timestep is a **temporal** relation:

```epiql
temporal relation Status(person_id: u32, state: State);
```

You can think of a temporal relation as one table per timestep: a `Status` for day 0, another
`Status` for day 1, and so on.

## The first patient

At the start of the simulation, on day 0, person 2 is infectious, and everyone else is
susceptible. These are the rules for `Health` from the last lesson, but now for `Status` at
the first timestep:

```epiql
Status@init(2, INFECTIOUS) <- Persons(2, _);
Status@init(p, SUSCEPTIBLE) <- Persons(p, _), p != 2;
```

`@init` after a relation name means: at timestep 0. In words:

> `(2, INFECTIOUS)` is in `Status` at timestep 0 **if** person 2 is in `Persons`.
>
> `(p, SUSCEPTIBLE)` is in `Status` at timestep 0 **if** `p` is in `Persons` **and** `p` is
> not 2.

This program runs for 4 timesteps. Before you run it: what do you expect `Status` to be on
day 0? And on day 1?

```epiql run timesteps=4
type State = SUSCEPTIBLE | INFECTIOUS | RECOVERED;

input relation Persons(person_id: u32, age: u8);
output temporal relation Status(person_id: u32, state: State);

Status@init(2, INFECTIOUS) <- Persons(2, _);
Status@init(p, SUSCEPTIBLE) <- Persons(p, _), p != 2;
```

```expect Status@0
1, SUSCEPTIBLE
2, INFECTIOUS
3, SUSCEPTIBLE
4, SUSCEPTIBLE
5, SUSCEPTIBLE
6, SUSCEPTIBLE
7, SUSCEPTIBLE
8, SUSCEPTIBLE
```

The result of a temporal relation is shown one timestep at a time. Use the slider, or the
buttons next to it, to go from one timestep to the next.

## Nothing happens by itself

Day 0 is as expected, but days 1, 2 and 3 are empty. The two rules only say which rows are in
`Status` at timestep 0. No rule says anything about any other day, so on those days `Status`
has no rows at all.

That may be surprising: you might expect people to stay susceptible until something happens
to them. But EpiQL only knows what the rules say. So let's write the rules for what happens
from one day to the next.

## Staying the same

The simplest thing that can happen is nothing: everyone keeps the state they have.

```epiql
Status@[now+1](p, s) <- Status@now(p, s);
```

`now` stands for any timestep, and `now+1` for the timestep after it. In words:

> `(p, s)` is in `Status` at timestep `now+1` **if** `(p, s)` is in `Status` at timestep
> `now`.

This one rule is about every day at once. Day 0 says what day 1 is; day 1 in its turn says
what day 2 is, and so on.

```epiql run timesteps=5
type State = SUSCEPTIBLE | INFECTIOUS | RECOVERED;

input relation Persons(person_id: u32, age: u8);
output temporal relation Status(person_id: u32, state: State);

Status@init(2, INFECTIOUS) <- Persons(2, _);
Status@init(p, SUSCEPTIBLE) <- Persons(p, _), p != 2;

Status@[now+1](p, s) <- Status@now(p, s);
```

## Recovering

Now let infectious people recover after one day. (That is far too fast for a real disease;
later lessons make it more realistic.)

```epiql
Status@[now+1](p, RECOVERED) <- Status@now(p, INFECTIOUS);
```

The program below has both rules. Before you run it: what do you expect for person 2 on day 1?

```epiql run timesteps=2
type State = SUSCEPTIBLE | INFECTIOUS | RECOVERED;

input relation Persons(person_id: u32, age: u8);
output temporal relation Status(person_id: u32, state: State);

Status@init(2, INFECTIOUS) <- Persons(2, _);
Status@init(p, SUSCEPTIBLE) <- Persons(p, _), p != 2;

Status@[now+1](p, s) <- Status@now(p, s);
Status@[now+1](p, RECOVERED) <- Status@now(p, INFECTIOUS);
```

On day 1, person 2 is both `INFECTIOUS` and `RECOVERED`. Both rules hold for person 2: the
first says that the state stays `INFECTIOUS`, the second that it is `RECOVERED`. A rule never
removes or replaces a row; it only says that a row is there. So we have to be precise about
*when* a state stays the same: only when it does not change.

## Changes and `not`

To say that, we first write down the changes in a relation of their own:

```epiql
temporal relation Transition(person_id: u32, state: State);
```

`(p, s)` in `Transition` at timestep `now` means: person `p` changes to state `s` at the end
of day `now`. Then three rules describe the whole course of a day:

```epiql
Transition@now(p, RECOVERED) <- Status@now(p, INFECTIOUS);
Status@[now+1](p, s) <- Transition@now(p, s);
Status@[now+1](p, s) <- Status@now(p, s), not Transition@now(p, _);
```

In words:

> A person changes to `RECOVERED` **if** they are `INFECTIOUS`.
>
> A person has state `s` tomorrow **if** they change to `s` today.
>
> A person has state `s` tomorrow **if** they have state `s` today **and** they do **not**
> change today.

`not` in front of a row means that there is no such row. `not Transition@now(p, _)` holds
when `Transition` has no row at all for person `p` today: whatever the state, as `_` stands
for any value.

`not` can only check for rows about values that are already known. In the last rule,
`Status@now(p, s)` says who `p` is; `not Transition@now(p, _)` then checks that there is no
change for that person. A rule whose variable names appear only after `not` would be about
every possible value, and EpiQL does not accept it.

```epiql run timesteps=5
type State = SUSCEPTIBLE | INFECTIOUS | RECOVERED;

input relation Persons(person_id: u32, age: u8);
output temporal relation Status(person_id: u32, state: State);
temporal relation Transition(person_id: u32, state: State);

Status@init(2, INFECTIOUS) <- Persons(2, _);
Status@init(p, SUSCEPTIBLE) <- Persons(p, _), p != 2;

Transition@now(p, RECOVERED) <- Status@now(p, INFECTIOUS);
Status@[now+1](p, s) <- Transition@now(p, s);
Status@[now+1](p, s) <- Status@now(p, s), not Transition@now(p, _);
```

```expect Status@1
1, SUSCEPTIBLE
2, RECOVERED
3, SUSCEPTIBLE
4, SUSCEPTIBLE
5, SUSCEPTIBLE
6, SUSCEPTIBLE
7, SUSCEPTIBLE
8, SUSCEPTIBLE
```

This way of writing a model, with the changes in `Transition` and a rule for staying the same
when there is no change, is used in every model in this tutorial, up to the model for the
Belgian population. A new kind of change only needs a new rule for `Transition`.

## Try it yourself

**1.** In lesson 3 you added the state `EXPOSED`: infected, but not yet infectious. Make
person 2 exposed on day 0 instead of infectious. An exposed person becomes infectious after
one day, and an infectious person recovers after one day. What is person 2's state on days 0
to 4?

```epiql run timesteps=5
type State = SUSCEPTIBLE | INFECTIOUS | RECOVERED;

input relation Persons(person_id: u32, age: u8);
output temporal relation Status(person_id: u32, state: State);
temporal relation Transition(person_id: u32, state: State);

Status@init(2, INFECTIOUS) <- Persons(2, _);
Status@init(p, SUSCEPTIBLE) <- Persons(p, _), p != 2;

Transition@now(p, RECOVERED) <- Status@now(p, INFECTIOUS);
Status@[now+1](p, s) <- Transition@now(p, s);
Status@[now+1](p, s) <- Status@now(p, s), not Transition@now(p, _);
```

```expect Status@0
1, SUSCEPTIBLE
2, EXPOSED
3, SUSCEPTIBLE
4, SUSCEPTIBLE
5, SUSCEPTIBLE
6, SUSCEPTIBLE
7, SUSCEPTIBLE
8, SUSCEPTIBLE
```

```expect Status@1
1, SUSCEPTIBLE
2, INFECTIOUS
3, SUSCEPTIBLE
4, SUSCEPTIBLE
5, SUSCEPTIBLE
6, SUSCEPTIBLE
7, SUSCEPTIBLE
8, SUSCEPTIBLE
```

<details>
<summary>Show a hint</summary>

Three things change: the type gets the value `EXPOSED`, the first patient starts as
`EXPOSED`, and there is one new kind of change, from `EXPOSED` to `INFECTIOUS`.

</details>

<details>
<summary>Show a solution</summary>

```epiql
type State = SUSCEPTIBLE | EXPOSED | INFECTIOUS | RECOVERED;

Status@init(2, EXPOSED) <- Persons(2, _);
Status@init(p, SUSCEPTIBLE) <- Persons(p, _), p != 2;

Transition@now(p, INFECTIOUS) <- Status@now(p, EXPOSED);
```

Person 2 is `EXPOSED` on day 0, `INFECTIOUS` on day 1 and `RECOVERED` from day 2 on. The
rules for `Status` stay as they are: a new kind of change only needs a new rule for
`Transition`. This is the *SEIR* model, with the same four states as the model for the
Belgian population.

</details>



## What you learned

- Time goes in **timesteps**: 0, 1, 2, and so on.
- A **temporal** relation can hold different rows at every timestep.
- `@init` after a relation name means timestep 0; `@now` means any timestep, and `@[now+1]`
  the timestep after it. One rule with `@now` is about every day of the simulation.
- A temporal relation has only the rows that the rules say it has, at every timestep.
  Nothing carries over from one day to the next by itself.
- Rules never remove or replace rows. When a state changes, the rule that keeps a state must
  say that it only holds when there is no change.
- `not` in front of a row means that there is no such row. The variable names in it must also
  appear in the body without `not`.
- Changes go in `Transition`; `Status` follows from it.
- The first states can also be changes, with `Transition@init`; then `Status` starts on day 1.
