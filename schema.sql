BEGIN;

-- ---------- Lookup tables ----------

CREATE TABLE content_medium (
    medium_id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    CONSTRAINT content_medium_name_ci_uq UNIQUE (name)
);

CREATE UNIQUE INDEX content_medium_name_lower_uq ON content_medium (LOWER(name));

CREATE TABLE maturity_stage (
    stage_id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    CONSTRAINT maturity_stage_name_ci_uq UNIQUE (name)
);

CREATE UNIQUE INDEX maturity_stage_name_lower_uq ON maturity_stage (LOWER(name));

-- Seed the controlled vocabularies (order matters: row 1 = default)
INSERT INTO
    content_medium (name)
VALUES ('uncategorized'),
    ('lecture'),
    ('research'),
    ('reflection');

INSERT INTO
    maturity_stage (name)
VALUES ('fetus'),
    ('toddler'),
    ('teen'),
    ('adult');

-- ---------- Core entities ----------

CREATE TABLE note (
    note_id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    creation_date TIMESTAMP NOT NULL DEFAULT now(),
    type TEXT NOT NULL DEFAULT 'normal' CHECK (type IN ('topic', 'normal')),
    publish_status TEXT NOT NULL DEFAULT 'private' CHECK (
        publish_status IN (
            'private',
            'draft',
            'published'
        )
    ),
    medium_id INT REFERENCES content_medium (medium_id),
    stage_id INT REFERENCES maturity_stage (stage_id)
);
-- Note titles double as the natural key the sync script upserts on
CREATE UNIQUE INDEX note_title_lower_uq ON note (LOWER(title));

CREATE TABLE alias (
    alias_id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    note_id INT NOT NULL REFERENCES note (note_id) ON DELETE CASCADE
);
-- Business rule: an alias must resolve unambiguously vault-wide
CREATE UNIQUE INDEX alias_name_lower_uq ON alias (LOWER(name));

CREATE TABLE topic (
    topic_id SERIAL PRIMARY KEY,
    name TEXT NOT NULL
);

CREATE UNIQUE INDEX topic_name_lower_uq ON topic (LOWER(name));

CREATE TABLE tag (
    tag_id SERIAL PRIMARY KEY,
    name TEXT NOT NULL
);
-- Business rule 2: a tag's name must be unique across the vault
CREATE UNIQUE INDEX tag_name_lower_uq ON tag (LOWER(name));

CREATE TABLE source (
    source_id SERIAL PRIMARY KEY,
    source_type TEXT,
    title TEXT NOT NULL,
    link TEXT,
    author TEXT
);

CREATE TABLE term (
    term_id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    external_reference_link TEXT
);

CREATE UNIQUE INDEX term_name_lower_uq ON term (LOWER(name));

-- ---------- Junction tables ----------

CREATE TABLE note_link (
    source_note_id INT NOT NULL REFERENCES note (note_id) ON DELETE CASCADE,
    target_note_id INT NOT NULL REFERENCES note (note_id) ON DELETE CASCADE,
    link_type TEXT,
    PRIMARY KEY (
        source_note_id,
        target_note_id
    ),
    -- Business rule 1: a note cannot link to itself
    CONSTRAINT note_link_no_self CHECK (
        source_note_id <> target_note_id
    )
);

CREATE TABLE note_topic (
    note_id INT NOT NULL REFERENCES note (note_id) ON DELETE CASCADE,
    topic_id INT NOT NULL REFERENCES topic (topic_id) ON DELETE CASCADE,
    PRIMARY KEY (note_id, topic_id)
);

CREATE TABLE note_tag (
    note_id INT NOT NULL REFERENCES note (note_id) ON DELETE CASCADE,
    tag_id INT NOT NULL REFERENCES tag (tag_id) ON DELETE CASCADE,
    PRIMARY KEY (note_id, tag_id)
);

CREATE TABLE note_source (
    note_id INT NOT NULL REFERENCES note (note_id) ON DELETE CASCADE,
    source_id INT NOT NULL REFERENCES source (source_id) ON DELETE CASCADE,
    PRIMARY KEY (note_id, source_id)
);

CREATE TABLE topic_hierarchy (
    parent_topic_id INT NOT NULL REFERENCES topic (topic_id) ON DELETE CASCADE,
    child_topic_id INT NOT NULL REFERENCES topic (topic_id) ON DELETE CASCADE,
    PRIMARY KEY (
        parent_topic_id,
        child_topic_id
    ),
    -- Business rule 3 (direct case): a topic cannot be its own parent
    CONSTRAINT topic_hierarchy_no_self CHECK (
        parent_topic_id <> child_topic_id
    )
);

CREATE TABLE term_topic (
    term_id INT NOT NULL REFERENCES term (term_id) ON DELETE CASCADE,
    topic_id INT NOT NULL REFERENCES topic (topic_id) ON DELETE CASCADE,
    PRIMARY KEY (term_id, topic_id)
);

-- ---------- Audit table ----------

CREATE TABLE maturity_stage_audit (
    audit_id SERIAL PRIMARY KEY,
    note_id INT NOT NULL REFERENCES note (note_id) ON DELETE CASCADE,
    old_stage_id INT REFERENCES maturity_stage (stage_id),
    new_stage_id INT REFERENCES maturity_stage (stage_id),
    changed_at TIMESTAMP NOT NULL DEFAULT now()
);

-- ============================================================
-- Triggers
-- ============================================================

-- Business rule 4: every note defaults to uncategorized/fetus
-- if not explicitly classified at insert time.
CREATE OR REPLACE FUNCTION set_default_classification() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.medium_id IS NULL THEN
        SELECT medium_id INTO NEW.medium_id FROM content_medium WHERE name = 'uncategorized';
    END IF;
    IF NEW.stage_id IS NULL THEN
        SELECT stage_id INTO NEW.stage_id FROM maturity_stage WHERE name = 'fetus';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_note_default_classification
    BEFORE INSERT ON note
    FOR EACH ROW EXECUTE FUNCTION set_default_classification();

-- Trigger-worthy business event: log every maturity_stage transition
CREATE OR REPLACE FUNCTION audit_maturity_stage_change() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.stage_id IS DISTINCT FROM OLD.stage_id THEN
        INSERT INTO maturity_stage_audit (note_id, old_stage_id, new_stage_id)
        VALUES (OLD.note_id, OLD.stage_id, NEW.stage_id);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_note_stage_audit
    AFTER UPDATE ON note
    FOR EACH ROW EXECUTE FUNCTION audit_maturity_stage_change();

-- Business rule 3 (transitive case): a topic cannot be listed as its
-- own ancestor anywhere in the hierarchy, not just as a direct parent.
CREATE OR REPLACE FUNCTION prevent_topic_hierarchy_cycle() RETURNS TRIGGER AS $$
DECLARE
    would_cycle BOOLEAN;
BEGIN
    WITH RECURSIVE ancestors AS (
        SELECT parent_topic_id FROM topic_hierarchy WHERE child_topic_id = NEW.parent_topic_id
        UNION
        SELECT th.parent_topic_id
        FROM topic_hierarchy th
        JOIN ancestors a ON th.child_topic_id = a.parent_topic_id
    )
    SELECT EXISTS (SELECT 1 FROM ancestors WHERE parent_topic_id = NEW.child_topic_id)
    INTO would_cycle;

    IF would_cycle THEN
        RAISE EXCEPTION 'Cycle detected: topic % is already an ancestor of topic %',
            NEW.child_topic_id, NEW.parent_topic_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_topic_hierarchy_no_cycle
    BEFORE INSERT ON topic_hierarchy
    FOR EACH ROW EXECUTE FUNCTION prevent_topic_hierarchy_cycle();

COMMIT;