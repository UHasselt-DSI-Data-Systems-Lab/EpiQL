# Input data

The EpiQL input relations are not stored in this repository — they are published as
shared Google Drive folders and downloaded on demand.

| Folder | Contents | Link |
| --- | --- | --- |
| `common` | `prob_symptomatic.parquet`, `prob_symptomatic.csv`, `Calendar.zip` (shared across population sizes) | [Drive](https://drive.google.com/drive/folders/1UbXjq88h2wXYGltFCW4zmUppiPczb11N?usp=sharing) |
| `bel-10k` | `persons.parquet`, `members.parquet`, `person_member.parquet`, `contactprob_symmetric.parquet` | [Drive](https://drive.google.com/drive/folders/14fOi8EguSKi6AVwtRd3AcxyCs1mszd8y?usp=sharing) |
| `bel-100k` | the same four files, for a population of 100k | [Drive](https://drive.google.com/drive/folders/1O-VqdPecaUzIvx4XVUFS6s6WtTNkOoWg?usp=sharing) |

## Download

```bash
pip install gdown          # once
python3 data/download.py   # from anywhere; data always lands next to the script
```

Useful flags:

- `--dataset bel-10k` — fetch only one folder (repeatable; default is all).
- `--force` — re-download and re-extract even if the files are already there.
- `--dest DIR` — put the data somewhere other than `data/`.

Re-running the script without `--force` is cheap: folders that already have files are
skipped.

## Resulting layout

```
data/
├── download.py       # tracked
├── README.md         # tracked
├── bel-10k.json      # tracked — dataset descriptor
├── bel-100k.json     # tracked — dataset descriptor
├── common/
│   ├── prob_symptomatic.parquet
│   ├── prob_symptomatic.csv
│   ├── Calendar.zip
│   └── Calendar/     # unpacked by the script: 0.csv, 1.csv, …
├── bel-10k/
│   ├── persons.parquet
│   ├── members.parquet
│   ├── person_member.parquet
│   └── contactprob_symmetric.parquet
└── bel-100k/         # same files as bel-10k/
```

`Calendar` is a *temporal* input relation, so the interpreter expects a **directory** of
per-timestep files (`{timestep}.parquet` or `{timestep}.csv`) rather than a single file —
that is why the script unzips `Calendar.zip` for you.

Everything in this directory except `download.py`, `README.md` and `*.json` is
git-ignored (see the `/data/*` rules in the root `.gitignore`).

## Running a simulation against it

`data/bel-10k.json` describes the relations with paths relative to this directory
(dataset paths are resolved against the descriptor's own folder), so once the download
finishes it is ready to use; `data/bel-100k.json` likewise. They cover the five input relations of
`models/baseline.epiql`: `Persons`, `PersonMember`, `ContactProb`, `ProbSymptomatic`
and `Calendar`.

From a `config.json` in the repository root:

```json
{
    "epiql_program_path": "models/baseline.epiql",
    "timesteps": 240,
    "input_datasets": "data/bel-10k.json",
    "output_dir": "output",
    "output_format": "parquet"
}
```

```bash
./epiql --config config.json
```

See the [config reference](../README.md#config-file) in the main README.
