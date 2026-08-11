"""
obsidian_sync.py

Continuously watches an Obsidian vault for .md file changes and
upserts the corresponding metadata into the Postgres schema defined
in schema.sql

Run:
    source .venv/bin/activate
    pip install -r requirements.txt
    export VAULT_PATH=/Users/cherryyypham/NotakingHub
    export DATABASE_URL=postgresql://admin:123@localhost:5432/obsidian
    python obsidian_sync.py
"""

import os
import re
import sys
import time
import logging
import threading
from urllib.parse import urlparse
from pathlib import Path

import frontmatter
import psycopg2
from psycopg2.extensions import connection as PGConnection
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler, FileSystemEvent
from dotenv import load_dotenv

# pylint: disable=missing-function-docstring,missing-class-docstring

load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
log = logging.getLogger("obsidian_sync")

VAULT_PATH = Path(os.environ.get("VAULT_PATH", "")).expanduser()
DATABASE_URL = os.environ.get("DATABASE_URL", "")
DEBOUNCE_SECONDS = 0.75  # Obsidian/OS often fire multiple events per save

WIKILINK_RE = re.compile(r"\[\[([^\]|#]+)(?:\|[^\]]*)?(?:#[^\]]*)?\]\]")


def get_connection() -> PGConnection:
    """Return a PostgreSQL connection for the configured database URL."""
    if not DATABASE_URL:
        raise RuntimeError("DATABASE_URL is not set")
    parsed = urlparse(DATABASE_URL)
    if parsed.username == "user" and parsed.password == "pass":
        raise RuntimeError(
            "DATABASE_URL still contains the placeholder credentials from the "
            "example in obsidian_sync.py; replace them with a real PostgreSQL "
            "role and password."
        )
    try:
        conn = psycopg2.connect(DATABASE_URL)
    except psycopg2.OperationalError as exc:
        raise RuntimeError(
            "Failed to connect to PostgreSQL using DATABASE_URL. Check that "
            "the database exists, the role is valid, and the password is correct."
        ) from exc
    conn.autocommit = False
    return conn


def upsert_lookup(cur, table: str, id_col: str, name: str) -> int:
    """Insert or reuse a case-insensitive lookup row and return its id."""
    cur.execute(
        f"SELECT {id_col} FROM {table} WHERE LOWER(name) = LOWER(%s)", (name,)
    )
    row = cur.fetchone()
    if row:
        return row[0]
    cur.execute(
        f"INSERT INTO {table} (name) VALUES (%s) RETURNING {id_col}", (name,)
    )
    return cur.fetchone()[0]


def find_note_id_by_title_or_alias(cur, name: str):
    """Resolve a note id by title first, then by alias."""
    cur.execute("SELECT note_id FROM note WHERE LOWER(title) = LOWER(%s)", (name,))
    row = cur.fetchone()
    if row:
        return row[0]
    cur.execute("SELECT note_id FROM alias WHERE LOWER(name) = LOWER(%s)", (name,))
    row = cur.fetchone()
    return row[0] if row else None


def parse_note_file(path: Path):
    """Parse one Markdown note into the normalized sync payload."""
    post = frontmatter.load(path)
    meta = post.metadata
    title = meta.get("title", path.stem)

    aliases = meta.get("aliases") or []
    if isinstance(aliases, str):
        aliases = [aliases]

    topics = meta.get("topics") or []
    if isinstance(topics, str):
        topics = [topics]

    tags = meta.get("tags") or []
    if isinstance(tags, str):
        tags = [tags]

    medium = meta.get("medium")
    stage = meta.get("stage")
    note_type = "topic" if meta.get("type") == "topic" else "normal"
    publish_status = meta.get("publish_status", "private")

    source = None
    if meta.get("source_title"):
        source = {
            "source_type": meta.get("source_type"),
            "title": meta.get("source_title"),
            "link": meta.get("source_link"),
            "author": meta.get("source_author"),
        }

    links = list(dict.fromkeys(WIKILINK_RE.findall(post.content)))  # de-dup, preserve order

    return {
        "title": title,
        "aliases": aliases,
        "topics": topics,
        "tags": tags,
        "medium": medium,
        "stage": stage,
        "type": note_type,
        "publish_status": publish_status,
        "source": source,
        "links": links,
    }


def sync_note(cur, parsed: dict) -> int:
    """Upsert the note row and refresh its direct lookup associations."""
    title = parsed["title"]

    medium_id = None
    if parsed["medium"]:
        medium_id = upsert_lookup(cur, "content_medium", "medium_id", parsed["medium"])

    stage_id = None
    if parsed["stage"]:
        stage_id = upsert_lookup(cur, "maturity_stage", "stage_id", parsed["stage"])

    cur.execute("SELECT note_id FROM note WHERE LOWER(title) = LOWER(%s)", (title,))
    row = cur.fetchone()

    if row:
        note_id = row[0]
        cur.execute(
            """
            UPDATE note
            SET type = %s, publish_status = %s,
                medium_id = COALESCE(%s, medium_id),
                stage_id = COALESCE(%s, stage_id)
            WHERE note_id = %s
            """,
            (parsed["type"], parsed["publish_status"], medium_id, stage_id, note_id),
        )
    else:
        cur.execute(
            """
            INSERT INTO note (title, type, publish_status, medium_id, stage_id)
            VALUES (%s, %s, %s, %s, %s)
            RETURNING note_id
            """,
            (title, parsed["type"], parsed["publish_status"], medium_id, stage_id),
        )
        note_id = cur.fetchone()[0]

    sync_aliases(cur, note_id, parsed["aliases"])
    sync_topics(cur, note_id, parsed["topics"])
    sync_tags(cur, note_id, parsed["tags"])
    sync_source(cur, note_id, parsed["source"])

    return note_id


def sync_aliases(cur, note_id: int, aliases: list[str]):
    cur.execute("DELETE FROM alias WHERE note_id = %s", (note_id,))
    for name in aliases:
        cur.execute(
            "SELECT alias_id FROM alias WHERE LOWER(name) = LOWER(%s)", (name,)
        )
        if cur.fetchone():
            log.warning("Alias '%s' already claimed by another note; skipping", name)
            continue
        cur.execute(
            "INSERT INTO alias (name, note_id) VALUES (%s, %s)", (name, note_id)
        )


def sync_topics(cur, note_id: int, topics: list[str]):
    cur.execute("DELETE FROM note_topic WHERE note_id = %s", (note_id,))
    for name in topics:
        topic_id = upsert_lookup(cur, "topic", "topic_id", name)
        cur.execute(
            "INSERT INTO note_topic (note_id, topic_id) VALUES (%s, %s) "
            "ON CONFLICT DO NOTHING",
            (note_id, topic_id),
        )


def sync_tags(cur, note_id: int, tags: list[str]):
    cur.execute("DELETE FROM note_tag WHERE note_id = %s", (note_id,))
    for name in tags:
        tag_id = upsert_lookup(cur, "tag", "tag_id", name)
        cur.execute(
            "INSERT INTO note_tag (note_id, tag_id) VALUES (%s, %s) "
            "ON CONFLICT DO NOTHING",
            (note_id, tag_id),
        )


def sync_source(cur, note_id: int, source: dict | None):
    cur.execute("DELETE FROM note_source WHERE note_id = %s", (note_id,))
    if not source:
        return
    cur.execute("SELECT source_id FROM source WHERE LOWER(title) = LOWER(%s)", (source["title"],))
    row = cur.fetchone()
    if row:
        source_id = row[0]
    else:
        cur.execute(
            "INSERT INTO source (source_type, title, link, author) "
            "VALUES (%s, %s, %s, %s) RETURNING source_id",
            (source["source_type"], source["title"], source["link"], source["author"]),
        )
        source_id = cur.fetchone()[0]
    cur.execute(
        "INSERT INTO note_source (note_id, source_id) VALUES (%s, %s) "
        "ON CONFLICT DO NOTHING",
        (note_id, source_id),
    )


def sync_links(cur, note_id: int, link_titles: list[str]):
    cur.execute("DELETE FROM note_link WHERE source_note_id = %s", (note_id,))
    for target_title in link_titles:
        target_id = find_note_id_by_title_or_alias(cur, target_title)
        if target_id is None:
            log.warning(
                "Link target '%s' not found yet; skipping (will retry on next sync)",
                target_title,
            )
            continue
        if target_id == note_id:
            log.warning("Skipping self-link on note_id=%s", note_id)
            continue
        cur.execute(
            "INSERT INTO note_link (source_note_id, target_note_id, link_type) "
            "VALUES (%s, %s, %s) ON CONFLICT DO NOTHING",
            (note_id, target_id, "reference"),
        )


def sync_file(path: Path):
    if path.suffix.lower() != ".md":
        return
    try:
        parsed = parse_note_file(path)
    except Exception:  # pylint: disable=broad-exception-caught
        log.exception("Failed to parse %s", path)
        return

    conn = get_connection()
    try:
        with conn.cursor() as cur:
            note_id = sync_note(cur, parsed)
            sync_links(cur, note_id, parsed["links"])
        conn.commit()
        log.info("Synced: %s", path.relative_to(VAULT_PATH))
    except Exception:  # pylint: disable=broad-exception-caught
        conn.rollback()
        log.exception("Sync failed for %s", path)
    finally:
        conn.close()


def delete_file(path: Path):
    if path.suffix.lower() != ".md":
        return
    title = path.stem
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM note WHERE LOWER(title) = LOWER(%s)", (title,))
        conn.commit()
        log.info("Deleted note for removed file: %s", path.name)
    except Exception:  # pylint: disable=broad-exception-caught
        conn.rollback()
        log.exception("Delete failed for %s", path)
    finally:
        conn.close()

class VaultHandler(FileSystemEventHandler):
    def __init__(self):
        self._timers: dict[str, threading.Timer] = {}
        self._lock = threading.Lock()

    def _debounced(self, path_str: str, func, *args):
        with self._lock:
            existing = self._timers.get(path_str)
            if existing:
                existing.cancel()
            timer = threading.Timer(DEBOUNCE_SECONDS, func, args=args)
            self._timers[path_str] = timer
            timer.start()

    def on_created(self, event: FileSystemEvent):
        if not event.is_directory:
            self._debounced(event.src_path, sync_file, Path(event.src_path))

    def on_modified(self, event: FileSystemEvent):
        if not event.is_directory:
            self._debounced(event.src_path, sync_file, Path(event.src_path))

    def on_deleted(self, event: FileSystemEvent):
        if not event.is_directory:
            self._debounced(event.src_path, delete_file, Path(event.src_path))

    def on_moved(self, event: FileSystemEvent):
        if event.is_directory:
            return
        self._debounced(event.src_path, delete_file, Path(event.src_path))
        self._debounced(event.dest_path, sync_file, Path(event.dest_path))


def initial_full_scan():
    """Sync every existing .md file once at startup so the DB starts
    consistent with the vault, rather than only reacting to future edits."""
    md_files = list(VAULT_PATH.rglob("*.md"))
    log.info("Initial scan: %d markdown files", len(md_files))
    for path in md_files:
        sync_file(path)


def main():
    if not VAULT_PATH.exists():
        log.error("VAULT_PATH does not exist: %s", VAULT_PATH)
        sys.exit(1)

    initial_full_scan()

    handler = VaultHandler()
    observer = Observer()
    observer.schedule(handler, str(VAULT_PATH), recursive=True)
    observer.start()
    log.info("Watching %s for changes... (Ctrl+C to stop)", VAULT_PATH)

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
    observer.join()


if __name__ == "__main__":
    main()
