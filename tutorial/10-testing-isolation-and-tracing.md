# Testing, isolation and tracing

How much does it help if people who test positive stay home? And what if the people they
infected stay home too? In this lesson, you add testing, isolation and tracing to the model
for the Belgian population of lesson 9. The result is the model `models/tracing.epiql`.

## Testing

```epiql
TestedPositive@[now+2](per) <--
    SymptomsTransition@now(per, SYMPTOMATIC),
    distr::bernouilli(0.9);
```

`SymptomsTransition@now(per, SYMPTOMATIC)` means that `per` has symptoms from the next day
on (lesson 9). One day later, `per` is tested: 9 in 10 people with symptoms are tested, and
the test is always right. People without symptoms are never tested.

## Isolation

```epiql
InIsolation@[now+1](per), InIsolation@[now+2](per), InIsolation@[now+3](per), InIsolation@[now+4](per),
InIsolation@[now+5](per), InIsolation@[now+6](per), InIsolation@[now+7](per) <--
    TestedPositive@now(per);
```

This rule has **seven heads**, separated by commas, and gives a row in each of them: `(per)`
is in `InIsolation` on each of the 7 days after `per` tests positive. That is as long as the
symptoms last.

Someone in isolation meets nobody, not even the people they live with. So every rule for
`PersonInPool` gets `not InIsolation@now(per)`, also the rule for the household:

```epiql
PersonInPool@now(per, age, ptid, pool_id) <-- PersonMember(per, age, HOUSEHOLD, pool_id, ptid), not InIsolation@now(per);
```

## Who infected whom

To trace the people someone infected, the model must remember who infected whom. So the
infection rule of lesson 9 gets a new head, `Transmission`, with the same two bodies:

```epiql
Transmission@t(per1, per2) <-
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

Transition@t(per1, EXPOSED) <- Transmission@t(per1, per2);
AllTransmissions(per1, per2) <-- Transmission@t(per1, per2);
```

`(per1, per2)` is in `Transmission` on a day if `per1` is infected by `per2` on that day.
Someone who is infected by two people has two rows in it, but with `<-`, one row in
`Transition`.

`AllTransmissions` is a relation without time, and its rule reads a temporal relation: a row
is in `AllTransmissions` if it is in `Transmission` on some day `t`. While the simulation
runs, it collects the infections of all the days so far. `<--` is safe here: someone can
only be infected while they are susceptible, so each row is in `Transmission` on one day
only.

## Tracing

```epiql
InIsolation@[now+1](infectee), …, InIsolation@[now+7](infectee) <-
    TestedPositive@now(per),
    AllTransmissions(infectee, per),
    Status@now(infectee, x), x in [SUSCEPTIBLE, EXPOSED, INFECTIOUS],
    not InIsolation@now(infectee),
    distr::bernouilli(0.9);
```

When `per` tests positive, the people `per` has infected stay home for 7 days too. This is
called **quarantine**. The tracers reach 9 in 10 of them. They do not trace someone who has
already recovered, or someone who already stays home: an isolation is not made longer.

This tracing is simpler than real contact tracing. Real tracers do not know who infected
whom: they ask someone who tested positive whom they met, and warn those people.

## The output

```epiql
NumTestedPositive@now(agg::count(per)) <-- TestedPositive@now(per);
NumIsolated@now(agg::count(per)) <-- Isolated@now(per);

Isolated@t(per) <- InIsolation@t(per);
```

`NumIsolated` counts the people who stay home on each day. It counts `Isolated`, not
`InIsolation`: someone in quarantine who tests positive gets rows in `InIsolation` from both
rules, so they can be in it twice on one day. With `<-`, `Isolated` has each person once.

## Run it

Here is the whole model, on the same 10,000 Belgians as in lesson 9. Compare
`NumInfectious` with the runs there, and look at `NumIsolated`.

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


PersonInPool@now(per, age, ptid, pool_id)         <-- PersonMember(per, age, PRIMARY_COMMUNITY, pool_id, ptid),   Symptomatic@now(per), not InIsolation@now(per),    distr::bernouilli(0.25), Calendar@now(WEEKEND);
PersonInPool@now(per, age, ptid, pool_id)         <-- PersonMember(per, age, SECONDARY_COMMUNITY, pool_id, ptid), Symptomatic@now(per), not InIsolation@now(per),    distr::bernouilli(0.25), Calendar@now(WEEKDAY);
PersonInPool@now(per, age, ptid, pool_id)         <-- PersonMember(per, age, ptype, pool_id, ptid),               
                                                    Symptomatic@now(per), not InIsolation@now(per),
												 	distr::bernouilli(0.1),  Calendar@now(WEEKDAY),     ptype in [SCHOOL,WORK];

PersonInPool@now(per, age, ptid, pool_id)       <-- PersonMember(per, age, PRIMARY_COMMUNITY, pool_id, ptid),   not Symptomatic@now(per),  not InIsolation@now(per),   Calendar@now(WEEKEND);
PersonInPool@now(per, age, ptid, pool_id)       <-- PersonMember(per, age, SECONDARY_COMMUNITY, pool_id, ptid), not Symptomatic@now(per),  not InIsolation@now(per),   Calendar@now(WEEKDAY);
PersonInPool@now(per, age, ptid, pool_id)       <-- PersonMember(per, age, ptype, pool_id, ptid),               not Symptomatic@now(per),  not InIsolation@now(per),   Calendar@now(WEEKDAY),   ptype in [SCHOOL,WORK];

# Always present in household pool, except when isolated
PersonInPool@now(per, age, ptid, pool_id)       <-- PersonMember(per, age, HOUSEHOLD, pool_id, ptid),  not InIsolation@now(per);

temporal relation InfectiousSymptomatic(person_id: u32); 
temporal relation InfectiousAsymptomatic(person_id: u32);

InfectiousSymptomatic@t(per2) <- Status@t(per2, INFECTIOUS), Symptomatic@t(per2);
InfectiousAsymptomatic@t(per2) <- Status@t(per2, INFECTIOUS), not Symptomatic@t(per2);


# who infected whom at every simulation timestep
temporal relation Transmission(person_id1: u32, person_id2: u32); 
# Dump of all transmissions in the past
relation AllTransmissions(person_id1: u32, person_id2: u32); 

Transmission@t(per1, per2) <-
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
with 5 runs of each model, the highest number of infectiou
# Duplicate elimination:
# store per1 only once, even if infected by multiple infectors
Transition@t(per1, EXPOSED) <- Transmission@t(per1, per2);

AllTransmissions(per1,per2) <-- Transmission@t(per1, per2);

Transition@[now+k](per, INFECTIOUS) <-- Transition@now(per, EXPOSED), k ~ distr::discrete(1,0.20835228584733906,2,0.19130344838772514,3,0.15320594486487116,4,0.115969539178529,5,0.08583874391780273,6,0.06310380843504527,7,0.04642523170260287,8,0.03431089245884943,9,0.025521920779025663,10,0.0191241605210256,11,0.014440513435552298,12,0.010988127489922407,13,0.00842442525932032,14,0.006505965384254663,15,0.005056965431217786,16,0.0039415508599106915,17,0.00304050181012072,18,0.002245845417973531,19,0.0014799871251948175,20,0.0007201416937167696,21,0.0);
Transition@[now+k](per, RECOVERED) <-- Transition@now(per, INFECTIOUS), k ~ distr::discrete(2,0.00013,3,0.00443,4,0.05399,5,0.24197,6,0.39894,7,0.24197,8,0.05399,9,0.00443,10,0.00013,11,0.00000,12,0.00000,13,0.00000,14,0.00000,15,0.00000,16,0.00002); 


Status@[now+1](per, status) <-- Transition@now(per, status);
Status@[now+1](per, status) <-- Status@now(per, status), not Transition@now(per, _);


SymptomsTransition@[now+k](per, SYMPTOMATIC) <-- Transition@now(per, EXPOSED), SymptomsDuringInfection(per), k ~ distr::discrete(2,0.07837076021917108,3,0.15507615885664966,4,0.17102932490594439,5,0.14848141821404284,6,0.11547374163873061,7,0.08586813376718089,8,0.06307984104752182,9,0.04638747677187502,10,0.03429699850347167,11,0.025534069592062447,12,0.019154083890804204,13,0.014479749175352686,14,0.011030499069012968,15,0.008466063804611108,16,0.006544953332269267,17,0.005094964956591803,18,0.003992552284842661,19,0.003148471455305324,20,0.0024977950614422247,21,0.0019929434531171875);
SymptomsTransition@[now+7](per, ASYMPTOMATIC) <-- SymptomsTransition@now(per, SYMPTOMATIC);


Symptomatic@[now+1](per) <-- SymptomsTransition@now(per, SYMPTOMATIC);
Symptomatic@[now+1](per) <-- Symptomatic@now(per), not SymptomsTransition@now(per, ASYMPTOMATIC);


#########################################################################
###                             TRACING                               ###
#########################################################################


# Persons currently in isolation
temporal relation InIsolation(person_id: u32); 
# Persons that have tested positive,
# where the test is taken one day after symptom onset
temporal relation TestedPositive(person_id: u32);


TestedPositive@[now+2](per) <-- 
			SymptomsTransition@now(per, SYMPTOMATIC), 
			distr::bernouilli(0.9);


# If test = positive: isolate for 7 days
InIsolation@[now+1](per), InIsolation@[now+2](per), InIsolation@[now+3](per), InIsolation@[now+4](per), InIsolation@[now+5](per), InIsolation@[now+6](per), InIsolation@[now+7](per) <-- 
			TestedPositive@now(per);


InIsolation@[now+1](infectee), InIsolation@[now+2](infectee), InIsolation@[now+3](infectee), InIsolation@[now+4](infectee), InIsolation@[now+5](infectee), InIsolation@[now+6](infectee), InIsolation@[now+7](infectee) <- 
			TestedPositive@now(per), 
			AllTransmissions(infectee, per), 
			Status@now(infectee, x), x in [SUSCEPTIBLE, EXPOSED, INFECTIOUS], 
			not InIsolation@now(infectee), 
			distr::bernouilli(0.9);


#########################################################################
###                             OUTPUT                                ###
#########################################################################

output temporal relation NewlyInfected(num: u32);
output temporal relation NumSusceptible(num: u32);
output temporal relation NumExposed(num: u32);
output temporal relation NumInfectious(num: u32);
output temporal relation NumRecovered(num: u32);
output temporal relation NumSymptomatic(num: u32);
output temporal relation NumTestedPositive(num: u32);
output temporal relation NumIsolated(num: u32);

NewlyInfected@now( agg::count(per) ) <-- Transition@now(per, EXPOSED);
NumSusceptible@now( agg::count(per) ) <-- Status@now(per, SUSCEPTIBLE);
NumExposed@now( agg::count(per) ) <-- Status@now(per, EXPOSED);
NumInfectious@now( agg::count(per) ) <-- Status@now(per, INFECTIOUS);
NumRecovered@now( agg::count(per) ) <-- Status@now(per, RECOVERED);
NumSymptomatic@now( agg::count(per) ) <-- Symptomatic@now(per);
NumTestedPositive@now( agg::count(per) ) <-- TestedPositive@now(per);
NumIsolated@now( agg::count(per) ) <-- Isolated@now(per);

temporal relation Isolated(person_id: u32);
Isolated@t(per) <- InIsolation@t(per);
```

## Compare the two models

Three runs of each model are not much to compare. In the **Run** and **Analyze** tabs, you
can run both models many times, and see them in one chart:

1. In the **Models** tab, add `baseline` and `tracing` from the *Library* to your workspace
   (point at a model and click *Add*), unless they are there already.
2. In the **Run** tab, under *Models*, tick `baseline` and `tracing`.
3. Choose the dataset `bel-10k`, 120 timesteps, and 10 repetitions, and click
   *Start experiment*.
4. In the list of experiments, click *Analyze* next to your experiment.
5. In the chart, choose the measure `NumInfectious`.

In the **Models** tab, open `tracing` and click *Compare…* to see every difference from
`baseline`.



## What you learned

- A rule can have several heads, separated by commas: each head gets a row when the body
  holds.
- A relation without time whose rule reads a temporal relation, such as `AllTransmissions`,
  collects the rows of all the days so far.
- In the **Run** and **Analyze** tabs, you can run several models many times and compare
  them in one chart.


