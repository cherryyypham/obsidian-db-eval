# Obsidian DB Eval


## Project Structure

```
📦
├─ CS5200_FinalProject_Pham.sql
├─ sync.yaml              -- configuration for the sync job
├─ load_vault.py          -- vault -> SQL: scans markdown, renders INSERTs
├─ HW10_Report_Pham.txt   -- write-up of what happened while building it
├─ requirements.txt
└─ .env.example
```


## Running the Program

Sync the vault into Postgres:

```bash
obsidian db sync
```

That scans every markdown file, drops and reloads the database, and prints a set of checks on what landed. It takes about a fifth of a second on 264 notes and writes nothing to disk — the `INSERT`s are rendered in memory and handed straight to Postgres.

| Flag | Effect |
| --- | --- |
| `--build` | Also rewrite Section 5 of the sql file from the vault |
| `--dry-run` | Do everything except touch the database |
| `--no-verify` | Skip the checks at the end |
| `-c PATH` | Use a different config file |
| `-q` | Warnings and errors only |

To run the whole script by hand, including the queries and the transaction demos:

```bash
psql -d notakinghub_hw10 -f CS5200_HW10_Pham.sql
```

Use `psql` for that, not the sync command: Sections 5 and 8 contain their own `BEGIN`/`COMMIT`/`ROLLBACK` blocks and psql honours them.

## Configuration

First-time setup:

```bash
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
```

Then make the command available from anywhere:

```bash
ln -s "$PWD/obsidian" ~/bin/obsidian
```

No virtualenv activation is needed afterwards — the script re-execs itself inside `.venv` when it finds one.

Everything else lives in `sync.yaml`:

| Key | Meaning |
| --- | --- |
| `vault.path` | The Obsidian vault to read |
| `database.url` | libpq URL; `postgresql:///name` uses the local socket |
| `database.create_if_missing` | Create the database instead of failing when it is absent |
| `output.script` | The combined SQL file |
| `output.write_data_section` | Rewrite Section 5 on every sync (same as `--build`) |
| `sync.mode` | `rebuild` or `dry-run` |
| `sync.steps` | Which section numbers to run, in order |
| `sync.verify` | Print the data checks after loading |
| `logging.file` | Where the run log is appended |

The sync always rebuilds rather than updating in place. The loader assigns ids 1..N in scan order so the generated rows can use literal foreign keys, and that is only true against empty tables. The whole load runs in one transaction: if any step fails, the database is left exactly as it was.

Postgres 18 and Python 3.11+ are assumed. `.env.example` shows the two environment variables `load_vault.py` reads when it is run on its own instead of through the CLI.
