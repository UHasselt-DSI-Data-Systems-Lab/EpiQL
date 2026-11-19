# Getting infected

So far, the only thing that happens is that person 2 recovers. Now we simulate how the
disease actually spreads: who meets whom, and who infects whom at those contacts.

## Who meets whom

People infect each other when they meet. In Tiny Town, people meet at home, and the children
also meet at school:

```data School(person_id, school_id)
```

Persons 3 and 4 (from household 1) and person 8 (from household 3) go to school 1.

From lesson 2 you know how to make pairs of people who live together. Pairs of people who go
to the same school are made the same way. Together they are the contacts:

```epiql
relation Contact(person: u32, other: u32);

Contact(p1, p2) <- Household(p1, h), Household(p2, h), p1 != p2;
Contact(p1, p2) <- School(p1, s), School(p2, s), p1 != p2;
```

Two rules are about `Contact`, so `Contact` holds the pairs from both: the people who live
together, and the people who go to school together.

`Contact` holds every pair twice, once in each order: persons 3 and 4 give both the row
`(3, 4)` and the row `(4, 3)`. That is on purpose: the infection rule below only infects
the first person of a pair, and with both orders in `Contact`, either person can infect the
other. A relation that holds `(p2, p1)` whenever it holds `(p1, p2)` is called
**symmetric**.

## Infection

A susceptible person who has contact with an infectious person gets infected. As in exercise 1
of lesson 4, they are first **exposed** for a day: infected, but not yet infectious. So the
model has four states, like the model for the Belgian population:

```epiql
type State = SUSCEPTIBLE | EXPOSED | INFECTIOUS | RECOVERED;
```

The infection rule makes a susceptible person `EXPOSED`:

```epiql
Transition@now(p1, EXPOSED) <-
    Status@now(p1, SUSCEPTIBLE),
    Contact(p1, p2),
    Status@now(p2, INFECTIOUS);
```

In words:

> A person `p1` changes to `EXPOSED` **if** `p1` is `SUSCEPTIBLE` today, **and** `p1` has
> contact with `p2`, **and** `p2` is `INFECTIOUS` today.

For now, every contact infects. That is not realistic, but it makes the outcome certain, so
that you can predict it exactly. In lesson 7, a contact infects only with a certain
probability.

The other changes are those of exercise 1 of lesson 4: an exposed person becomes infectious
after one day, and an infectious person recovers after one day.

```epiql
Transition@now(p, INFECTIOUS) <- Status@now(p, EXPOSED);
Transition@now(p, RECOVERED) <- Status@now(p, INFECTIOUS);
```

Thanks to the way the model is written in the last lesson, these rules for `Transition` are
all that is needed. The rules for `Status` stay the same.

## The whole model

Before you run it, work out the epidemic day by day. Who is exposed on day 1? Who is
infectious on day 2? Does everyone get ill?

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
```

A line that starts with `#` is a **comment**: a note for the reader, which EpiQL skips.

<details>
<summary>What happened</summary>

| Day | Exposed | Infectious | What happens |
| --- | --- | --- | --- |
| 0 | | 2 | Person 2 infects the rest of household 1: persons 1, 3 and 4. |
| 1 | 1, 3, 4 | | Nobody is infectious, so nobody is infected. |
| 2 | | 1, 3, 4 | Persons 3 and 4 infect person 8 at school. |
| 3 | 8 | | |
| 4 | | 8 | Person 8 infects person 7 at home. |
| 5 | 7 | | |
| 6 | | 7 | Everyone that person 7 meets is recovered already. |
| 7 | | | The epidemic is over. |

Because everyone is exposed for exactly one day and infectious for exactly one day, the
epidemic goes in steps of two days. In lesson 8, these periods get realistic lengths.

Persons 5 and 6 never get ill: they meet nobody outside their home.

</details>

## Try it yourself

The model for the Belgian population has more kinds of places than homes and schools: also
workplaces and two kinds of communities. It does not write a separate rule for each kind of
place. These two exercises build up its way of doing it.

**1.** Put all places in one relation. A row `(p, place, id)` of `Member` says that person `p`
belongs to place number `id` of kind `place`: `(3, SCHOOL, 1)` says that person 3 goes to
school 1. The type `Place` and the relation `Member` are declared already.

- Write two rules for `Member`: one that takes the rows of `Household`, and one that takes
  the rows of `School`.
- Then replace the two rules for `Contact` with a single rule that uses `Member`.

The epidemic should stay exactly the same.

```epiql run timesteps=10
type State = SUSCEPTIBLE | EXPOSED | INFECTIOUS | RECOVERED;
type Place = HOUSEHOLD | SCHOOL;

input relation Persons(person_id: u32, age: u8);
input relation Household(person_id: u32, household_id: u32);
input relation School(person_id: u32, school_id: u32);
output temporal relation Status(person_id: u32, state: State);
temporal relation Transition(person_id: u32, state: State);
output relation Member(person_id: u32, place: Place, place_id: u32);
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
```

```expect Member
1, HOUSEHOLD, 1
2, HOUSEHOLD, 1
3, HOUSEHOLD, 1
4, HOUSEHOLD, 1
5, HOUSEHOLD, 2
6, HOUSEHOLD, 2
7, HOUSEHOLD, 3
8, HOUSEHOLD, 3
3, SCHOOL, 1
4, SCHOOL, 1
8, SCHOOL, 1
```

```expect Status@4
1, RECOVERED
2, RECOVERED
3, RECOVERED
4, RECOVERED
5, SUSCEPTIBLE
6, SUSCEPTIBLE
7, SUSCEPTIBLE
8, INFECTIOUS
```

<details>
<summary>Show a hint</summary>

In the head of a rule for `Member`, write the kind of place as a value, as in
`Health(2, INFECTIOUS)` of lesson 3. In the rule for `Contact`, two people meet if they
belong to the same place: the same kind **and** the same number.

</details>

<details>
<summary>Show a solution</summary>

```epiql
Member(p, HOUSEHOLD, h) <- Household(p, h);
Member(p, SCHOOL, s) <- School(p, s);

Contact(p1, p2) <- Member(p1, place, id), Member(p2, place, id), p1 != p2;
```

Both `place` and `id` appear in both rows of `Member`, so both rows must have the same kind
of place and the same number: household 1 and school 1 are different places.

This is how the model for the Belgian population does it, with the relation `PersonMember`
and five kinds of places. A new kind of place now only needs a new rule for `Member`; the
rule for `Contact` stays the same.

</details>

**2.** A child who is infectious stays home from school, but is still at home with their
household. Who is where can now be different every day, so it needs a temporal relation:

```epiql
temporal relation Present(person_id: u32, place: Place, place_id: u32);
```

Write two rules for `Present`: everyone is present in their household, and a person is
present at their school if they are not `INFECTIOUS`. Then let `Contact` change from day to
day: make it a temporal relation, and let it use `Present@now` instead of `Member`. Before you
run it: who gets ill now?

```epiql run timesteps=10
type State = SUSCEPTIBLE | EXPOSED | INFECTIOUS | RECOVERED;
type Place = HOUSEHOLD | SCHOOL;

input relation Persons(person_id: u32, age: u8);
input relation Household(person_id: u32, household_id: u32);
input relation School(person_id: u32, school_id: u32);
output temporal relation Status(person_id: u32, state: State);
temporal relation Transition(person_id: u32, state: State);
relation Member(person_id: u32, place: Place, place_id: u32);
relation Contact(person: u32, other: u32);

# Who belongs where
Member(p, HOUSEHOLD, h) <- Household(p, h);
Member(p, SCHOOL, s) <- School(p, s);

# Who meets whom
Contact(p1, p2) <- Member(p1, place, id), Member(p2, place, id), p1 != p2;

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
```

```expect Status@9
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

A rule can have a temporal head and a body without any temporal relation:
`Present@now(p, HOUSEHOLD, h) <- Member(p, HOUSEHOLD, h);` holds on every day. In the rule
for school, use `not Status@now(p, INFECTIOUS)`. Once `Contact` is temporal, write it with
`@now` everywhere, also in the infection rule.

</details>

<details>
<summary>Show a solution</summary>

```epiql
temporal relation Present(person_id: u32, place: Place, place_id: u32);
temporal relation Contact(person: u32, other: u32);

Present@now(p, HOUSEHOLD, h) <- Member(p, HOUSEHOLD, h);
Present@now(p, SCHOOL, s) <- Member(p, SCHOOL, s), not Status@now(p, INFECTIOUS);

Contact@now(p1, p2) <- Present@now(p1, place, id), Present@now(p2, place, id), p1 != p2;

Transition@now(p1, EXPOSED) <-
    Status@now(p1, SUSCEPTIBLE),
    Contact@now(p1, p2),
    Status@now(p2, INFECTIOUS);
```

Only household 1 gets ill. Persons 3 and 4 go to school on day 1, but they are only exposed
then, so they do not infect anyone. On day 2 they are infectious, and they stay home.

The model for the Belgian population does the same with `PersonInPool`: everyone is always
present in their household, but people with symptoms often stay away from school, work and
the community. There, it is a matter of chance, which is the subject of lesson 7.

</details>

## What you learned

- A few rules for `Transition` are enough to let a disease spread; the rules for `Status`
  stay the same.
- In the SEIR model, an infected person is first `EXPOSED`, and only later `INFECTIOUS`.
- A rule can combine a relation that changes over time (`Status@now`) with one that does not
  (`Contact`).
- A line that starts with `#` is a comment, which EpiQL skips.
