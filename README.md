# EpiQL

EpiQL is a declarative, Datalog-inspired language for simulating the spread of
infectious diseases. A model declares relations (people, contact pools, disease states)
and rules that derive new facts from existing ones, including random draws such as "this
contact leads to an infection with probability *p*". The interpreter runs the rules over
discrete timesteps on a population dataset. Underneath, it compiles every rule to a query
plan and runs it on a query engine.

> **About this repository.** It contains the EpiQL binaries (under
> [Releases](../../releases)), example models, the tutorial and example data. The source
> code is not public: the query engine underneath EpiQL is ongoing research that has not
> been published yet.


## What is included

| Path                 | Contents                                                                     |
| -------------------- | ---------------------------------------------------------------------------- |
| [Releases](../../releases) | `epiql` (command line) and `epiql-web` (web interface) for Linux x86_64 |
| `models/`            | `baseline.epiql` (epidemic in Belgium), `tracing.epiql` (with testing and contact tracing), `tiny-town-demo.epiql` (the baseline with one infected person on day 0) |
| `tutorial/`          | Lessons that teach EpiQL step by step on Tiny Town, a town of eight people |
| `data/`              | Tiny Town, and descriptors and a downloader for Belgian population samples   |
| `config.json`        | An example run: the demo model on Tiny Town, 20 repetitions of 60 days      |
| `scripts/`           | `setup.sh` (unpack the binaries), `demo.sh` (run and summarise), `web.sh` (web interface), `clean.sh` (remove results and binaries; `--all` also removes your web workspace) |

## Quick start

You need Linux on x86_64 with glibc 2.34 or newer (Ubuntu 22.04+, Debian 12+).

1. Clone this repository, download the latest release archive into it, and unpack it:

   ```sh
   git clone https://github.com/UHasselt-DSI-Data-Systems-Lab/EpiQL.git epiql && cd epiql
   curl -LO https://github.com/UHasselt-DSI-Data-Systems-Lab/EpiQL/releases/download/v0.1.0/epiql-0.1.0-x86_64-linux.tar.gz
   scripts/setup.sh          # unpacks ./epiql and ./epiql-web, checks the system
   ```

2. **Belgian population (optional):** to run the models on a sample of 10k or 100k inhabitants of
   Belgium, download the data (see [`data/README.md`](data/README.md)):

   ```sh
   pip install gdown
   python3 data/download.py
   ```

   Then pick the dataset in the web interface (step 3). For the command line (step 4), set
   `"input_datasets": "data/bel-10k.json"` and `"epiql_program_path": "models/baseline.epiql"`
   in `config.json`. The demo model exposes only one person, which suits Tiny Town but not
   a population of 10k.
   Without this download, everything below still works on the small synthetic population.

3. **Web interface:** start it and open <http://127.0.0.1:8780/>. Stop it with Ctrl+C.

   ```sh
   scripts/web.sh
   ```

   The **Learn** tab has the tutorial. Under **Models** you can write models.
   **Run** runs one or more models on a dataset,
   and **Analyze** compares their outcomes in charts. Your models and experiments are stored
   in `epiql-workspace/`.

4. **Command line:** You can also run models from the command line instead of using the web interface. The following script runs the demo model on a small synthetic population, 20 times for 60 days each:

   ```sh
   scripts/demo.sh
   ```

   The full results are in `runs/<date-time>/output/`. Pass another config file to run that instead:
   `scripts/demo.sh my-config.json`.


## Config file

A run of the command line is described by a JSON config file:

```json
{
    "epiql_program_path": "models/tiny-town-demo.epiql",
    "timesteps": 60,
    "input_datasets": "data/tiny-town.json",
    "output_dir": "output",
    "output_format": "csv",
    "monte_carlo_runs": 20,
    "start_date": "2020-03-01"
}
```

The first five fields are required. `output_format` is `"parquet"` or `"csv"`. The rest
are optional:

| Field              | Default        | Meaning                                               |
| ------------------ | -------------- | ----------------------------------------------------- |
| `explain_plans`    | `false`        | Write all query plans to `query_plans.md`             |
| `profile_rules`    | `false`        | Write per-rule wall-clock times to `rule_timings.csv` |
| `partitions`       | number of CPUs | Number of parallel partitions                         |
| `monte_carlo_runs` | `1`            | Number of repetitions of the whole simulation         |
| `params`           | none           | Values for the `param`s of the program                |
| `start_date`       | none           | The date of timestep 0, as `"2020-09-01"`             |

A program can declare parameters, such as `param budget: u32 = 100;`, and use them in
its rules. `params` gives them other values for this run, as in
`"params": { "budget": 300, "priority": "ADULTS" }`. A program that calls a date function,
such as `date::weekday(now)`, needs `start_date`. One timestep is one day.

`epiql_program_path` and `input_datasets` are resolved relative to the config file, and
`output_dir` relative to the current directory.

### Output

```
output/
├── program.epiql                   a copy of the program that ran
├── config.json                     a copy of the config file
├── program_timings.csv             parse and run time per Monte Carlo run
└── run_0/
    ├── NumInfectious@0.csv         temporal output relation, one file per timestep
    ├── NumInfectious@1.csv
    ├── rule_timings.csv            only with "profile_rules": true
    └── query_plans.md              only with "explain_plans": true
```
