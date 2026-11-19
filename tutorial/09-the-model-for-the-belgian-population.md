# The model for the Belgian population

The earlier lessons often pointed ahead to "the model for the Belgian population". It is the
file `models/baseline.epiql`, and it simulates the spread of a virus in a sample of the
Belgian population. In this lesson, you read it
from top to bottom. Almost every rule in it is a rule you have written yourself, in a
lesson about Tiny Town. The few things that are new are explained on the way.

At the end, you run it on 10,000 individuals.

## The input

```epiql
type Pooltype = HOUSEHOLD | SCHOOL | WORK | PRIMARY_COMMUNITY | SECONDARY_COMMUNITY;
type State = SUSCEPTIBLE | EXPOSED | INFECTIOUS | RECOVERED;
type Symptoms = SYMPTOMATIC | ASYMPTOMATIC;

input relation Persons(person_id: u32, age: u8);
input relation PersonMember(person_id: u32, age: u8, pool_type: Pooltype, pool_id: u32, pool_type_id: u8);
input relation ContactProb(pool_type: Pooltype, pool_id: u32, age1: u8, age2: u8, prob: f64, pool_type_id: u8);
input relation ProbSymptomatic(age: u8, prob: f64);
type DayType = WEEKEND | WEEKDAY;
input temporal relation Calendar(daytype: DayType);
```

The places where people meet are called **pools**. There are five kinds: the household,
school, work, and two communities. The primary community is where people spend their
weekends, the secondary community where they spend their weekdays.

- `PersonMember` is the `Member` of exercise 1 in lesson 5: which person belongs to which
  pool. It also has the person's age, and `pool_type_id`, a number for the kind of pool
  (0 for `HOUSEHOLD`, …).
- `ContactProb` gives, for every pool, the probability that two people of age `age1` and
  `age2` in that pool have contact on a day.
- `ProbSymptomatic` gives, for every age, the probability that someone of that age gets
  symptoms when infected.
- `Calendar` is an **input temporal relation**: an input with a table for every timestep. Its
  table for a day holds one row, `WEEKEND` or `WEEKDAY`.

For example, the first rows of `PersonMember` in the sample of 10,000 people:

| person_id | age | pool_type | pool_id | pool_type_id |
| --- | --- | --- | --- | --- |
| 108 | 71 | HOUSEHOLD | 108 | 0 |
| 271 | 38 | HOUSEHOLD | 271 | 0 |
| 4493 | 4 | HOUSEHOLD | 293 | 0 |
| 431 | 1 | HOUSEHOLD | 431 | 0 |

## Who gets symptoms

```epiql
relation SymptomsDuringInfection(person_id: u32);
SymptomsDuringInfection(per) <-- Persons(per, age), ProbSymptomatic(age, prob), distr::bernouilli(prob);
```

This rule decides once, at the start, for every person whether they will have symptoms if
they get infected. It is new in one way: the probability of the Bernouilli trial is not a
number in the rule, but `prob`, a variable name whose value comes from `ProbSymptomatic`. So
every person gets the probability of their own age. The rule gives one row per person, so
`<--` is safe (lesson 7).

The model uses the variable name `per` where the lessons used `p`. Variable names are free
to choose, as long as a rule uses the same one everywhere it means the same thing.

## Day 0

```epiql
Transition@init(person_id, status) <--
    Persons(person_id, _),
    status ~ distr::discrete(SUSCEPTIBLE, 0.999, EXPOSED, 0.001);
```

The random start of lesson 7: one person in a thousand starts exposed.

## Who is present

```epiql
PersonInPool@now(per, age, ptid, pool_id) <-- PersonMember(per, age, HOUSEHOLD, pool_id, ptid);
PersonInPool@now(per, age, ptid, pool_id) <--
    PersonMember(per, age, ptype, pool_id, ptid), not Symptomatic@now(per),
    Calendar@now(WEEKDAY), ptype in [SCHOOL, WORK];
PersonInPool@t(per, age, ptid, pool_id) <--
    PersonMember(per, age, ptype, pool_id, ptid), Symptomatic@t(per),
    distr::bernouilli(0.1), Calendar@t(WEEKDAY), ptype in [SCHOOL, WORK];
```

`PersonInPool` is the `Present` of exercise 2 in lesson 5: who is in which pool on which
day. The model has six rules for it; these are three of them:

- Everyone is always in their household.
- On a weekday, someone without symptoms goes to school or work. `Calendar@now(WEEKDAY)`
  holds on the days whose row in `Calendar` is `WEEKDAY`. `ptype in [SCHOOL, WORK]` holds when
  `ptype` is one of the values in the list.
- On a weekday, someone with symptoms goes to school or work with probability 0.1: most of
  them stay home.

The third rule uses `@t` instead of `@now`. Like `now`, `t` is a variable name for the
timestep: you can choose any variable name, except `init`, which always means timestep 0.
Within one rule, the body uses the same one everywhere.

The other three rules are the same for the communities: the primary community on weekends,
the secondary community on weekdays, where someone with symptoms comes with probability
0.25.

## Infection

```epiql
Transition@t(per1, EXPOSED) <-
    Status@t(per1, SUSCEPTIBLE),
    InfectiousSymptomatic@t(per2),
    PersonInPool@t(per1, age1, pool_type_id, pool_id),
    PersonInPool@t(per2, age2, pool_type_id, pool_id),
    ContactProb(_, pool_id, age1, age2, prob, pool_type_id),
    distr::bernouilli(prob * 0.032172512)
  |
    Status@t(per1, SUSCEPTIBLE),
    InfectiousAsymptomatic@t(per2),
    PersonInPool@t(per1, age1, pool_type_id, pool_id),
    PersonInPool@t(per2, age2, pool_type_id, pool_id),
    ContactProb(_, pool_id, age1, age2, prob, pool_type_id),
    distr::bernouilli(prob * 0.016086256);
```

This is the infection rule of lesson 7, with two new things.

**`|` between two bodies** means "or": the head holds if the first body holds, **or** the
second. It looks like two rules with the same head, but it is not quite the same: see
below. The first body is about infectious people with symptoms, the second about those
without:
`InfectiousSymptomatic` and `InfectiousAsymptomatic` are made from `Status` and
`Symptomatic` a few lines higher up in the model.

**A computed probability.** Two people infect each other if they are in the same pool on that
day (the same `pool_type_id` and `pool_id`, as in lesson 5), if they meet, and if the
contact passes on the disease. The probability of all that is the contact probability for
their ages, `prob`, times the probability that a contact infects: 0.032 for someone with
symptoms, and half that for someone without.

The rule uses `<-` instead of `<--`: someone who meets several infectious people gets a Bernouilli trial for each
contact, but changes to `EXPOSED` only once (lesson 7).

### Why one rule, and not two?

Why does the infection rule use `|`, instead of two rules? Below is a model of Tiny Town in
the style of the model for the Belgian population, with one rule for infection at home and
one for infection at school. Every contact infects, and person 4 is the first
patient. How many times does person 3 change to `EXPOSED` on day 1? And what happens next?

Then write the two rules as one rule with `|`, and check `Transition` on day 1.

```epiql run timesteps=8
type State = SUSCEPTIBLE | EXPOSED | INFECTIOUS | RECOVERED;

input relation Persons(person_id: u32, age: u8);
input relation Household(person_id: u32, household_id: u32);
input relation School(person_id: u32, school_id: u32);
output temporal relation Status(person_id: u32, state: State);
output temporal relation Transition(person_id: u32, state: State);

# Day 0
Transition@init(4, INFECTIOUS) <- Persons(4, _);
Transition@init(p, SUSCEPTIBLE) <- Persons(p, _), p != 4;

# Infection, at home and at school
Transition@now(p1, EXPOSED) <-
    Status@now(p1, SUSCEPTIBLE),
    Household(p1, h), Household(p2, h), p1 != p2,
    Status@now(p2, INFECTIOUS);
Transition@now(p1, EXPOSED) <-
    Status@now(p1, SUSCEPTIBLE),
    School(p1, s), School(p2, s), p1 != p2,
    Status@now(p2, INFECTIOUS);

# Latent and infectious periods
Transition@[now+k](p, INFECTIOUS) <-- Transition@now(p, EXPOSED), k ~ distr::uniform(1, 2, 3);
Transition@[now+3](p, RECOVERED) <-- Transition@now(p, INFECTIOUS);

# From one day to the next
Status@[now+1](p, s) <-- Transition@now(p, s);
Status@[now+1](p, s) <-- Status@now(p, s), not Transition@now(p, _);
```

```expect Transition@1
1, EXPOSED
2, EXPOSED
3, EXPOSED
8, EXPOSED
```

<details>
<summary>Show the answer</summary>

Person 3 lives with person 4 *and* goes to school with person 4, so both rules give the row
`(3, EXPOSED)`. Each rule eliminates its own duplicates, but not those of another rule, so
`Transition` gets that row twice. The rules with `<--` then carry the duplicate further:
`Status` has `(3, EXPOSED)` twice, so a count of the exposed people counts person 3 twice,
and person 3 gets two latent periods, drawn separately.

</details>

<details>
<summary>Show a solution</summary>

```epiql
Transition@now(p1, EXPOSED) <-
    Status@now(p1, SUSCEPTIBLE),
    Household(p1, h), Household(p2, h), p1 != p2,
    Status@now(p2, INFECTIOUS)
  |
    Status@now(p1, SUSCEPTIBLE),
    School(p1, s), School(p2, s), p1 != p2,
    Status@now(p2, INFECTIOUS);
```

With one rule, duplicate elimination covers both bodies, so `(3, EXPOSED)` is in `Transition`
once. That is why the model for the Belgian population has one infection rule, with `|`
between the bodies for infectious people with and without symptoms.

</details>

## Latent and infectious periods, and symptoms

```epiql
Transition@[now+k](per, INFECTIOUS) <-- Transition@now(per, EXPOSED), k ~ distr::discrete(1, 0.208, 2, 0.191, …);
Transition@[now+k](per, RECOVERED) <-- Transition@now(per, INFECTIOUS), k ~ distr::discrete(2, 0.00013, 3, 0.00443, …);

Status@[now+1](per, status) <-- Transition@now(per, status);
Status@[now+1](per, status) <-- Status@now(per, status), not Transition@now(per, _);
```

The delays of lesson 8, and the rules of lesson 4 for going from one day to the next.

```epiql
SymptomsTransition@[now+k](per, SYMPTOMATIC) <--
    Transition@now(per, EXPOSED), SymptomsDuringInfection(per), k ~ distr::discrete(2, 0.078, …);
SymptomsTransition@[now+7](per, ASYMPTOMATIC) <-- SymptomsTransition@now(per, SYMPTOMATIC);

Symptomatic@[now+1](per) <-- SymptomsTransition@now(per, SYMPTOMATIC);
Symptomatic@[now+1](per) <-- Symptomatic@now(per), not SymptomsTransition@now(per, ASYMPTOMATIC);
```

Symptoms work in the same way as the states. `SymptomsTransition` holds the changes:
someone who will get symptoms gets them a drawn number of days after being infected, and
loses them 7 days later. `Symptomatic` follows from the changes, with the rule of lesson 4
for staying the same, for a relation with one column.

## The output

```epiql
NewlyInfected@now(agg::count(per)) <-- Transition@now(per, EXPOSED);
NumInfectious@now(agg::count(per)) <-- Status@now(per, INFECTIOUS);
```

The counts of lesson 6: new infections on each day, and the number of
people in each state.

## Run it

Here is the whole model, on a sample of 10,000 Belgians. It runs 3 times, for 120 days,
which takes a few seconds. Look at `NumInfectious` and `NewlyInfected`: how different are
the runs? Now and then, the epidemic dies out in one of them: the few people who start
exposed happen to infect nobody.

The Belgian data is not part of EpiQL itself. If the run says that a file is missing, run
`python3 data/download.py` once (see `data/README.md`).

```epiql run timesteps=120 runs=3 dataset=bel-10k
type Pooltype = HOUSEHOLD | SCHOOL | WORK | PRIMARY_COMMUNITY | SECONDARY_COMMUNITY;
type State = SUSCEPTIBLE | EXPOSED | INFECTIOUS | RECOVERED;
type Symptoms = SYMPTOMATIC | ASYMPTOMATIC;

input relation Persons(person_id: u32, age: u8);
input relation PersonMember(person_id: u32, age: u8, pool_type: Pooltype, pool_id: u32, pool_type_id: u8);
input relation ContactProb(pool_type: Pooltype, pool_id: u32, age1: u8, age2: u8, prob: f64, pool_type_id: u8);
input relation ProbSymptomatic(age: u8, prob: f64);
type DayType = WEEKEND | WEEKDAY;
input temporal relation Calendar(daytype: DayType);

temporal relation PersonInPool(person_id: u32, age: u8, pool_type_id: u8, pool_id: u32);
temporal relation Status(person_id: u32, state: State);
temporal relation Transition(person_id: u32, state: State);
temporal relation SymptomsTransition(person_id: u32, state: Symptoms);
temporal relation Symptomatic(person_id: u32);

# for every person, determine whether this person will have symptoms when infected
# one bernoulli trial per person, probability is age-dependent.
# person_id is unique in persons, no distinct.
relation SymptomsDuringInfection(person_id: u32);
SymptomsDuringInfection(per) <-- Persons(per,age), ProbSymptomatic(age,prob), distr::bernouilli(prob);

Transition@init(person_id, status) <--
	Persons(person_id, _), 
	status ~ distr::discrete(SUSCEPTIBLE, 0.999, EXPOSED, 0.001);

PersonInPool@t(per, age, ptid, pool_id)         <-- PersonMember(per, age, PRIMARY_COMMUNITY, pool_id, ptid),   Symptomatic@t(per),     distr::bernouilli(0.25), Calendar@t(WEEKEND);
PersonInPool@t(per, age, ptid, pool_id)         <-- PersonMember(per, age, SECONDARY_COMMUNITY, pool_id, ptid), Symptomatic@t(per),     distr::bernouilli(0.25), Calendar@t(WEEKDAY);
PersonInPool@t(per, age, ptid, pool_id)         <-- PersonMember(per, age, ptype, pool_id, ptid),               
                                                    Symptomatic@t(per),    
												 	distr::bernouilli(0.1),  Calendar@t(WEEKDAY),     ptype in [SCHOOL,WORK];

PersonInPool@now(per, age, ptid, pool_id)       <-- PersonMember(per, age, PRIMARY_COMMUNITY, pool_id, ptid),   not Symptomatic@now(per), 	                     Calendar@now(WEEKEND);
PersonInPool@now(per, age, ptid, pool_id)       <-- PersonMember(per, age, SECONDARY_COMMUNITY, pool_id, ptid), not Symptomatic@now(per), 	                     Calendar@now(WEEKDAY);
PersonInPool@now(per, age, ptid, pool_id)       <-- PersonMember(per, age, ptype, pool_id, ptid),               not Symptomatic@now(per), 	                     Calendar@now(WEEKDAY),   ptype in [SCHOOL,WORK];

# Always present in household pool
PersonInPool@now(per, age, ptid, pool_id)       <-- PersonMember(per, age, HOUSEHOLD, pool_id, ptid);

temporal relation InfectiousSymptomatic(person_id: u32); 
temporal relation InfectiousAsymptomatic(person_id: u32);

InfectiousSymptomatic@t(per2) <- Status@t(per2, INFECTIOUS), Symptomatic@t(per2);
InfectiousAsymptomatic@t(per2) <- Status@t(per2, INFECTIOUS), not Symptomatic@t(per2);

Transition@t(per1, EXPOSED) <-
	Status@t(per1, SUSCEPTIBLE),
	InfectiousSymptomatic@t(per2),
	PersonInPool@t(per1,age1,pool_type_id,pool_id),
	PersonInPool@t(per2,age2,pool_type_id,pool_id),
	ContactProb(_,pool_id,age1,age2,prob,pool_type_id),
    distr::bernouilli(prob * 0.032172512) 

		| 
		
	Status@t(per1, SUSCEPTIBLE),
	InfectiousAsymptomatic@t(per2),
	PersonInPool@t(per1,age1,pool_type_id,pool_id),
	PersonInPool@t(per2,age2,pool_type_id,pool_id),
	ContactProb(_,pool_id,age1,age2,prob,pool_type_id),
    distr::bernouilli(prob * 0.016086256); 

Transition@[now+k](per, INFECTIOUS) <-- Transition@now(per, EXPOSED), k ~ distr::discrete(1,0.20835228584733906,2,0.19130344838772514,3,0.15320594486487116,4,0.115969539178529,5,0.08583874391780273,6,0.06310380843504527,7,0.04642523170260287,8,0.03431089245884943,9,0.025521920779025663,10,0.0191241605210256,11,0.014440513435552298,12,0.010988127489922407,13,0.00842442525932032,14,0.006505965384254663,15,0.005056965431217786,16,0.0039415508599106915,17,0.00304050181012072,18,0.002245845417973531,19,0.0014799871251948175,20,0.0007201416937167696,21,0.0);
Transition@[now+k](per, RECOVERED) <-- Transition@now(per, INFECTIOUS), k ~ distr::discrete(2,0.00013,3,0.00443,4,0.05399,5,0.24197,6,0.39894,7,0.24197,8,0.05399,9,0.00443,10,0.00013,11,0.00000,12,0.00000,13,0.00000,14,0.00000,15,0.00000,16,0.00002); 


Status@[now+1](per, status) <-- Transition@now(per, status);
Status@[now+1](per, status) <-- Status@now(per, status), not Transition@now(per, _);


SymptomsTransition@[now+k](per, SYMPTOMATIC) <-- Transition@now(per, EXPOSED), SymptomsDuringInfection(per), k ~ distr::discrete(2,0.07837076021917108,3,0.15507615885664966,4,0.17102932490594439,5,0.14848141821404284,6,0.11547374163873061,7,0.08586813376718089,8,0.06307984104752182,9,0.04638747677187502,10,0.03429699850347167,11,0.025534069592062447,12,0.019154083890804204,13,0.014479749175352686,14,0.011030499069012968,15,0.008466063804611108,16,0.006544953332269267,17,0.005094964956591803,18,0.003992552284842661,19,0.003148471455305324,20,0.0024977950614422247,21,0.0019929434531171875);
SymptomsTransition@[now+7](per, ASYMPTOMATIC) <-- SymptomsTransition@now(per, SYMPTOMATIC);


Symptomatic@[now+1](per) <-- SymptomsTransition@now(per, SYMPTOMATIC);
Symptomatic@[now+1](per) <-- Symptomatic@now(per), not SymptomsTransition@now(per, ASYMPTOMATIC);

#########################################################################
###                             OUTPUT                                ###
#########################################################################

output temporal relation NewlyInfected(num: u32);
output temporal relation NumSusceptible(num: u32);
output temporal relation NumExposed(num: u32);
output temporal relation NumInfectious(num: u32);
output temporal relation NumRecovered(num: u32);
output temporal relation NumSymptomatic(num: u32);

NewlyInfected@now( agg::count(per) ) <-- Transition@now(per, EXPOSED);
NumSusceptible@now( agg::count(per) ) <-- Status@now(per, SUSCEPTIBLE);
NumExposed@now( agg::count(per) ) <-- Status@now(per, EXPOSED);
NumInfectious@now( agg::count(per) ) <-- Status@now(per, INFECTIOUS);
NumRecovered@now( agg::count(per) ) <-- Status@now(per, RECOVERED);
NumSymptomatic@now( agg::count(per) ) <-- Symptomatic@now(per);
```

## Try it yourself

**1.** What happens if the schools close? In the program above, remove `SCHOOL` from the two
lists `[SCHOOL, WORK]`, and run it again. Compare `NewlyInfected` and `NumInfectious` with
before. (*Undo my changes* brings back the model as it was.)

<details>
<summary>Show the answer</summary>

`[WORK]` is a list with one value. Without school, children only meet other people at home
and in the communities, and the disease spreads much more slowly. When we tried it, about a
third as many people were infected in 120 days as with the schools open. How much fewer
differs from run to run: compare the runs, not one run.

</details>

**2.** What if people with symptoms always stay home? Change the probabilities with which
they still go to school, work and the communities to `0.0`.

<details>
<summary>Show the answer</summary>

These are the `0.1` and the two `0.25` in the rules for `PersonInPool`. The epidemic grows
more slowly, but it does not stop: people without symptoms still go everywhere, and they are
infectious too.

</details>

**3.** However the draws come out, every one of the 10,000 people has exactly one state on
every day from day 1 on. Write a rule for `NumPersons`, the number of people in `Status` on
each day, and check that it is 10,000 on the last day, in every run. (This program runs for
fewer days, to be quicker.)

```epiql run timesteps=20 runs=3 dataset=bel-10k
type Pooltype = HOUSEHOLD | SCHOOL | WORK | PRIMARY_COMMUNITY | SECONDARY_COMMUNITY;
type State = SUSCEPTIBLE | EXPOSED | INFECTIOUS | RECOVERED;
type Symptoms = SYMPTOMATIC | ASYMPTOMATIC;

input relation Persons(person_id: u32, age: u8);
input relation PersonMember(person_id: u32, age: u8, pool_type: Pooltype, pool_id: u32, pool_type_id: u8);
input relation ContactProb(pool_type: Pooltype, pool_id: u32, age1: u8, age2: u8, prob: f64, pool_type_id: u8);
input relation ProbSymptomatic(age: u8, prob: f64);
type DayType = WEEKEND | WEEKDAY;
input temporal relation Calendar(daytype: DayType);

temporal relation PersonInPool(person_id: u32, age: u8, pool_type_id: u8, pool_id: u32);
temporal relation Status(person_id: u32, state: State);
temporal relation Transition(person_id: u32, state: State);
temporal relation SymptomsTransition(person_id: u32, state: Symptoms);
temporal relation Symptomatic(person_id: u32);

# for every person, determine whether this person will have symptoms when infected
# one bernoulli trial per person, probability is age-dependent.
# person_id is unique in persons, no distinct.
relation SymptomsDuringInfection(person_id: u32);
SymptomsDuringInfection(per) <-- Persons(per,age), ProbSymptomatic(age,prob), distr::bernouilli(prob);

Transition@init(person_id, status) <--
	Persons(person_id, _), 
	status ~ distr::discrete(SUSCEPTIBLE, 0.999, EXPOSED, 0.001);

PersonInPool@t(per, age, ptid, pool_id)         <-- PersonMember(per, age, PRIMARY_COMMUNITY, pool_id, ptid),   Symptomatic@t(per),     distr::bernouilli(0.25), Calendar@t(WEEKEND);
PersonInPool@t(per, age, ptid, pool_id)         <-- PersonMember(per, age, SECONDARY_COMMUNITY, pool_id, ptid), Symptomatic@t(per),     distr::bernouilli(0.25), Calendar@t(WEEKDAY);
PersonInPool@t(per, age, ptid, pool_id)         <-- PersonMember(per, age, ptype, pool_id, ptid),               
                                                    Symptomatic@t(per),    
												 	distr::bernouilli(0.1),  Calendar@t(WEEKDAY),     ptype in [SCHOOL,WORK];

PersonInPool@now(per, age, ptid, pool_id)       <-- PersonMember(per, age, PRIMARY_COMMUNITY, pool_id, ptid),   not Symptomatic@now(per), 	                     Calendar@now(WEEKEND);
PersonInPool@now(per, age, ptid, pool_id)       <-- PersonMember(per, age, SECONDARY_COMMUNITY, pool_id, ptid), not Symptomatic@now(per), 	                     Calendar@now(WEEKDAY);
PersonInPool@now(per, age, ptid, pool_id)       <-- PersonMember(per, age, ptype, pool_id, ptid),               not Symptomatic@now(per), 	                     Calendar@now(WEEKDAY),   ptype in [SCHOOL,WORK];

# Always present in household pool
PersonInPool@now(per, age, ptid, pool_id)       <-- PersonMember(per, age, HOUSEHOLD, pool_id, ptid);

temporal relation InfectiousSymptomatic(person_id: u32); 
temporal relation InfectiousAsymptomatic(person_id: u32);

InfectiousSymptomatic@t(per2) <- Status@t(per2, INFECTIOUS), Symptomatic@t(per2);
InfectiousAsymptomatic@t(per2) <- Status@t(per2, INFECTIOUS), not Symptomatic@t(per2);

Transition@t(per1, EXPOSED) <-
	Status@t(per1, SUSCEPTIBLE),
	InfectiousSymptomatic@t(per2),
	PersonInPool@t(per1,age1,pool_type_id,pool_id),
	PersonInPool@t(per2,age2,pool_type_id,pool_id),
	ContactProb(_,pool_id,age1,age2,prob,pool_type_id),
    distr::bernouilli(prob * 0.032172512) 

		| 
		
	Status@t(per1, SUSCEPTIBLE),
	InfectiousAsymptomatic@t(per2),
	PersonInPool@t(per1,age1,pool_type_id,pool_id),
	PersonInPool@t(per2,age2,pool_type_id,pool_id),
	ContactProb(_,pool_id,age1,age2,prob,pool_type_id),
    distr::bernouilli(prob * 0.016086256); 

Transition@[now+k](per, INFECTIOUS) <-- Transition@now(per, EXPOSED), k ~ distr::discrete(1,0.20835228584733906,2,0.19130344838772514,3,0.15320594486487116,4,0.115969539178529,5,0.08583874391780273,6,0.06310380843504527,7,0.04642523170260287,8,0.03431089245884943,9,0.025521920779025663,10,0.0191241605210256,11,0.014440513435552298,12,0.010988127489922407,13,0.00842442525932032,14,0.006505965384254663,15,0.005056965431217786,16,0.0039415508599106915,17,0.00304050181012072,18,0.002245845417973531,19,0.0014799871251948175,20,0.0007201416937167696,21,0.0);
Transition@[now+k](per, RECOVERED) <-- Transition@now(per, INFECTIOUS), k ~ distr::discrete(2,0.00013,3,0.00443,4,0.05399,5,0.24197,6,0.39894,7,0.24197,8,0.05399,9,0.00443,10,0.00013,11,0.00000,12,0.00000,13,0.00000,14,0.00000,15,0.00000,16,0.00002); 


Status@[now+1](per, status) <-- Transition@now(per, status);
Status@[now+1](per, status) <-- Status@now(per, status), not Transition@now(per, _);


SymptomsTransition@[now+k](per, SYMPTOMATIC) <-- Transition@now(per, EXPOSED), SymptomsDuringInfection(per), k ~ distr::discrete(2,0.07837076021917108,3,0.15507615885664966,4,0.17102932490594439,5,0.14848141821404284,6,0.11547374163873061,7,0.08586813376718089,8,0.06307984104752182,9,0.04638747677187502,10,0.03429699850347167,11,0.025534069592062447,12,0.019154083890804204,13,0.014479749175352686,14,0.011030499069012968,15,0.008466063804611108,16,0.006544953332269267,17,0.005094964956591803,18,0.003992552284842661,19,0.003148471455305324,20,0.0024977950614422247,21,0.0019929434531171875);
SymptomsTransition@[now+7](per, ASYMPTOMATIC) <-- SymptomsTransition@now(per, SYMPTOMATIC);


Symptomatic@[now+1](per) <-- SymptomsTransition@now(per, SYMPTOMATIC);
Symptomatic@[now+1](per) <-- Symptomatic@now(per), not SymptomsTransition@now(per, ASYMPTOMATIC);

#########################################################################
###                             OUTPUT                                ###
#########################################################################

output temporal relation NewlyInfected(num: u32);
output temporal relation NumSusceptible(num: u32);
output temporal relation NumExposed(num: u32);
output temporal relation NumInfectious(num: u32);
output temporal relation NumRecovered(num: u32);
output temporal relation NumSymptomatic(num: u32);
output temporal relation NumPersons(num: u32);

NewlyInfected@now( agg::count(per) ) <-- Transition@now(per, EXPOSED);
NumSusceptible@now( agg::count(per) ) <-- Status@now(per, SUSCEPTIBLE);
NumExposed@now( agg::count(per) ) <-- Status@now(per, EXPOSED);
NumInfectious@now( agg::count(per) ) <-- Status@now(per, INFECTIOUS);
NumRecovered@now( agg::count(per) ) <-- Status@now(per, RECOVERED);
NumSymptomatic@now( agg::count(per) ) <-- Symptomatic@now(per);
```

```expect NumPersons
10000
```

<details>
<summary>Show a solution</summary>

```epiql
NumPersons@now(agg::count(per)) <-- Status@now(per, _);
```

Each person has one row in `Status`, so `<--` is safe here, and `<-` gives the same.

</details>

## What you learned

- The model for the Belgian population is built from the rules of the earlier lessons.
- An `input temporal relation`, such as `Calendar`, has an input table for every timestep.
- `x in [A, B]` holds when `x` is one of the values in the list.
- The probability of a Bernouilli trial can come from a relation, and be computed:
  `distr::bernouilli(prob * 0.032)`.
- `|` between two bodies means "or": the head holds if either body holds. Duplicate
  elimination covers both bodies, which it does not do for two separate rules.
- Any variable name except `init` works for the timestep: `@t` means the same as `@now`.

In the next lesson, you add contact tracing to this model.
