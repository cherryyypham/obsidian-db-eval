-- =====================================================================
-- SECTION 1: HEADER
-- =====================================================================

-- CS 5200  Database Management Systems  Summer 2026
-- Final Project
-- Student name:  Cherry Pham
-- Date:          08/14/2026
-- AI Disclosure: I use Claude to help me with Obsidian data transfer/sync script to populate the database and to write the README.

-- =====================================================================
-- SECTION 2: DROP TABLES
-- =====================================================================

DROP TABLE IF EXISTS node_stage_audit CASCADE;

DROP TABLE IF EXISTS term_topics CASCADE;

DROP TABLE IF EXISTS topic_hierarchy CASCADE;

DROP TABLE IF EXISTS node_sources CASCADE;

DROP TABLE IF EXISTS node_tags CASCADE;

DROP TABLE IF EXISTS node_topics CASCADE;

DROP TABLE IF EXISTS node_links CASCADE;

DROP TABLE IF EXISTS aliases CASCADE;

DROP TABLE IF EXISTS nodes CASCADE;

DROP TABLE IF EXISTS sources CASCADE;

DROP TABLE IF EXISTS terms CASCADE;

DROP TABLE IF EXISTS free_tags CASCADE;

DROP TABLE IF EXISTS topic_tags CASCADE;

DROP TABLE IF EXISTS maturity_stages CASCADE;

DROP TABLE IF EXISTS identity_tags CASCADE;

-- =====================================================================
-- SECTION 3: SCHEMA
-- =====================================================================

CREATE TABLE identity_tags (
    identity_tag_id INTEGER GENERATED ALWAYS AS IDENTITY,
    title VARCHAR(100) NOT NULL,
    CONSTRAINT pk_identity_tags PRIMARY KEY (identity_tag_id),
    -- 'uncategorized' is the vault's explicit "not decided yet" value and
    -- is distinct from an absent identity tag, which is NULL.
    CONSTRAINT ck_identity_tags_title CHECK (
        title IN (
            'lecture',
            'research',
            'thought',
            'uncategorized'
        )
    ),
    CONSTRAINT uq_identity_tags_title UNIQUE (title)
);

CREATE TABLE maturity_stages (
    maturity_stage_id INTEGER GENERATED ALWAYS AS IDENTITY,
    name VARCHAR(100) NOT NULL,
    CONSTRAINT pk_maturity_stages PRIMARY KEY (maturity_stage_id),
    -- Union of the HW9 stages and the ones the live vault writes.
    CONSTRAINT ck_maturity_stages_name CHECK (
        name IN (
            'fetus',
            'infant',
            'toddler',
            'adolescent',
            'teen',
            'adult'
        )
    ),
    CONSTRAINT uq_maturity_stages_name UNIQUE (name)
);

CREATE TABLE topic_tags (
    topic_tag_id INTEGER GENERATED ALWAYS AS IDENTITY,
    topic VARCHAR(100) NOT NULL,
    CONSTRAINT pk_topic_tags PRIMARY KEY (topic_tag_id),
    CONSTRAINT uq_topic_tags_topic UNIQUE (topic)
);

CREATE TABLE free_tags (
    free_tag_id INTEGER GENERATED ALWAYS AS IDENTITY,
    name VARCHAR(100) NOT NULL,
    CONSTRAINT pk_free_tags PRIMARY KEY (free_tag_id),
    CONSTRAINT uq_free_tags_name UNIQUE (name)
);

CREATE TABLE terms (
    term_id INTEGER GENERATED ALWAYS AS IDENTITY,
    name VARCHAR(200) NOT NULL,
    external_reference_link VARCHAR(500),
    CONSTRAINT pk_terms PRIMARY KEY (term_id),
    CONSTRAINT uq_terms_name UNIQUE (name)
);

CREATE TABLE sources (
    source_id INTEGER GENERATED ALWAYS AS IDENTITY,
    source_type VARCHAR(20),
    title VARCHAR(200) NOT NULL,
    link VARCHAR(500),
    author VARCHAR(200),
    CONSTRAINT pk_sources PRIMARY KEY (source_id),
    CONSTRAINT ck_sources_source_type CHECK (
        source_type IN (
            'book',
            'article',
            'video',
            'podcast',
            'website',
            'lecture',
            'paper',
            'link',
            'slides',
            'documentation',
            'repository',
            'forum'
        )
    ),
    CONSTRAINT uq_sources_title_link UNIQUE (title, link)
);

CREATE TABLE nodes (
    node_id INTEGER GENERATED ALWAYS AS IDENTITY,
    vault_path VARCHAR(300) NOT NULL,
    title VARCHAR(200) NOT NULL,
    note_type VARCHAR(20) NOT NULL,
    publish_status VARCHAR(20) NOT NULL,
    vault_folder VARCHAR(30) NOT NULL,
    identity_tag_id INTEGER,
    maturity_stage_id INTEGER,
    date_created TIMESTAMPTZ,
    date_modified TIMESTAMPTZ,
    CONSTRAINT pk_nodes PRIMARY KEY (node_id),
    CONSTRAINT ck_nodes_note_type CHECK (
        note_type IN (
            'fleeting',
            'literature',
            'permanent',
            'structure',
            'normal',
            'topic'
        )
    ),
    CONSTRAINT ck_nodes_publish_status CHECK (
        publish_status IN (
            'draft',
            'published',
            'private'
        )
    ),
    CONSTRAINT ck_nodes_vault_folder CHECK (
        vault_folder IN (
            'inbox',
            'literature',
            'permanent',
            'structure',
            'archive',
            'zettelkasten',
            'courses',
            'topics',
            'indexes'
        )
    ),
    -- Passes when either timestamp is NULL: NULL >= NULL is unknown, and
    -- CHECK accepts unknown.
    CONSTRAINT ck_nodes_modified_after_created CHECK (date_modified >= date_created),
    CONSTRAINT uq_nodes_vault_path UNIQUE (vault_path),
    CONSTRAINT uq_nodes_title_folder UNIQUE (title, vault_folder),
    CONSTRAINT fk_nodes_identity_tag FOREIGN KEY (identity_tag_id) REFERENCES identity_tags (identity_tag_id) ON DELETE RESTRICT,
    CONSTRAINT fk_nodes_maturity_stage FOREIGN KEY (maturity_stage_id) REFERENCES maturity_stages (maturity_stage_id) ON DELETE RESTRICT
);

CREATE TABLE aliases (
    alias_id INTEGER GENERATED ALWAYS AS IDENTITY,
    name VARCHAR(100) NOT NULL,
    node_id INTEGER NOT NULL,
    CONSTRAINT pk_aliases PRIMARY KEY (alias_id),
    CONSTRAINT uq_aliases_node_name UNIQUE (node_id, name),
    CONSTRAINT fk_aliases_node FOREIGN KEY (node_id) REFERENCES nodes (node_id) ON DELETE CASCADE
);

CREATE TABLE node_links (
    node_link_id INTEGER GENERATED ALWAYS AS IDENTITY,
    source_node_id INTEGER NOT NULL,
    target_node_id INTEGER NOT NULL,
    link_type VARCHAR(20) NOT NULL,
    CONSTRAINT pk_node_links PRIMARY KEY (node_link_id),
    CONSTRAINT ck_node_links_link_type CHECK (
        link_type IN (
            'wiki_link',
            'derived_from',
            'related',
            'contradicts',
            'reference'
        )
    ),
    CONSTRAINT ck_node_links_no_self_link CHECK (
        source_node_id <> target_node_id
    ),
    CONSTRAINT uq_node_links_source_target_type UNIQUE (
        source_node_id,
        target_node_id,
        link_type
    ),
    CONSTRAINT fk_node_links_source FOREIGN KEY (source_node_id) REFERENCES nodes (node_id) ON DELETE CASCADE,
    CONSTRAINT fk_node_links_target FOREIGN KEY (target_node_id) REFERENCES nodes (node_id) ON DELETE CASCADE
);

CREATE TABLE node_topics (
    node_topic_id INTEGER GENERATED ALWAYS AS IDENTITY,
    node_id INTEGER NOT NULL,
    topic_tag_id INTEGER NOT NULL,
    CONSTRAINT pk_node_topics PRIMARY KEY (node_topic_id),
    CONSTRAINT uq_node_topics_node_topic UNIQUE (node_id, topic_tag_id),
    CONSTRAINT fk_node_topics_node FOREIGN KEY (node_id) REFERENCES nodes (node_id) ON DELETE CASCADE,
    CONSTRAINT fk_node_topics_topic FOREIGN KEY (topic_tag_id) REFERENCES topic_tags (topic_tag_id) ON DELETE CASCADE
);

CREATE TABLE node_tags (
    node_tag_id INTEGER GENERATED ALWAYS AS IDENTITY,
    node_id INTEGER NOT NULL,
    free_tag_id INTEGER NOT NULL,
    CONSTRAINT pk_node_tags PRIMARY KEY (node_tag_id),
    CONSTRAINT uq_node_tags_node_tag UNIQUE (node_id, free_tag_id),
    CONSTRAINT fk_node_tags_node FOREIGN KEY (node_id) REFERENCES nodes (node_id) ON DELETE CASCADE,
    CONSTRAINT fk_node_tags_tag FOREIGN KEY (free_tag_id) REFERENCES free_tags (free_tag_id) ON DELETE CASCADE
);

CREATE TABLE node_sources (
    node_source_id INTEGER GENERATED ALWAYS AS IDENTITY,
    node_id INTEGER NOT NULL,
    source_id INTEGER NOT NULL,
    CONSTRAINT pk_node_sources PRIMARY KEY (node_source_id),
    CONSTRAINT uq_node_sources_node_source UNIQUE (node_id, source_id),
    CONSTRAINT fk_node_sources_node FOREIGN KEY (node_id) REFERENCES nodes (node_id) ON DELETE CASCADE,
    CONSTRAINT fk_node_sources_source FOREIGN KEY (source_id) REFERENCES sources (source_id) ON DELETE CASCADE
);

CREATE TABLE topic_hierarchy (
    topic_hierarchy_id INTEGER GENERATED ALWAYS AS IDENTITY,
    parent_topic_tag_id INTEGER NOT NULL,
    child_topic_tag_id INTEGER NOT NULL,
    CONSTRAINT pk_topic_hierarchy PRIMARY KEY (topic_hierarchy_id),
    CONSTRAINT ck_topic_hierarchy_no_self_parent CHECK (
        parent_topic_tag_id <> child_topic_tag_id
    ),
    CONSTRAINT uq_topic_hierarchy_parent_child UNIQUE (
        parent_topic_tag_id,
        child_topic_tag_id
    ),
    CONSTRAINT fk_topic_hierarchy_parent FOREIGN KEY (parent_topic_tag_id) REFERENCES topic_tags (topic_tag_id) ON DELETE CASCADE,
    CONSTRAINT fk_topic_hierarchy_child FOREIGN KEY (child_topic_tag_id) REFERENCES topic_tags (topic_tag_id) ON DELETE CASCADE
);

CREATE TABLE term_topics (
    term_topic_id INTEGER GENERATED ALWAYS AS IDENTITY,
    term_id INTEGER NOT NULL,
    topic_tag_id INTEGER NOT NULL,
    CONSTRAINT pk_term_topics PRIMARY KEY (term_topic_id),
    CONSTRAINT uq_term_topics_term_topic UNIQUE (term_id, topic_tag_id),
    CONSTRAINT fk_term_topics_term FOREIGN KEY (term_id) REFERENCES terms (term_id) ON DELETE CASCADE,
    CONSTRAINT fk_term_topics_topic FOREIGN KEY (topic_tag_id) REFERENCES topic_tags (topic_tag_id) ON DELETE CASCADE
);

-- Written only by the trigger in Section 6.
CREATE TABLE node_stage_audit (
    node_stage_audit_id INTEGER GENERATED ALWAYS AS IDENTITY,
    node_id INTEGER NOT NULL,
    old_maturity_stage_id INTEGER,
    new_maturity_stage_id INTEGER,
    direction VARCHAR(10) NOT NULL,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT pk_node_stage_audit PRIMARY KEY (node_stage_audit_id),
    CONSTRAINT ck_node_stage_audit_direction CHECK (
        direction IN (
            'promoted',
            'demoted',
            'classified',
            'cleared'
        )
    ),
    CONSTRAINT fk_node_stage_audit_node FOREIGN KEY (node_id) REFERENCES nodes (node_id) ON DELETE CASCADE,
    CONSTRAINT fk_node_stage_audit_old FOREIGN KEY (old_maturity_stage_id) REFERENCES maturity_stages (maturity_stage_id) ON DELETE RESTRICT,
    CONSTRAINT fk_node_stage_audit_new FOREIGN KEY (new_maturity_stage_id) REFERENCES maturity_stages (maturity_stage_id) ON DELETE RESTRICT
);

-- =====================================================================
-- SECTION 4: VIEW & FUNCTION
-- =====================================================================

-- View: one row per topic, with the shape of the writing under it.
-- Every join is a LEFT JOIN so a topic nobody has written under yet still
-- gets a row of zeros. Read by Q8.
CREATE OR REPLACE VIEW v_topic_activity AS
SELECT
    tt.topic_tag_id,
    tt.topic,
    COUNT(DISTINCT n.node_id) AS note_count,
    COUNT(DISTINCT n.node_id) FILTER (
        WHERE ms.name IN ('teen', 'adult')
    ) AS mature_note_count,
    COUNT(DISTINCT n.node_id) FILTER (
        WHERE n.publish_status = 'published'
    ) AS published_note_count,
    COUNT(DISTINCT ns.source_id) AS distinct_source_count,
    MIN(n.date_created)::DATE AS first_note_on,
    MAX(n.date_modified)::DATE AS last_touched_on
FROM topic_tags tt
LEFT JOIN node_topics nt ON nt.topic_tag_id = tt.topic_tag_id
LEFT JOIN nodes n ON n.node_id = nt.node_id
LEFT JOIN maturity_stages ms ON ms.maturity_stage_id = n.maturity_stage_id
LEFT JOIN node_sources ns ON ns.node_id = n.node_id
GROUP BY tt.topic_tag_id, tt.topic;

-- Function: how load-bearing is this note right now? Weights the things
-- that cost effort -- 3 x sources cited, 2 x outgoing links, 2 x incoming
-- links, 1 x aliases -- then discounts the total for going stale, so a
-- note untouched for a year is worth half of one edited yesterday. That
-- decay is what a plain COUNT cannot express. Returns NULL for a node_id
-- that does not exist, which is not the same as a score of zero.
-- Called by Q8.
CREATE OR REPLACE FUNCTION fn_note_health(p_node_id INTEGER)
RETURNS NUMERIC AS $$
DECLARE
    v_raw           NUMERIC;
    v_months_stale  NUMERIC;
    v_touched       TIMESTAMPTZ;
BEGIN
    SELECT COALESCE(n.date_modified, n.date_created)
    INTO v_touched
    FROM nodes n
    WHERE n.node_id = p_node_id;

    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    SELECT 3 * (SELECT COUNT(*) FROM node_sources s WHERE s.node_id = p_node_id)
         + 2 * (SELECT COUNT(*) FROM node_links l WHERE l.source_node_id = p_node_id)
         + 2 * (SELECT COUNT(*) FROM node_links l WHERE l.target_node_id = p_node_id)
         + 1 * (SELECT COUNT(*) FROM aliases a WHERE a.node_id = p_node_id)
    INTO v_raw;

    -- An undated note is treated as maximally stale, not as brand new.
    v_months_stale := COALESCE(
        EXTRACT(EPOCH FROM (now() - v_touched)) / 2629746.0,
        24
    );

    RETURN ROUND(v_raw / (1 + GREATEST(v_months_stale, 0) / 12.0), 2);
END;
$$ LANGUAGE plpgsql STABLE;

-- =====================================================================
-- SECTION 5: SAMPLE DATA
-- =====================================================================

-- These INSERT statements are generated by load_vault.py from the
-- live NotakingHub Obsidian vault. Do not hand-edit: re-run
-- `obsidian db sync --build` instead.
--
-- Parents are inserted before children, so the ids Postgres assigns
-- are 1..N in the order written here and the literal ids in the
-- child rows are the ones the generator observed.

BEGIN;

-- Notes that declare no identity get NULL in nodes.identity_tag_id.
INSERT INTO
    identity_tags (title)
VALUES ('lecture'),
    ('research'),
    ('thought'),
    ('uncategorized');

-- 'infant' and 'adolescent' are in the vocabulary but no note sits
-- at either stage: parents with zero children, for Q1.
INSERT INTO
    maturity_stages (name)
VALUES ('fetus'),
    ('infant'),
    ('toddler'),
    ('adolescent'),
    ('teen'),
    ('adult');

INSERT INTO
    topic_tags (topic)
VALUES ('Biology'),
    ('Literature'),
    ('Chinese Literature'),
    ('Computer Science'),
    ('Mathematics'),
    ('Data Science'),
    ('Machine Learning'),
    ('Psychology'),
    ('Motivation Theory'),
    ('Neuro Science'),
    ('Sociology'),
    ('Pedagogy'),
    ('Vietnamese Literature'),
    ('Western Literature'),
    ('Clustering'),
    ('SDT Reading Map'),
    ('Self-Regulation Theory');

INSERT INTO
    free_tags (name)
VALUES ('stub'),
    ('question'),
    ('todo');

-- No vault term has a glossary link yet, so the column is all NULL.
INSERT INTO
    terms (name, external_reference_link)
VALUES ('executive function', NULL),
    ('dopamine', NULL),
    ('working memory', NULL),
    ('exemplar', NULL),
    ('message passing', NULL),
    ('preference', NULL),
    ('linkage', NULL),
    ('dendrogram', NULL),
    ('Ward''s method', NULL),
    ('support', NULL),
    ('confidence', NULL),
    ('lift', NULL),
    ('frequent itemset', NULL),
    ('soul search', NULL),
    ('set boundaries', NULL),
    ('"Emma"', NULL),
    (
        'clustering feature tree',
        NULL
    ),
    ('CF vector', NULL),
    ('branching factor', NULL),
    ('marginal likelihood', NULL),
    ('evidence ratio', NULL),
    ('model comparison', NULL),
    ('prior', NULL),
    ('likelihood', NULL),
    ('posterior', NULL),
    ('COMMANDS', NULL),
    ('Database', NULL),
    ('Vocabulary', NULL),
    (
        'DBMS: Database Management System',
        NULL
    ),
    ('DBMS', NULL),
    ('schema', NULL),
    ('data model', NULL),
    (
        'Entity vs Entity Instance',
        NULL
    ),
    ('Weak entities', NULL),
    ('simple', NULL),
    ('composite', NULL),
    ('multivalued', NULL),
    ('derived', NULL),
    ('Superkey', NULL),
    ('Candidate Key', NULL),
    ('Primary Key', NULL),
    ('Requirements', NULL),
    ('Composite Key', NULL),
    ('Foreign Key', NULL),
    ('INSERT', NULL),
    ('UPDATE', NULL),
    ('DELETE', NULL),
    ('DML', NULL),
    ('inner join', NULL),
    ('CTE', NULL),
    ('window function', NULL),
    ('partition by', NULL),
    ('functional dependency', NULL),
    ('BCNF', NULL),
    ('third normal form', NULL),
    ('relational algebra', NULL),
    ('projection', NULL),
    ('selection', NULL),
    ('trigger', NULL),
    ('stored procedure', NULL),
    ('user-defined function', NULL),
    ('ACID', NULL),
    ('isolation level', NULL),
    ('deadlock', NULL),
    ('B-tree', NULL),
    ('clustered index', NULL),
    ('query plan', NULL),
    ('selectivity', NULL),
    ('broadcast addition', NULL),
    ('norm', NULL),
    ('regulation', NULL),
    ('vector space', NULL),
    ('span', NULL),
    ('basis', NULL),
    (
        'Derivatives for Matrices',
        NULL
    ),
    ('Gradient Descent', NULL),
    ('Hessian Matrix', NULL),
    (
        'Soft-max and Cross-entropy',
        NULL
    ),
    ('p-value', NULL),
    ('null hypothesis', NULL),
    ('least squares', NULL),
    ('residual', NULL),
    ('R-squared', NULL),
    (
        'low bias, high variance',
        NULL
    ),
    (
        'large bias, low variance',
        NULL
    ),
    ('margin', NULL),
    ('kernel trick', NULL),
    ('hyperparameter tuning', NULL),
    ('tree', NULL),
    ('nodes', NULL),
    ('leafs', NULL),
    ('Impurity', NULL),
    ('Misclassification', NULL),
    ('Gini index', NULL),
    ('Pad++', NULL),
    ('discrimination', NULL),
    ('feature matrix', NULL),
    ('normalization', NULL),
    ('centroid', NULL),
    ('inertia', NULL),
    ('actual negative', NULL),
    ('positive.', NULL),
    ('True', NULL),
    ('rate', NULL),
    ('specificity', NULL),
    ('actual', NULL),
    ('silhouette score', NULL),
    ('Due dates', NULL),
    ('Documents', NULL),
    ('Corpus', NULL),
    ('Bag of Words', NULL),
    ('Term frequency', NULL),
    ('Cosine distance', NULL),
    ('Cliques', NULL),
    ('Complete Graph', NULL),
    (
        'Bron-Kerbosch Recursive Algorithm',
        NULL
    ),
    ('Graph Density', NULL),
    ('Dijsktra''s Algorithm', NULL),
    ('centrality', NULL),
    (
        'Univariate - 1 variable',
        NULL
    ),
    ('eigenvector', NULL),
    ('explained variance', NULL),
    ('scree plot', NULL),
    ('Genetics algorithm', NULL),
    ('Representation', NULL),
    (
        'Fitness/evaluation function',
        NULL
    ),
    ('Population', NULL),
    (
        'Parent selection mechanism',
        NULL
    ),
    ('crossover', NULL),
    ('manifold', NULL),
    ('t-SNE', NULL),
    ('UMAP', NULL),
    ('parametric', NULL),
    ('non-parametric', NULL),
    (
        'bias-variance tradeoff',
        NULL
    ),
    ('natural join', NULL),
    ('epsilon', NULL),
    ('minPts', NULL),
    ('core point', NULL),
    ('density-reachable', NULL),
    ('Core Points', NULL),
    ('Primary tuning', NULL),
    ('throughput', NULL),
    ('checkpointing', NULL),
    ('GPU utilization', NULL),
    ('train/test split', NULL),
    ('label noise', NULL),
    ('class imbalance', NULL),
    (
        'Switchboard -- encoder training',
        NULL
    ),
    (
        'Expresso -- decoder training',
        NULL
    ),
    ('Pretrain', NULL),
    ('triangle inequality', NULL),
    ('distance bound', NULL),
    ('pruning', NULL),
    ('Key insight', NULL),
    (
        'Triangle Inequality Lemma',
        NULL
    ),
    ('Key characteristics', NULL),
    (
        'expectation maximization',
        NULL
    ),
    ('mixture component', NULL),
    ('covariance type', NULL),
    ('learning rate', NULL),
    ('step size', NULL),
    ('convergence', NULL),
    (
        'mutual reachability distance',
        NULL
    ),
    ('condensed tree', NULL),
    ('minimum cluster size', NULL),
    ('seeding', NULL),
    (
        'centroid initialization',
        NULL
    ),
    ('D2 sampling', NULL),
    ('Lloyd''s algorithm', NULL),
    ('elbow method', NULL),
    ('Background', NULL),
    ('Centers', NULL),
    ('medoid', NULL),
    (
        'partitioning around medoids',
        NULL
    ),
    ('swap step', NULL),
    ('distance metric', NULL),
    ('k', NULL),
    (
        'curse of dimensionality',
        NULL
    ),
    ('eigenvalue', NULL),
    ('rank', NULL),
    ('null space', NULL),
    ('magnitude', NULL),
    ('direction', NULL),
    (
        'ordinary least squares',
        NULL
    ),
    ('coefficient', NULL),
    ('tam cương lĩnh', NULL),
    ('Minh minh đức', NULL),
    ('Tân dân', NULL),
    ('Chỉ ư chí thiện', NULL),
    ('bát điều mục', NULL),
    ('Tam cương', NULL),
    ('assignment step', NULL),
    ('update step', NULL),
    ('center of gravity', NULL),
    ('bandwidth', NULL),
    (
        'kernel density estimation',
        NULL
    ),
    ('mode', NULL),
    ('basin of attraction', NULL),
    ('windows', NULL),
    ('radius', NULL),
    ('Date', NULL),
    (
        'Have a decision-making framework',
        NULL
    ),
    (
        'On individual contributor roles',
        NULL
    ),
    ('Tools', NULL),
    ('Platform', NULL),
    ('Colleague''s focus', NULL),
    ('mini-batch', NULL),
    ('stochastic update', NULL),
    ('convergence tolerance', NULL),
    (
        'Key differences from Lloyd''s',
        NULL
    ),
    ('Update rule', NULL),
    ('mel spectrogram', NULL),
    ('waveform synthesis', NULL),
    ('fidelity', NULL),
    ('discrete RVQ tokens', NULL),
    ('Colloquially, yes.', NULL),
    ('neural codec decoder', NULL),
    ('reachability plot', NULL),
    ('core distance', NULL),
    ('ordering', NULL),
    (
        'positive semi-definite',
        NULL
    ),
    ('quadratic form', NULL),
    ('big dreams', NULL),
    ('normalizing constant', NULL),
    ('HDBSCAN', NULL),
    ('BERTopic', NULL),
    (
        '`distilbert-base-uncased`',
        NULL
    ),
    ('`bert-base-uncased`', NULL),
    ('`roberta-base`', NULL),
    ('singular value', NULL),
    ('orthogonal matrix', NULL),
    ('Dimension Eraser', NULL),
    ('Dimension Adder', NULL),
    ('Left Singular Vectors', NULL),
    ('simplex', NULL),
    ('half duplex', NULL),
    ('full duplex', NULL),
    ('graph Laplacian', NULL),
    ('affinity matrix', NULL),
    ('eigengap', NULL),
    ('phoneme', NULL),
    ('prosody', NULL),
    ('goal pursuit', NULL),
    ('need satisfaction', NULL),
    (
        'organismic integration',
        NULL
    ),
    ('intrinsic motivation', NULL),
    ('extrinsic motivation', NULL),
    ('basic needs', NULL),
    ('hierarchical model', NULL),
    (
        'situational motivation',
        NULL
    ),
    ('global motivation', NULL),
    ('locus of causality', NULL),
    ('stability', NULL),
    ('controllability', NULL),
    (
        'self-regulated learning',
        NULL
    ),
    ('co-regulation', NULL),
    (
        'socially shared regulation',
        NULL
    ),
    ('causal attribution', NULL),
    (
        'achievement motivation',
        NULL
    ),
    ('locus of control', NULL),
    ('cyclical phases', NULL),
    ('self-efficacy', NULL),
    ('embedding', NULL),
    ('perplexity', NULL),
    ('latency', NULL),
    ('turn-taking', NULL),
    ('voice cloning', NULL),
    ('Deepgram Eval', NULL),
    ('Speechmatics', NULL),
    ('stacking', NULL),
    ('meta-learner', NULL),
    (
        'out-of-fold prediction',
        NULL
    ),
    ('Why overfitting', NULL),
    ('How to not', NULL);

-- source_type, link and author each hold NULL on some rows and a
-- value on others.
INSERT INTO
    sources (
        source_type,
        title,
        link,
        author
    )
VALUES (
        'link',
        'Open-source software',
        'https://www.google.com/search?q=Open-source+software&sca_esv=f03daf4eddc76bb6&sxsrf=ANbL-n4s0xvch_hWq5pil6XPYANQZG4FIw%3A1774129191198&ei=JxC_aY_sC4acw8cPkbW46Ak&biw=1470&bih=919&oq=oss+&gs_lp=Egxnd3Mtd2l6LXNlcnAiBG9zcyAqAggAMgoQABiABBhDGIoFMgoQABiABBhDGIoFMgoQABiABBhDGIoFMgoQABiABBhDGIoFM',
        NULL
    ),
    (
        'forum',
        'www.reddit.com',
        'https://www.reddit.com/r/ADHD/comments/1cr0c54/what_gives_you_energy_if_caffeine_doesnt_work/',
        NULL
    ),
    (
        'link',
        'www.webmd.com',
        'https://www.webmd.com/add-adhd/adhd-caffeine',
        NULL
    ),
    (
        'link',
        'pmc.ncbi.nlm.nih.gov',
        'https://pmc.ncbi.nlm.nih.gov/articles/PMC8850715/#:~:text=This%20review%20concluded%20that%20caffeine,than%20caffeine%20for%20these%20indicators',
        NULL
    ),
    (
        'link',
        'munsterbehavioralhealth.com',
        'https://munsterbehavioralhealth.com/does-caffeine-make-adhd-sleepy/#:~:text=This%20explains%20why%20caffeine%20makes,heart%20rate%20or%20blood%20pressure',
        NULL
    ),
    (
        'link',
        'www.semanticscholar.org',
        'https://www.semanticscholar.org/paper/Effects-of-Caffeine-on-Main-Symptoms-in-Children-A-Perrotte-Moreira/8d0be4b95b555fe705ef35322f4dece430de4c82',
        NULL
    ),
    (
        'documentation',
        'Affinity Propagation scikit-learn',
        'https://scikit-learn.org/stable/modules/generated/sklearn.cluster.AffinityPropagation.html#sklearn.cluster.AffinityPropagation',
        NULL
    ),
    (
        'documentation',
        'Agglomerative Clustering scikit-learn',
        'https://scikit-learn.org/stable/modules/generated/sklearn.cluster.AgglomerativeClustering.html#sklearn.cluster.AgglomerativeClustering',
        NULL
    ),
    (
        'link',
        'www.anthropic.com',
        'https://www.anthropic.com/',
        NULL
    ),
    (
        'video',
        'www.youtube.com',
        'https://www.youtube.com/watch?v=guVvtZ7ZClw',
        NULL
    ),
    (
        'documentation',
        'BIRCH scikit-learn',
        'https://scikit-learn.org/stable/modules/generated/sklearn.cluster.Birch.html#sklearn.cluster.Birch',
        NULL
    ),
    (
        'slides',
        'CS5200_Syllabus_Summer2026.pdf',
        NULL,
        NULL
    ),
    (
        'slides',
        'CS5200_Week2_Lecture_Slides.pdf',
        NULL,
        NULL
    ),
    (
        'slides',
        'CS5200_Week3_Slides.pdf',
        NULL,
        NULL
    ),
    (
        'slides',
        'CS5200_Week4_FINAL.pdf',
        NULL,
        NULL
    ),
    (
        'slides',
        'CS5200_Week6_Slides_Final.pdf',
        NULL,
        NULL
    ),
    (
        'slides',
        'CS5200_Week7_Slides_FINAL.pdf',
        NULL,
        NULL
    ),
    (
        'slides',
        'CS5200_Week8_Slides_Lectures.pdf',
        NULL,
        NULL
    ),
    (
        'slides',
        'CS5200_Week9_Lecture_Slides.pdf',
        NULL,
        NULL
    ),
    (
        'slides',
        'CS5200_Week10_Slides_Final.pdf',
        NULL,
        NULL
    ),
    (
        'link',
        'en.wikipedia.org',
        'https://en.wikipedia.org/wiki/Principle_of_least_privilege:',
        NULL
    ),
    (
        'slides',
        'CS5200_Week11_Slides_Final.pdf',
        NULL,
        NULL
    ),
    (
        'slides',
        '00 Intro Slides 1.pdf',
        NULL,
        NULL
    ),
    (
        'repository',
        'https://github.com/cherryyypham/NEU-ML/blob/main/Lab1-01-14-25.ipynb',
        'https://github.com/cherryyypham/NEU-ML/blob/main/Lab1-01-14-25.ipynb',
        NULL
    ),
    (
        'repository',
        'https://github.com/cherryyypham/NEU-ML/blob/main/Lab2-01-14-25.ipynb',
        'https://github.com/cherryyypham/NEU-ML/blob/main/Lab2-01-14-25.ipynb',
        NULL
    ),
    (
        'repository',
        'https://github.com/cherryyypham/NEU-ML/blob/main/Lab3-01-14-25.ipynb',
        'https://github.com/cherryyypham/NEU-ML/blob/main/Lab3-01-14-25.ipynb',
        NULL
    ),
    (
        'link',
        'www.cs.cornell.edu',
        'https://www.cs.cornell.edu/courses/cs4780/2024sp/',
        NULL
    ),
    (
        'repository',
        'github.com',
        'https://github.com/cherryyypham/NEU-ML/blob/main/Lab4-01-21-25.ipynb',
        NULL
    ),
    (
        'repository',
        'github.com',
        'https://github.com/cherryyypham/NEU-ML/blob/main/Lab1-Week3.ipynb',
        NULL
    ),
    (
        'repository',
        'Lab 1',
        'https://github.com/cherryyypham/NEU-ML/blob/main/W4-Lab1.ipynb',
        NULL
    ),
    (
        'slides',
        'regression-1.pdf',
        NULL,
        NULL
    ),
    (
        'slides',
        'regression-2.pdf',
        NULL,
        NULL
    ),
    (
        'slides',
        'svm-comparison-tuning-1-notes.pdf',
        NULL,
        NULL
    ),
    (
        'slides',
        'svm-comparison-tuning-2-notes.pdf',
        NULL,
        NULL
    ),
    (
        'slides',
        'svm-comparison-tuning-3-notes.pdf',
        NULL,
        NULL
    ),
    (
        'repository',
        'demo1 on github',
        'https://github.com',
        NULL
    ),
    (
        'documentation',
        'silhouette',
        'https://scikit-learn.org/stable/auto_examples/cluster/plot_kmeans_silhouette_analysis.html',
        NULL
    ),
    (
        'link',
        'greenbuildingscareermap.org',
        'https://greenbuildingscareermap.org/',
        NULL
    ),
    (
        'video',
        'DBSCAN Video',
        'https://www.youtube.com/watch?v=RDZUdRSDOok',
        NULL
    ),
    (
        'documentation',
        'DBSCAN scikit-learn',
        'https://scikit-learn.org/stable/modules/generated/sklearn.cluster.DBSCAN.html',
        NULL
    ),
    (
        'link',
        'temporal_epoch30.pt',
        'http://temporal_epoch30.pt',
        NULL
    ),
    (
        'repository',
        'github.com',
        'https://github.com/espnet/espnet/issues/1245',
        NULL
    ),
    (
        'forum',
        'www.reddit.com',
        'https://www.reddit.com/r/learnmachinelearning/comments/vfcybn/how_much_data_is_needed_to_train_a_texttospeech/',
        NULL
    ),
    (
        'link',
        'waywithwords.net',
        'https://waywithwords.net/resource/reliable-asr-model-training-data/',
        NULL
    ),
    (
        'link',
        'huggingface.co',
        'https://huggingface.co/datasets/mythicinfinity/libritts',
        NULL
    ),
    (
        'paper',
        'arxiv.org',
        'https://arxiv.org/abs/1904.02882',
        NULL
    ),
    (
        'documentation',
        'HDBSCAN scikit-learn',
        'https://scikit-learn.org/stable/modules/generated/sklearn.cluster.HDBSCAN.html#sklearn.cluster.HDBSCAN',
        NULL
    ),
    (
        'documentation',
        'KMeans scikit-learn',
        'https://scikit-learn.org/stable/modules/generated/sklearn.cluster.KMeans.html#sklearn.cluster.KMeans',
        NULL
    ),
    (
        'link',
        'www.khanacademy.org',
        'https://www.khanacademy.org/math/linear-algebra',
        NULL
    ),
    (
        'documentation',
        'Mean-Shift Clustering GeeksforGeeks',
        'https://www.geeksforgeeks.org/machine-learning/ml-mean-shift-clustering/',
        NULL
    ),
    (
        'documentation',
        'Mean Shift scikit-learn',
        'https://scikit-learn.org/stable/modules/generated/sklearn.cluster.MeanShift.html#sklearn.cluster.MeanShift',
        NULL
    ),
    (
        'documentation',
        'MiniBatchKMeans scikit-learn',
        'https://scikit-learn.org/stable/modules/generated/sklearn.cluster.MiniBatchKMeans.html',
        NULL
    ),
    (
        'link',
        'datascience.stackexchange.com',
        'https://datascience.stackexchange.com/questions/16807/why-mini-batch-size-is-better-than-one-single-batch-with-all-training-data',
        NULL
    ),
    (
        'link',
        'fidelity',
        'https://www.emergentmind.com/topics/fidelity-alpha-precision',
        NULL
    ),
    (
        'link',
        'www.emergentmind.com',
        'https://www.emergentmind.com/topics/neural-vocoder',
        NULL
    ),
    (
        'documentation',
        'OPTICS scikit-learn',
        'https://scikit-learn.org/stable/modules/generated/sklearn.cluster.OPTICS.html#sklearn.cluster.OPTICS',
        NULL
    ),
    (
        'link',
        'huggingface.co',
        'https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2',
        NULL
    ),
    (
        'video',
        'KhanAcademy',
        'https://www.youtube.com/watch?v=vSczTbgc8Rc',
        NULL
    ),
    (
        'forum',
        'www.reddit.com',
        'https://www.reddit.com/r/LocalLLaMA/comments/1ly6cg6/kyutai_texttospeech_is_considering_opening_up/',
        NULL
    ),
    (
        'forum',
        'IndexTTS2',
        'https://www.reddit.com/r/LocalLLaMA/comments/1lyy39n/indextts2_the_most_realistic_and_expressive/',
        NULL
    ),
    (
        'forum',
        'externally',
        'https://www.reddit.com/r/LocalLLaMA/comments/1ks0arl/voice_cloning_for_kokoro_tts_using_random_walk/',
        NULL
    ),
    (
        'forum',
        'voice cloning',
        'https://www.reddit.com/search/?q=kyutai+voice+cloning&cId=9a003de2-8fde-48df-9ca9-69aa51e86688&iId=f1d8d8bf-07ed-4a70-8293-287bf881c7a8',
        NULL
    ),
    (
        'link',
        'unmute.sh',
        'http://unmute.sh/',
        NULL
    ),
    (
        'forum',
        'voice actors',
        'https://www.reddit.com/search/?q=kyutai+voice+actors&cId=1bd56646-5093-46cd-bb69-5808efdfb644&iId=0969235a-e161-4de3-b47f-f922fe5afdff',
        NULL
    ),
    (
        'paper',
        'The "What" and "Why" of Goal Pursuits: Human Needs and the Self-Determination of Behavior',
        'https://doi.org/10.1207/S15327965PLI1104_01',
        'Deci, E. L. & Ryan, R. M.'
    ),
    (
        'paper',
        'Lavigne et al 2007',
        NULL,
        'Lavigne, G. L., Vallerand, R. J. & Miquelon, P.'
    ),
    (
        'paper',
        'Leon et al 2015',
        NULL,
        'León, J., Núñez, J. L. & Liew, J.'
    ),
    (
        'paper',
        'Niemiec et al Ryan Deci 2009',
        NULL,
        'Niemiec, C. P., Ryan, R. M. & Deci, E. L.'
    ),
    (
        'paper',
        'Why Teachers Adopt a Controlling Motivating Style Toward Students and How They Can Become More Autonomy Supportive',
        'https://doi.org/10.1080/00461520903028990',
        'Reeve, J.'
    ),
    (
        'paper',
        'Self-Determination Theory and the Facilitation of Intrinsic Motivation, Social Development, and Well-Being',
        'https://doi.org/10.1037/0003-066X.55.1.68',
        'Ryan, R. M. & Deci, E. L.'
    ),
    (
        'paper',
        'Deci and Ryan''s Self-Determination Theory: A View from the Hierarchical Model of Intrinsic and Extrinsic Motivation',
        'https://doi.org/10.1207/S15327965PLI1104_03',
        'Vallerand, R. J.'
    ),
    (
        'paper',
        'Vansteenkiste et al 2005',
        NULL,
        'Vansteenkiste, M. et al.'
    ),
    (
        'paper',
        'Vansteenkiste et al 2009',
        NULL,
        'Vansteenkiste, M. et al.'
    ),
    (
        'paper',
        'Wang et al 2022',
        NULL,
        'Wang, et al.'
    ),
    (
        'paper',
        'A Review of Self-regulated Learning: Six Models and Four Directions for Research',
        'https://doi.org/10.3389/fpsyg.2017.00422',
        'Panadero, E.'
    ),
    (
        'paper',
        'Pekrun et al 2002',
        NULL,
        'Pekrun, R. et al.'
    ),
    (
        'paper',
        'Motivation and social cognitive theory',
        'https://doi.org/10.1016/j.cedpsych.2019.101832',
        'Schunk, D. H. & DiBenedetto, M. K.'
    ),
    (
        'paper',
        'Stefanou et al 2013',
        NULL,
        'Stefanou, C. et al.'
    ),
    (
        'paper',
        'Sunger and Tekkaya 2006',
        NULL,
        'Sungur, S. & Tekkaya, C.'
    ),
    (
        'paper',
        'Attribution Theory, Achievement Motivation, and the Educational Process',
        NULL,
        'Weiner, B.'
    ),
    (
        'paper',
        'Weiner 2012',
        NULL,
        'Weiner, B.'
    ),
    (
        'paper',
        'Wolters 1998',
        NULL,
        'Wolters, C. A.'
    ),
    (
        'paper',
        'Wolters 2003',
        NULL,
        'Wolters, C. A.'
    ),
    (
        'paper',
        'Becoming a Self-Regulated Learner: An Overview',
        'https://doi.org/10.1207/s15430421tip4102_2',
        'Zimmerman, B. J.'
    ),
    (
        'paper',
        'Zimmerman and Martinez Pons 1986',
        NULL,
        'Zimmerman, B. J. & Martinez-Pons, M.'
    ),
    (
        'paper',
        'Zimmerman et al 1992',
        NULL,
        'Zimmerman, B. J. et al.'
    ),
    (
        'link',
        'Stellar Cafe',
        'https://www.stellarcafe.com/',
        NULL
    ),
    (
        'repository',
        'Abes I call em',
        'https://github.com/AIndoria/volition',
        NULL
    ),
    (
        'repository',
        'unmute',
        'https://github.com/kyutai-labs/unmute',
        NULL
    ),
    (
        'repository',
        'moshi',
        'https://github.com/kyutai-labs/moshi',
        NULL
    ),
    (
        'repository',
        'MLX-audio',
        'https://github.com/Blaizzy/mlx-audio',
        NULL
    ),
    (
        'article',
        'feature selection',
        'https://blogs.sas.com/content/subconsciousmusings/2015/10/26/principal-component-analysis-for-dimensionality-reduction/',
        NULL
    ),
    (
        'paper',
        'support.sas.com',
        'https://support.sas.com/resources/papers/proceedings17/SAS0437-2017.pdf',
        NULL
    ),
    (
        'article',
        'blogs.sas.com',
        'https://blogs.sas.com/content/subconsciousmusings/2017/05/18/stacked-ensemble-models-win-data-science-competitions/',
        NULL
    ),
    (
        'link',
        'www.kaggle.com',
        'https://www.kaggle.com/',
        NULL
    ),
    (
        'link',
        'www.kdd.org',
        'http://www.kdd.org/kdd-cup',
        NULL
    );

-- date_created spans the whole life of the vault, Feb 2024 onward.
INSERT INTO
    nodes (
        vault_path,
        title,
        note_type,
        publish_status,
        vault_folder,
        identity_tag_id,
        maturity_stage_id,
        date_created,
        date_modified
    )
VALUES (
        '2026-08-14.md',
        '2026-08-14',
        'normal',
        'private',
        'zettelkasten',
        NULL,
        1,
        NULL,
        NULL
    ),
    (
        'NotakingHub/README.md',
        'README',
        'normal',
        'private',
        'inbox',
        NULL,
        NULL,
        NULL,
        NULL
    ),
    (
        'NotakingHub/indexes/Links.md',
        'Links',
        'normal',
        'private',
        'indexes',
        NULL,
        NULL,
        NULL,
        NULL
    ),
    (
        'NotakingHub/indexes/Tags.md',
        'Tags',
        'normal',
        'private',
        'indexes',
        NULL,
        NULL,
        NULL,
        NULL
    ),
    (
        'NotakingHub/indexes/Topics/Biology.md',
        'Biology',
        'topic',
        'private',
        'topics',
        4,
        1,
        TIMESTAMP '2026-05-20 08:00:00',
        TIMESTAMP '2026-06-08 15:00:00'
    ),
    (
        'NotakingHub/indexes/Topics/Chinese Literature.md',
        'Chinese Literature',
        'topic',
        'published',
        'topics',
        4,
        6,
        TIMESTAMP '2024-07-14 14:00:00',
        TIMESTAMP '2024-08-09 04:00:00'
    ),
    (
        'NotakingHub/indexes/Topics/Computer Science.md',
        'Computer Science',
        'topic',
        'published',
        'topics',
        4,
        6,
        TIMESTAMP '2025-08-09 16:00:00',
        TIMESTAMP '2025-08-11 03:00:00'
    ),
    (
        'NotakingHub/indexes/Topics/Data Science.md',
        'Data Science',
        'topic',
        'draft',
        'topics',
        4,
        5,
        TIMESTAMP '2025-02-10 12:00:00',
        TIMESTAMP '2025-02-21 22:00:00'
    ),
    (
        'NotakingHub/indexes/Topics/Literature.md',
        'Literature',
        'topic',
        'published',
        'topics',
        4,
        6,
        TIMESTAMP '2026-06-04 08:00:00',
        TIMESTAMP '2026-06-09 22:00:00'
    ),
    (
        'NotakingHub/indexes/Topics/Machine Learning.md',
        'Machine Learning',
        'topic',
        'published',
        'topics',
        4,
        6,
        TIMESTAMP '2024-08-18 13:00:00',
        TIMESTAMP '2024-09-05 20:00:00'
    ),
    (
        'NotakingHub/indexes/Topics/Mathematics.md',
        'Mathematics',
        'topic',
        'draft',
        'topics',
        4,
        5,
        TIMESTAMP '2026-01-14 15:00:00',
        TIMESTAMP '2026-01-26 23:00:00'
    ),
    (
        'NotakingHub/indexes/Topics/Motivation Theory.md',
        'Motivation Theory',
        'topic',
        'published',
        'topics',
        4,
        6,
        TIMESTAMP '2024-10-25 13:00:00',
        TIMESTAMP '2024-11-23 00:00:00'
    ),
    (
        'NotakingHub/indexes/Topics/Neuro Science.md',
        'Neuro Science',
        'topic',
        'private',
        'topics',
        4,
        1,
        TIMESTAMP '2025-08-22 14:00:00',
        TIMESTAMP '2025-09-20 08:00:00'
    ),
    (
        'NotakingHub/indexes/Topics/Pedagogy.md',
        'Pedagogy',
        'topic',
        'published',
        'topics',
        4,
        6,
        TIMESTAMP '2026-03-05 08:00:00',
        TIMESTAMP '2026-03-20 16:00:00'
    ),
    (
        'NotakingHub/indexes/Topics/Psychology.md',
        'Psychology',
        'topic',
        'published',
        'topics',
        4,
        6,
        TIMESTAMP '2024-07-08 18:00:00',
        TIMESTAMP '2024-08-03 20:00:00'
    ),
    (
        'NotakingHub/indexes/Topics/Sociology.md',
        'Sociology',
        'topic',
        'published',
        'topics',
        4,
        6,
        TIMESTAMP '2026-04-07 19:00:00',
        TIMESTAMP '2026-04-23 11:00:00'
    ),
    (
        'NotakingHub/indexes/Topics/Vietnamese Literature.md',
        'Vietnamese Literature',
        'topic',
        'published',
        'topics',
        4,
        6,
        TIMESTAMP '2024-06-14 19:00:00',
        TIMESTAMP '2024-07-12 04:00:00'
    ),
    (
        'NotakingHub/indexes/Topics/Western Literature.md',
        'Western Literature',
        'topic',
        'published',
        'topics',
        4,
        6,
        TIMESTAMP '2024-08-24 13:00:00',
        TIMESTAMP '2024-10-05 15:00:00'
    ),
    (
        'NotakingHub/templates/BasicTemplate.md',
        'BasicTemplate',
        'normal',
        'private',
        'zettelkasten',
        NULL,
        1,
        NULL,
        NULL
    ),
    (
        'NotakingHub/templates/ClassTemplate.md',
        'ClassTemplate',
        'normal',
        'private',
        'inbox',
        NULL,
        NULL,
        NULL,
        NULL
    ),
    (
        'NotakingHub/templates/TopicTemplate.md',
        'TopicTemplate',
        'normal',
        'private',
        'inbox',
        NULL,
        NULL,
        NULL,
        NULL
    ),
    (
        'NotakingHub/zettelkasten/06-04-2025.md',
        '06-04-2025',
        'normal',
        'draft',
        'zettelkasten',
        3,
        6,
        TIMESTAMP '2025-04-06 00:00:00',
        TIMESTAMP '2025-04-06 00:00:00'
    ),
    (
        'NotakingHub/zettelkasten/15-03-2025.md',
        '15-03-2025',
        'normal',
        'draft',
        'zettelkasten',
        3,
        6,
        TIMESTAMP '2025-03-15 00:00:00',
        TIMESTAMP '2025-03-15 00:00:00'
    ),
    (
        'NotakingHub/zettelkasten/2026-08-01.md',
        '2026-08-01',
        'normal',
        'private',
        'zettelkasten',
        3,
        1,
        TIMESTAMP '2026-08-01 21:00:00',
        TIMESTAMP '2026-08-14 14:00:00'
    ),
    (
        'NotakingHub/zettelkasten/29-04-2025.md',
        '29-04-2025',
        'normal',
        'draft',
        'zettelkasten',
        3,
        6,
        TIMESTAMP '2025-04-29 00:00:00',
        TIMESTAMP '2025-04-29 00:00:00'
    ),
    (
        'NotakingHub/zettelkasten/30-03-2025.md',
        '30-03-2025',
        'normal',
        'draft',
        'zettelkasten',
        3,
        6,
        TIMESTAMP '2025-03-30 00:00:00',
        TIMESTAMP '2025-03-30 00:00:00'
    ),
    (
        'NotakingHub/zettelkasten/ADHD.md',
        'ADHD',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2026-03-14 16:48:00',
        TIMESTAMP '2026-04-07 02:48:00'
    ),
    (
        'NotakingHub/zettelkasten/AI Best Practices.md',
        'AI Best Practices',
        'normal',
        'private',
        'zettelkasten',
        2,
        3,
        TIMESTAMP '2024-08-27 09:00:00',
        TIMESTAMP '2024-09-10 02:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Achievement Goal Theory.md',
        'Achievement Goal Theory',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2025-12-13 13:47:23',
        TIMESTAMP '2026-01-10 23:47:23'
    ),
    (
        'NotakingHub/zettelkasten/Affinity Propagation.md',
        'Affinity Propagation',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2026-02-15 15:18:00',
        TIMESTAMP '2026-03-30 23:18:00'
    ),
    (
        'NotakingHub/zettelkasten/Agglomerative Clustering.md',
        'Agglomerative Clustering',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2026-02-15 15:22:00',
        TIMESTAMP '2026-03-16 15:22:00'
    ),
    (
        'NotakingHub/zettelkasten/Analects.md',
        'Analects',
        'normal',
        'private',
        'zettelkasten',
        2,
        3,
        TIMESTAMP '2026-06-13 06:10:21',
        TIMESTAMP '2026-06-27 02:10:21'
    ),
    (
        'NotakingHub/zettelkasten/Anomie.md',
        'Anomie',
        'normal',
        'private',
        'zettelkasten',
        2,
        3,
        TIMESTAMP '2026-02-26 15:19:51',
        TIMESTAMP '2026-03-02 01:19:51'
    ),
    (
        'NotakingHub/zettelkasten/Anthropic.md',
        'Anthropic',
        'normal',
        'draft',
        'zettelkasten',
        2,
        5,
        TIMESTAMP '2025-08-06 17:00:00',
        TIMESTAMP '2025-08-24 03:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Apriori.md',
        'Apriori',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2025-06-23 08:00:00',
        TIMESTAMP '2025-07-04 15:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Arrivederci.md',
        'Arrivederci',
        'normal',
        'draft',
        'zettelkasten',
        3,
        6,
        TIMESTAMP '2024-05-13 00:00:00',
        TIMESTAMP '2024-05-13 00:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Attachment Theory.md',
        'Attachment Theory',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2026-05-05 07:52:39',
        TIMESTAMP '2026-05-28 03:52:39'
    ),
    (
        'NotakingHub/zettelkasten/BIRCH.md',
        'BIRCH',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2026-02-15 15:18:00',
        TIMESTAMP '2026-03-24 19:18:00'
    ),
    (
        'NotakingHub/zettelkasten/Balcony with the night breeze.md',
        'Balcony with the night breeze',
        'normal',
        'draft',
        'zettelkasten',
        3,
        6,
        TIMESTAMP '2024-03-13 00:00:00',
        TIMESTAMP '2024-03-13 00:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Basic Psychological Needs Theory.md',
        'Basic Psychological Needs Theory',
        'normal',
        'draft',
        'zettelkasten',
        2,
        5,
        TIMESTAMP '2026-07-02 11:00:00',
        TIMESTAMP '2026-07-08 22:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Bayes'' Factor.md',
        'Bayes'' Factor',
        'normal',
        'private',
        'zettelkasten',
        2,
        3,
        TIMESTAMP '2026-01-29 15:53:00',
        TIMESTAMP '2026-03-07 22:53:00'
    ),
    (
        'NotakingHub/zettelkasten/Bayes.md',
        'Bayes',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2025-04-09 16:00:00',
        TIMESTAMP '2025-04-30 17:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Bayesian Statistic.md',
        'Bayesian Statistic',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2026-02-15 15:18:00',
        TIMESTAMP '2026-02-18 10:18:00'
    ),
    (
        'NotakingHub/zettelkasten/Behaviorism.md',
        'Behaviorism',
        'normal',
        'published',
        'zettelkasten',
        2,
        6,
        TIMESTAMP '2026-06-14 15:45:00',
        TIMESTAMP '2026-06-25 16:45:00'
    ),
    (
        'NotakingHub/zettelkasten/Bình Ngô Đại Cáo.md',
        'Bình Ngô Đại Cáo',
        'normal',
        'draft',
        'zettelkasten',
        2,
        5,
        TIMESTAMP '2026-08-04 23:25:35',
        TIMESTAMP '2026-08-11 16:25:35'
    ),
    (
        'NotakingHub/zettelkasten/Book of Songs.md',
        'Book of Songs',
        'normal',
        'published',
        'zettelkasten',
        2,
        6,
        TIMESTAMP '2026-01-05 16:20:13',
        TIMESTAMP '2026-01-30 17:20:13'
    ),
    (
        'NotakingHub/zettelkasten/CMD.md',
        'CMD',
        'normal',
        'private',
        'zettelkasten',
        2,
        3,
        TIMESTAMP '2024-12-17 13:00:00',
        TIMESTAMP '2024-12-22 03:00:00'
    ),
    (
        'NotakingHub/zettelkasten/COURSES/Bioinformatics Interest Group Running Notes.md',
        'Bioinformatics Interest Group Running Notes',
        'normal',
        'published',
        'courses',
        1,
        6,
        TIMESTAMP '2026-02-26 12:37:00',
        TIMESTAMP '2026-03-18 14:37:00'
    ),
    (
        'NotakingHub/zettelkasten/COURSES/CS 5200-DatabaseManagementSystems/05-12-26-Class1-Intro.md',
        '05-12-26-Class1-Intro',
        'normal',
        'private',
        'courses',
        1,
        1,
        TIMESTAMP '2026-05-12 18:15:00',
        TIMESTAMP '2026-06-16 13:15:00'
    ),
    (
        'NotakingHub/zettelkasten/COURSES/CS 5200-DatabaseManagementSystems/05-19-26-Class2-ERModelingandConceptualDesign.md',
        '05-19-26-Class2-ERModelingandConceptualDesign',
        'normal',
        'private',
        'courses',
        1,
        1,
        TIMESTAMP '2026-05-19 18:28:00',
        TIMESTAMP '2026-06-28 08:28:00'
    ),
    (
        'NotakingHub/zettelkasten/COURSES/CS 5200-DatabaseManagementSystems/05-26-26-Class3-TheRelationalModel,Keys,andConstraints.md',
        '05-26-26-Class3-TheRelationalModel,Keys,andConstraints',
        'normal',
        'private',
        'courses',
        1,
        1,
        TIMESTAMP '2026-05-26 18:00:00',
        TIMESTAMP '2026-06-29 03:00:00'
    ),
    (
        'NotakingHub/zettelkasten/COURSES/CS 5200-DatabaseManagementSystems/06-02-26-Class4-SQLFundamentalsI-DML.md',
        '06-02-26-Class4-SQLFundamentalsI-DML',
        'normal',
        'private',
        'courses',
        1,
        1,
        TIMESTAMP '2026-06-02 18:00:00',
        TIMESTAMP '2026-07-03 06:00:00'
    ),
    (
        'NotakingHub/zettelkasten/COURSES/CS 5200-DatabaseManagementSystems/06-09-26-Class5-JoinsCTEsWindow Functions.md',
        '06-09-26-Class5-JoinsCTEsWindow Functions',
        'normal',
        'private',
        'courses',
        1,
        1,
        TIMESTAMP '2026-06-09 18:00:00',
        TIMESTAMP '2026-07-17 23:00:00'
    ),
    (
        'NotakingHub/zettelkasten/COURSES/CS 5200-DatabaseManagementSystems/06-16-26-Class6-Normalization.md',
        '06-16-26-Class6-Normalization',
        'normal',
        'private',
        'courses',
        1,
        1,
        TIMESTAMP '2026-06-16 18:00:00',
        TIMESTAMP '2026-07-12 12:00:00'
    ),
    (
        'NotakingHub/zettelkasten/COURSES/CS 5200-DatabaseManagementSystems/06-23-26-Class7-ConsolidationAndRelationalAlgebra.md',
        '06-23-26-Class7-ConsolidationAndRelationalAlgebra',
        'normal',
        'private',
        'courses',
        1,
        1,
        TIMESTAMP '2026-06-23 18:00:00',
        TIMESTAMP '2026-06-26 00:00:00'
    ),
    (
        'NotakingHub/zettelkasten/COURSES/CS 5200-DatabaseManagementSystems/06-30-26-Class8-FunctionsTriggersAndServerSideLogic.md',
        '06-30-26-Class8-FunctionsTriggersAndServerSideLogic',
        'normal',
        'private',
        'courses',
        1,
        1,
        TIMESTAMP '2026-06-30 18:00:00',
        TIMESTAMP '2026-07-22 18:00:00'
    ),
    (
        'NotakingHub/zettelkasten/COURSES/CS 5200-DatabaseManagementSystems/07-07-26-Class9-TransactionsACIDAndConcurrency.md',
        '07-07-26-Class9-TransactionsACIDAndConcurrency',
        'normal',
        'private',
        'courses',
        1,
        1,
        TIMESTAMP '2026-07-07 18:00:00',
        TIMESTAMP '2026-07-25 00:00:00'
    ),
    (
        'NotakingHub/zettelkasten/COURSES/CS 5200-DatabaseManagementSystems/07-14-26-Class10-IndexesBTreesAndQueryPerformance.md',
        '07-14-26-Class10-IndexesBTreesAndQueryPerformance',
        'normal',
        'private',
        'courses',
        1,
        1,
        TIMESTAMP '2026-07-14 18:00:00',
        TIMESTAMP '2026-07-19 08:00:00'
    ),
    (
        'NotakingHub/zettelkasten/COURSES/CS 5200-DatabaseManagementSystems/07-21-26-Class11-IndexesBTreesAndQueryPerformance.md',
        '07-21-26-Class11-IndexesBTreesAndQueryPerformance',
        'normal',
        'private',
        'courses',
        1,
        1,
        TIMESTAMP '2026-07-21 18:00:00',
        TIMESTAMP '2026-08-14 19:00:00'
    ),
    (
        'NotakingHub/zettelkasten/COURSES/CS6140-MachineLearning/01-07-26-Class1-Intro.md',
        '01-07-26-Class1-Intro',
        'normal',
        'private',
        'courses',
        1,
        1,
        TIMESTAMP '2026-01-07 18:30:00',
        TIMESTAMP '2026-01-15 08:30:00'
    ),
    (
        'NotakingHub/zettelkasten/COURSES/CS6140-MachineLearning/01-14-26-Class2-QEA1.md',
        '01-14-26-Class2-QEA1',
        'normal',
        'published',
        'courses',
        1,
        6,
        TIMESTAMP '2026-01-14 18:30:00',
        TIMESTAMP '2026-02-12 00:30:00'
    ),
    (
        'NotakingHub/zettelkasten/COURSES/CS6140-MachineLearning/01-21-26-Class3-MatrixCalculus-Probability.md',
        '01-21-26-Class3-MatrixCalculus-Probability',
        'normal',
        'published',
        'courses',
        1,
        6,
        TIMESTAMP '2026-01-21 18:30:00',
        TIMESTAMP '2026-02-01 23:30:00'
    ),
    (
        'NotakingHub/zettelkasten/COURSES/CS6140-MachineLearning/01-28-26-Class4-Regression.md',
        '01-28-26-Class4-Regression',
        'normal',
        'draft',
        'courses',
        1,
        5,
        TIMESTAMP '2026-01-28 18:30:00',
        TIMESTAMP '2026-03-08 04:30:00'
    ),
    (
        'NotakingHub/zettelkasten/COURSES/CS6140-MachineLearning/02-04-26-Class5.md',
        '02-04-26-Class5',
        'normal',
        'private',
        'courses',
        1,
        3,
        TIMESTAMP '2026-02-04 18:30:00',
        TIMESTAMP '2026-03-01 11:30:00'
    ),
    (
        'NotakingHub/zettelkasten/COURSES/CS6140-MachineLearning/02-11-26-Class7-SVMs-ModelComparison-ModelTuning.md',
        '02-11-26-Class7-SVMs-ModelComparison-ModelTuning',
        'normal',
        'draft',
        'courses',
        1,
        5,
        TIMESTAMP '2026-02-11 18:30:00',
        TIMESTAMP '2026-03-13 18:30:00'
    ),
    (
        'NotakingHub/zettelkasten/COURSES/CS6140-MachineLearning/03-11-26-Class9-Trees.md',
        '03-11-26-Class9-Trees',
        'normal',
        'private',
        'courses',
        1,
        1,
        TIMESTAMP '2026-03-11 18:11:00',
        TIMESTAMP '2026-03-17 11:11:00'
    ),
    (
        'NotakingHub/zettelkasten/COURSES/DS5230-UnsupervisedML/01-15-26-Class2-Aptitude-Test.md',
        '01-15-26-Class2-Aptitude-Test',
        'normal',
        'published',
        'courses',
        1,
        6,
        TIMESTAMP '2026-01-15 18:30:00',
        TIMESTAMP '2026-02-27 01:30:00'
    ),
    (
        'NotakingHub/zettelkasten/COURSES/DS5230-UnsupervisedML/01-22-26-Class3-K-Means.md',
        '01-22-26-Class3-K-Means',
        'normal',
        'private',
        'courses',
        1,
        3,
        TIMESTAMP '2026-01-22 18:30:00',
        TIMESTAMP '2026-01-24 19:30:00'
    ),
    (
        'NotakingHub/zettelkasten/COURSES/DS5230-UnsupervisedML/02-05-26-Class5-Accuracy-DecisionTree.md',
        '02-05-26-Class5-Accuracy-DecisionTree',
        'normal',
        'published',
        'courses',
        1,
        6,
        TIMESTAMP '2026-02-05 18:30:00',
        TIMESTAMP '2026-03-10 13:30:00'
    ),
    (
        'NotakingHub/zettelkasten/COURSES/DS5230-UnsupervisedML/02-12-26-Class6-Apriori.md',
        '02-12-26-Class6-Apriori',
        'normal',
        'published',
        'courses',
        1,
        6,
        TIMESTAMP '2026-02-12 18:30:00',
        TIMESTAMP '2026-03-20 04:30:00'
    ),
    (
        'NotakingHub/zettelkasten/COURSES/DS5230-UnsupervisedML/02-19-26-Class7-TextMining.md',
        '02-19-26-Class7-TextMining',
        'normal',
        'private',
        'courses',
        1,
        1,
        TIMESTAMP '2026-02-19 18:00:00',
        TIMESTAMP '2026-03-23 05:00:00'
    ),
    (
        'NotakingHub/zettelkasten/COURSES/DS5230-UnsupervisedML/02-26-26-Class8-NetworkAnalysis.md',
        '02-26-26-Class8-NetworkAnalysis',
        'normal',
        'private',
        'courses',
        1,
        1,
        TIMESTAMP '2026-02-19 18:00:00',
        TIMESTAMP '2026-03-06 05:00:00'
    ),
    (
        'NotakingHub/zettelkasten/COURSES/DS5230-UnsupervisedML/03-12-26-Class9-MultivariateStatistics-PCA.md',
        '03-12-26-Class9-MultivariateStatistics-PCA',
        'normal',
        'private',
        'courses',
        1,
        1,
        TIMESTAMP '2026-02-19 18:00:00',
        TIMESTAMP '2026-03-14 12:00:00'
    ),
    (
        'NotakingHub/zettelkasten/COURSES/DS5230-UnsupervisedML/03-26-26-Class10-GeneticAlgorithm.md',
        '03-26-26-Class10-GeneticAlgorithm',
        'normal',
        'private',
        'courses',
        1,
        3,
        TIMESTAMP '2026-03-26 18:00:00',
        TIMESTAMP '2026-05-04 02:00:00'
    ),
    (
        'NotakingHub/zettelkasten/COURSES/DS5230-UnsupervisedML/04-09-26-Class11-DimensionReduction.md',
        '04-09-26-Class11-DimensionReduction',
        'normal',
        'private',
        'courses',
        1,
        1,
        TIMESTAMP '2026-04-09 18:16:00',
        TIMESTAMP '2026-05-07 09:16:00'
    ),
    (
        'NotakingHub/zettelkasten/Ca Dao.md',
        'Ca Dao',
        'normal',
        'private',
        'zettelkasten',
        2,
        3,
        TIMESTAMP '2026-08-10 01:07:39',
        TIMESTAMP '2026-08-11 08:07:39'
    ),
    (
        'NotakingHub/zettelkasten/Calculus.md',
        'Calculus',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2026-03-25 15:00:00',
        TIMESTAMP '2026-04-03 23:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Căn phòng cũ.md',
        'Căn phòng cũ',
        'normal',
        'draft',
        'zettelkasten',
        3,
        6,
        TIMESTAMP '2024-02-11 00:00:00',
        TIMESTAMP '2024-02-11 00:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Cảm ơn và Xin Lỗi.md',
        'Cảm ơn và Xin Lỗi',
        'normal',
        'draft',
        'zettelkasten',
        3,
        6,
        TIMESTAMP '2025-04-09 00:00:00',
        TIMESTAMP '2025-04-09 00:00:00'
    ),
    (
        'NotakingHub/zettelkasten/ChatGPT.md',
        'ChatGPT',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2025-01-08 20:00:00',
        TIMESTAMP '2025-01-31 15:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Chí Phèo.md',
        'Chí Phèo',
        'normal',
        'draft',
        'zettelkasten',
        2,
        5,
        TIMESTAMP '2026-08-02 12:20:51',
        TIMESTAMP '2026-08-09 23:20:51'
    ),
    (
        'NotakingHub/zettelkasten/Ciao ciao Finalizing this chapter, finally.md',
        'Ciao ciao Finalizing this chapter, finally',
        'normal',
        'draft',
        'zettelkasten',
        3,
        6,
        TIMESTAMP '2024-05-19 00:00:00',
        TIMESTAMP '2024-05-19 00:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Claude.md',
        'Claude',
        'normal',
        'private',
        'zettelkasten',
        2,
        3,
        TIMESTAMP '2026-04-14 11:00:00',
        TIMESTAMP '2026-05-19 02:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Clustering.md',
        'Clustering',
        'topic',
        'private',
        'zettelkasten',
        2,
        3,
        TIMESTAMP '2026-02-13 17:35:00',
        TIMESTAMP '2026-03-14 18:35:00'
    ),
    (
        'NotakingHub/zettelkasten/Cognitive Dissonance.md',
        'Cognitive Dissonance',
        'normal',
        'private',
        'zettelkasten',
        2,
        3,
        TIMESTAMP '2026-06-13 09:00:00',
        TIMESTAMP '2026-06-14 21:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Cognitive Load Theory.md',
        'Cognitive Load Theory',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2026-06-10 11:00:00',
        TIMESTAMP '2026-06-17 23:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Comparative Literature.md',
        'Comparative Literature',
        'normal',
        'draft',
        'zettelkasten',
        2,
        5,
        TIMESTAMP '2026-06-26 06:10:52',
        TIMESTAMP '2026-07-21 10:10:52'
    ),
    (
        'NotakingHub/zettelkasten/Comparison of Linear Regression with K-Nearest Neighbors.md',
        'Comparison of Linear Regression with K-Nearest Neighbors',
        'normal',
        'draft',
        'zettelkasten',
        2,
        5,
        TIMESTAMP '2026-02-03 16:46:00',
        TIMESTAMP '2026-03-07 21:46:00'
    ),
    (
        'NotakingHub/zettelkasten/Consolidation and Relational Algebra.md',
        'Consolidation and Relational Algebra',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2024-07-16 18:00:00',
        TIMESTAMP '2024-07-21 07:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Crime and Punishment.md',
        'Crime and Punishment',
        'normal',
        'published',
        'zettelkasten',
        2,
        6,
        TIMESTAMP '2026-05-26 14:00:41',
        TIMESTAMP '2026-05-27 22:00:41'
    ),
    (
        'NotakingHub/zettelkasten/Cross-Validation.md',
        'Cross-Validation',
        'normal',
        'published',
        'zettelkasten',
        2,
        6,
        TIMESTAMP '2026-06-03 09:40:00',
        TIMESTAMP '2026-06-05 09:40:00'
    ),
    (
        'NotakingHub/zettelkasten/Cultural Capital.md',
        'Cultural Capital',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2025-12-09 13:03:12',
        TIMESTAMP '2025-12-29 06:03:12'
    ),
    (
        'NotakingHub/zettelkasten/Culturally Responsive Pedagogy.md',
        'Culturally Responsive Pedagogy',
        'normal',
        'draft',
        'zettelkasten',
        2,
        5,
        TIMESTAMP '2026-07-20 10:40:00',
        TIMESTAMP '2026-07-23 13:40:00'
    ),
    (
        'NotakingHub/zettelkasten/DBSCAN.md',
        'DBSCAN',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2026-02-15 15:18:00',
        TIMESTAMP '2026-02-18 15:18:00'
    ),
    (
        'NotakingHub/zettelkasten/Dante''s Divine Comedy.md',
        'Dante''s Divine Comedy',
        'normal',
        'published',
        'zettelkasten',
        2,
        6,
        TIMESTAMP '2025-12-05 20:00:39',
        TIMESTAMP '2025-12-27 23:00:39'
    ),
    (
        'NotakingHub/zettelkasten/Don Quixote.md',
        'Don Quixote',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2026-03-25 08:37:10',
        TIMESTAMP '2026-04-08 13:37:10'
    ),
    (
        'NotakingHub/zettelkasten/Dream of the Red Chamber.md',
        'Dream of the Red Chamber',
        'normal',
        'draft',
        'zettelkasten',
        2,
        5,
        TIMESTAMP '2026-07-05 16:08:52',
        TIMESTAMP '2026-07-14 02:08:52'
    ),
    (
        'NotakingHub/zettelkasten/Du Fu.md',
        'Du Fu',
        'normal',
        'draft',
        'zettelkasten',
        2,
        5,
        TIMESTAMP '2026-01-24 14:26:56',
        TIMESTAMP '2026-02-02 07:26:56'
    ),
    (
        'NotakingHub/zettelkasten/ENCOM/Compute Optimization.md',
        'Compute Optimization',
        'normal',
        'draft',
        'zettelkasten',
        2,
        5,
        TIMESTAMP '2026-05-16 14:00:00',
        TIMESTAMP '2026-05-29 14:00:00'
    ),
    (
        'NotakingHub/zettelkasten/ENCOM/Training Dataset.md',
        'Training Dataset',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2026-04-05 16:49:00',
        TIMESTAMP '2026-05-03 23:49:00'
    ),
    (
        'NotakingHub/zettelkasten/Elkan''s Algorithm.md',
        'Elkan''s Algorithm',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2026-02-22 19:17:00',
        TIMESTAMP '2026-04-04 08:17:00'
    ),
    (
        'NotakingHub/zettelkasten/Epic Poetry.md',
        'Epic Poetry',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2026-07-02 21:32:27',
        TIMESTAMP '2026-07-09 05:32:27'
    ),
    (
        'NotakingHub/zettelkasten/Equity in Learning.md',
        'Equity in Learning',
        'normal',
        'private',
        'zettelkasten',
        2,
        3,
        TIMESTAMP '2026-07-16 11:30:00',
        TIMESTAMP '2026-08-03 12:30:00'
    ),
    (
        'NotakingHub/zettelkasten/Ethical Guidelines.md',
        'Ethical Guidelines',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2024-09-08 11:00:00',
        TIMESTAMP '2024-09-15 05:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Expectancy-Value Theory.md',
        'Expectancy-Value Theory',
        'normal',
        'private',
        'zettelkasten',
        2,
        3,
        TIMESTAMP '2026-07-04 14:40:00',
        TIMESTAMP '2026-07-18 19:40:00'
    ),
    (
        'NotakingHub/zettelkasten/Family and the Achievement of Happiness.md',
        'Family and the Achievement of Happiness',
        'normal',
        'draft',
        'zettelkasten',
        3,
        6,
        TIMESTAMP '2024-06-21 00:00:00',
        TIMESTAMP '2024-06-21 00:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Feelings of self-improvement p.2.md',
        'Feelings of self-improvement p.2',
        'normal',
        'draft',
        'zettelkasten',
        3,
        6,
        TIMESTAMP '2024-03-27 00:00:00',
        TIMESTAMP '2024-03-27 00:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Feelings of self-improvement.md',
        'Feelings of self-improvement',
        'normal',
        'draft',
        'zettelkasten',
        3,
        6,
        TIMESTAMP '2024-03-06 00:00:00',
        TIMESTAMP '2024-03-06 00:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Flow Theory.md',
        'Flow Theory',
        'normal',
        'draft',
        'zettelkasten',
        2,
        5,
        TIMESTAMP '2026-07-06 16:00:00',
        TIMESTAMP '2026-07-30 00:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Four Great Classical Novels.md',
        'Four Great Classical Novels',
        'normal',
        'draft',
        'zettelkasten',
        2,
        5,
        TIMESTAMP '2025-12-27 01:55:21',
        TIMESTAMP '2026-01-03 19:55:21'
    ),
    (
        'NotakingHub/zettelkasten/French Symbolism.md',
        'French Symbolism',
        'normal',
        'draft',
        'zettelkasten',
        2,
        5,
        TIMESTAMP '2026-01-29 17:33:54',
        TIMESTAMP '2026-02-10 22:33:54'
    ),
    (
        'NotakingHub/zettelkasten/GMM.md',
        'GMM',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2026-02-15 15:18:00',
        TIMESTAMP '2026-03-15 16:18:00'
    ),
    (
        'NotakingHub/zettelkasten/Game-Based Learning.md',
        'Game-Based Learning',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2026-07-15 10:00:00',
        TIMESTAMP '2026-08-08 11:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Goal Setting Theory.md',
        'Goal Setting Theory',
        'normal',
        'published',
        'zettelkasten',
        2,
        6,
        TIMESTAMP '2026-07-05 10:20:00',
        TIMESTAMP '2026-07-20 19:20:00'
    ),
    (
        'NotakingHub/zettelkasten/Goethe''s Faust.md',
        'Goethe''s Faust',
        'normal',
        'private',
        'zettelkasten',
        2,
        3,
        TIMESTAMP '2026-06-28 20:22:36',
        TIMESTAMP '2026-07-24 12:22:36'
    ),
    (
        'NotakingHub/zettelkasten/Google.md',
        'Google',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2024-08-05 18:00:00',
        TIMESTAMP '2024-08-16 01:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Gradient Descent.md',
        'Gradient Descent',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2026-02-23 15:22:00',
        TIMESTAMP '2026-03-31 22:22:00'
    ),
    (
        'NotakingHub/zettelkasten/Greek Tragedy.md',
        'Greek Tragedy',
        'normal',
        'private',
        'zettelkasten',
        2,
        3,
        TIMESTAMP '2026-04-28 13:56:58',
        TIMESTAMP '2026-05-19 03:56:58'
    ),
    (
        'NotakingHub/zettelkasten/Growth Mindset.md',
        'Growth Mindset',
        'normal',
        'draft',
        'zettelkasten',
        2,
        5,
        TIMESTAMP '2026-06-11 16:20:00',
        TIMESTAMP '2026-07-02 17:20:00'
    ),
    (
        'NotakingHub/zettelkasten/HDBSCAN.md',
        'HDBSCAN',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2026-02-15 15:18:00',
        TIMESTAMP '2026-03-10 03:18:00'
    ),
    (
        'NotakingHub/zettelkasten/Habitus.md',
        'Habitus',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2026-06-21 11:15:00',
        TIMESTAMP '2026-06-30 14:15:00'
    ),
    (
        'NotakingHub/zettelkasten/Hamlet.md',
        'Hamlet',
        'normal',
        'draft',
        'zettelkasten',
        2,
        5,
        TIMESTAMP '2026-06-27 21:55:34',
        TIMESTAMP '2026-07-23 05:55:34'
    ),
    (
        'NotakingHub/zettelkasten/Health Science.md',
        'Health Science',
        'normal',
        'private',
        'zettelkasten',
        NULL,
        NULL,
        NULL,
        NULL
    ),
    (
        'NotakingHub/zettelkasten/How has half the summer passed already.md',
        'How has half the summer passed already',
        'normal',
        'draft',
        'zettelkasten',
        3,
        6,
        TIMESTAMP '2024-06-23 00:00:00',
        TIMESTAMP '2024-06-23 00:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Hôm nay đã làm những gì.md',
        'Hôm nay đã làm những gì',
        'normal',
        'draft',
        'zettelkasten',
        3,
        6,
        TIMESTAMP '2024-02-28 00:00:00',
        TIMESTAMP '2024-02-28 00:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Hồ Xuân Hương.md',
        'Hồ Xuân Hương',
        'normal',
        'private',
        'zettelkasten',
        2,
        3,
        TIMESTAMP '2026-06-27 15:00:29',
        TIMESTAMP '2026-07-02 03:00:29'
    ),
    (
        'NotakingHub/zettelkasten/Hugging Face.md',
        'Hugging Face',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2024-10-11 14:00:00',
        TIMESTAMP '2024-11-24 04:00:00'
    ),
    (
        'NotakingHub/zettelkasten/I''m dying of thirst.md',
        'I''m dying of thirst',
        'normal',
        'draft',
        'zettelkasten',
        3,
        6,
        TIMESTAMP '2024-04-28 00:00:00',
        TIMESTAMP '2024-04-28 00:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Intrinsic vs Extrinsic Motivation.md',
        'Intrinsic vs Extrinsic Motivation',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2026-07-03 09:30:00',
        TIMESTAMP '2026-07-26 19:30:00'
    ),
    (
        'NotakingHub/zettelkasten/Journey to the West.md',
        'Journey to the West',
        'normal',
        'published',
        'zettelkasten',
        2,
        6,
        TIMESTAMP '2026-04-27 17:46:51',
        TIMESTAMP '2026-05-07 13:46:51'
    ),
    (
        'NotakingHub/zettelkasten/K-Means Clustering.md',
        'K-Means Clustering',
        'normal',
        'published',
        'zettelkasten',
        2,
        6,
        TIMESTAMP '2026-05-14 16:55:53',
        TIMESTAMP '2026-05-22 09:55:53'
    ),
    (
        'NotakingHub/zettelkasten/K-Means++.md',
        'K-Means++',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2026-02-23 14:23:00',
        TIMESTAMP '2026-02-27 16:23:00'
    ),
    (
        'NotakingHub/zettelkasten/K-Means.md',
        'K-Means',
        'normal',
        'private',
        'zettelkasten',
        2,
        3,
        TIMESTAMP '2026-02-15 14:23:00',
        TIMESTAMP '2026-03-17 20:23:00'
    ),
    (
        'NotakingHub/zettelkasten/K-Medoids (PAM).md',
        'K-Medoids (PAM)',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2026-02-15 15:18:00',
        TIMESTAMP '2026-03-09 07:18:00'
    ),
    (
        'NotakingHub/zettelkasten/K-Nearest Neighbors.md',
        'K-Nearest Neighbors',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2026-02-15 15:18:00',
        TIMESTAMP '2026-02-25 02:18:00'
    ),
    (
        'NotakingHub/zettelkasten/Kaggle.md',
        'Kaggle',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2025-06-08 16:00:00',
        TIMESTAMP '2025-06-26 19:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Kickstart.md',
        'Kickstart',
        'normal',
        'draft',
        'zettelkasten',
        3,
        6,
        TIMESTAMP '2024-06-10 00:00:00',
        TIMESTAMP '2024-06-10 00:00:00'
    ),
    (
        'NotakingHub/zettelkasten/LLM.md',
        'LLM',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2025-09-13 16:00:00',
        TIMESTAMP '2025-09-29 18:00:00'
    ),
    (
        'NotakingHub/zettelkasten/LSTM.md',
        'LSTM',
        'normal',
        'private',
        'zettelkasten',
        NULL,
        NULL,
        NULL,
        NULL
    ),
    (
        'NotakingHub/zettelkasten/Les Misérables.md',
        'Les Misérables',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2026-08-01 05:13:12',
        TIMESTAMP '2026-08-10 01:13:12'
    ),
    (
        'NotakingHub/zettelkasten/Li Bai.md',
        'Li Bai',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2026-05-28 13:48:33',
        TIMESTAMP '2026-06-02 21:48:33'
    ),
    (
        'NotakingHub/zettelkasten/Linear Algebra.md',
        'Linear Algebra',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2026-02-15 15:18:00',
        TIMESTAMP '2026-03-15 19:18:00'
    ),
    (
        'NotakingHub/zettelkasten/Linear Regression.md',
        'Linear Regression',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2024-10-01 12:00:00',
        TIMESTAMP '2024-11-08 17:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Literary Devices.md',
        'Literary Devices',
        'normal',
        'published',
        'zettelkasten',
        2,
        6,
        TIMESTAMP '2026-06-08 02:45:33',
        TIMESTAMP '2026-07-05 04:45:33'
    ),
    (
        'NotakingHub/zettelkasten/Literature/TAM QUỐC DIỄN NGHĨA.md',
        'TAM QUỐC DIỄN NGHĨA',
        'normal',
        'published',
        'zettelkasten',
        2,
        6,
        TIMESTAMP '2026-06-30 08:00:00',
        TIMESTAMP '2026-08-09 22:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Literature/Thiên Quan Tứ Phúc.md',
        'Thiên Quan Tứ Phúc',
        'normal',
        'draft',
        'zettelkasten',
        2,
        5,
        TIMESTAMP '2025-06-08 16:00:00',
        TIMESTAMP '2025-06-18 18:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Literature/Văn học cổ truyền Trung Quốc.md',
        'Văn học cổ truyền Trung Quốc',
        'normal',
        'published',
        'zettelkasten',
        2,
        6,
        TIMESTAMP '2026-01-07 09:00:00',
        TIMESTAMP '2026-01-22 14:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Lloyd''s Algorithm.md',
        'Lloyd''s Algorithm',
        'normal',
        'draft',
        'zettelkasten',
        2,
        5,
        TIMESTAMP '2026-02-22 19:16:00',
        TIMESTAMP '2026-03-17 21:16:00'
    ),
    (
        'NotakingHub/zettelkasten/Lu Xun.md',
        'Lu Xun',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2026-05-05 11:40:57',
        TIMESTAMP '2026-05-17 18:40:57'
    ),
    (
        'NotakingHub/zettelkasten/Macbeth.md',
        'Macbeth',
        'normal',
        'private',
        'zettelkasten',
        2,
        3,
        TIMESTAMP '2026-08-07 07:11:49',
        TIMESTAMP '2026-08-11 10:11:49'
    ),
    (
        'NotakingHub/zettelkasten/Madame Bovary.md',
        'Madame Bovary',
        'normal',
        'published',
        'zettelkasten',
        2,
        6,
        TIMESTAMP '2026-06-16 12:45:39',
        TIMESTAMP '2026-07-06 18:45:39'
    ),
    (
        'NotakingHub/zettelkasten/Magical Realism.md',
        'Magical Realism',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2026-07-09 17:08:59',
        TIMESTAMP '2026-07-12 19:08:59'
    ),
    (
        'NotakingHub/zettelkasten/Mastery Learning.md',
        'Mastery Learning',
        'normal',
        'published',
        'zettelkasten',
        2,
        6,
        TIMESTAMP '2025-12-04 04:01:24',
        TIMESTAMP '2025-12-08 00:01:24'
    ),
    (
        'NotakingHub/zettelkasten/MasteryCalculation.md',
        'MasteryCalculation',
        'normal',
        'draft',
        'zettelkasten',
        2,
        5,
        TIMESTAMP '2025-01-29 17:00:00',
        TIMESTAMP '2025-02-03 09:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Matrix Multiplication.md',
        'Matrix Multiplication',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2025-11-15 19:00:00',
        TIMESTAMP '2025-12-27 09:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Matrix.md',
        'Matrix',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2026-04-13 09:00:00',
        TIMESTAMP '2026-05-26 19:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Mean Shift.md',
        'Mean Shift',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2026-02-15 15:18:00',
        TIMESTAMP '2026-03-07 19:18:00'
    ),
    (
        'NotakingHub/zettelkasten/Mentor Check-in with Nick.md',
        'Mentor Check-in with Nick',
        'normal',
        'draft',
        'zettelkasten',
        3,
        6,
        TIMESTAMP '2024-06-21 09:00:00',
        TIMESTAMP '2024-07-03 15:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Mini-Batch K-Means.md',
        'Mini-Batch K-Means',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2026-02-22 19:18:00',
        TIMESTAMP '2026-03-20 05:18:00'
    ),
    (
        'NotakingHub/zettelkasten/Modernism.md',
        'Modernism',
        'normal',
        'published',
        'zettelkasten',
        2,
        6,
        TIMESTAMP '2026-06-09 03:08:07',
        TIMESTAMP '2026-06-10 06:08:07'
    ),
    (
        'NotakingHub/zettelkasten/Nam Cao.md',
        'Nam Cao',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2025-12-31 23:28:15',
        TIMESTAMP '2026-01-19 08:28:15'
    ),
    (
        'NotakingHub/zettelkasten/Neural Vocoder.md',
        'Neural Vocoder',
        'normal',
        'published',
        'zettelkasten',
        2,
        6,
        TIMESTAMP '2025-09-03 12:00:00',
        TIMESTAMP '2025-09-24 13:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Nguyễn Du.md',
        'Nguyễn Du',
        'normal',
        'draft',
        'zettelkasten',
        2,
        5,
        TIMESTAMP '2025-12-18 05:59:14',
        TIMESTAMP '2026-01-11 19:59:14'
    ),
    (
        'NotakingHub/zettelkasten/Nguyễn Trãi.md',
        'Nguyễn Trãi',
        'normal',
        'published',
        'zettelkasten',
        2,
        6,
        TIMESTAMP '2026-03-06 10:48:11',
        TIMESTAMP '2026-03-13 00:48:11'
    ),
    (
        'NotakingHub/zettelkasten/Nhất Linh.md',
        'Nhất Linh',
        'normal',
        'published',
        'zettelkasten',
        2,
        6,
        TIMESTAMP '2026-02-02 13:02:45',
        TIMESTAMP '2026-02-15 00:02:45'
    ),
    (
        'NotakingHub/zettelkasten/OPTICS.md',
        'OPTICS',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2026-02-15 15:18:00',
        TIMESTAMP '2026-03-07 04:18:00'
    ),
    (
        'NotakingHub/zettelkasten/Obsession.md',
        'Obsession',
        'normal',
        'draft',
        'zettelkasten',
        3,
        6,
        TIMESTAMP '2026-08-11 00:00:00',
        TIMESTAMP '2026-08-11 00:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Oedipus Rex.md',
        'Oedipus Rex',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2026-06-24 20:42:11',
        TIMESTAMP '2026-07-04 13:42:11'
    ),
    (
        'NotakingHub/zettelkasten/One Hundred Years of Solitude.md',
        'One Hundred Years of Solitude',
        'normal',
        'private',
        'zettelkasten',
        2,
        3,
        TIMESTAMP '2026-03-04 08:51:26',
        TIMESTAMP '2026-03-06 15:51:26'
    ),
    (
        'NotakingHub/zettelkasten/OpenAI.md',
        'OpenAI',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2025-11-04 09:00:00',
        TIMESTAMP '2025-11-10 20:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Overfitting and Underfitting.md',
        'Overfitting and Underfitting',
        'normal',
        'private',
        'zettelkasten',
        2,
        3,
        TIMESTAMP '2026-06-04 14:05:00',
        TIMESTAMP '2026-06-08 19:05:00'
    ),
    (
        'NotakingHub/zettelkasten/PCA.md',
        'PCA',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2024-12-11 21:00:00',
        TIMESTAMP '2024-12-17 06:00:00'
    ),
    (
        'NotakingHub/zettelkasten/PSD.md',
        'PSD',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2026-01-28 20:29:00',
        TIMESTAMP '2026-02-09 01:29:00'
    ),
    (
        'NotakingHub/zettelkasten/People pleaser.md',
        'People pleaser',
        'normal',
        'draft',
        'zettelkasten',
        3,
        6,
        TIMESTAMP '2024-11-27 00:00:00',
        TIMESTAMP '2024-11-27 00:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Posterior Probability.md',
        'Posterior Probability',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2026-01-28 20:18:00',
        TIMESTAMP '2026-02-26 03:18:00'
    ),
    (
        'NotakingHub/zettelkasten/Principal Component Analysis.md',
        'Principal Component Analysis',
        'normal',
        'private',
        'zettelkasten',
        2,
        3,
        TIMESTAMP '2026-02-17 11:51:49',
        TIMESTAMP '2026-03-12 20:51:49'
    ),
    (
        'NotakingHub/zettelkasten/Probability.md',
        'Probability',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2025-12-06 09:00:00',
        TIMESTAMP '2026-01-20 04:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Promplematic friends.md',
        'Promplematic friends',
        'normal',
        'draft',
        'zettelkasten',
        3,
        6,
        TIMESTAMP '2024-02-11 00:00:00',
        TIMESTAMP '2024-02-11 00:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Quick_Notes/-Quick Note.md',
        '-Quick Note',
        'normal',
        'draft',
        'zettelkasten',
        3,
        5,
        TIMESTAMP '2024-11-20 09:00:00',
        TIMESTAMP '2025-01-01 15:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Quick_Notes/Career Dev.md',
        'Career Dev',
        'normal',
        'draft',
        'zettelkasten',
        3,
        5,
        TIMESTAMP '2025-01-11 21:00:00',
        TIMESTAMP '2025-01-24 22:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Quick_Notes/METLN.md',
        'METLN',
        'normal',
        'private',
        'zettelkasten',
        3,
        3,
        TIMESTAMP '2026-02-17 18:00:00',
        TIMESTAMP '2026-03-15 12:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Quick_Notes/personal statement.md',
        'personal statement',
        'normal',
        'private',
        'zettelkasten',
        3,
        3,
        TIMESTAMP '2026-06-26 11:00:00',
        TIMESTAMP '2026-07-21 17:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Random Forests.md',
        'Random Forests',
        'normal',
        'draft',
        'zettelkasten',
        2,
        5,
        TIMESTAMP '2026-06-02 10:15:00',
        TIMESTAMP '2026-06-03 21:15:00'
    ),
    (
        'NotakingHub/zettelkasten/Romance of the Three Kingdoms.md',
        'Romance of the Three Kingdoms',
        'normal',
        'private',
        'zettelkasten',
        2,
        3,
        TIMESTAMP '2025-12-23 02:22:46',
        TIMESTAMP '2025-12-31 03:22:46'
    ),
    (
        'NotakingHub/zettelkasten/Russian Realism.md',
        'Russian Realism',
        'normal',
        'private',
        'zettelkasten',
        2,
        3,
        TIMESTAMP '2026-06-16 12:56:10',
        TIMESTAMP '2026-07-16 15:56:10'
    ),
    (
        'NotakingHub/zettelkasten/SVD.md',
        'SVD',
        'normal',
        'draft',
        'zettelkasten',
        2,
        5,
        TIMESTAMP '2026-01-27 16:27:00',
        TIMESTAMP '2026-02-22 01:27:00'
    ),
    (
        'NotakingHub/zettelkasten/Scaffolding.md',
        'Scaffolding',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2026-07-19 15:10:00',
        TIMESTAMP '2026-07-27 17:10:00'
    ),
    (
        'NotakingHub/zettelkasten/Self-Determination Theory.md',
        'Self-Determination Theory',
        'normal',
        'published',
        'zettelkasten',
        2,
        6,
        TIMESTAMP '2026-07-01 10:00:00',
        TIMESTAMP '2026-07-04 16:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Self-Efficacy.md',
        'Self-Efficacy',
        'normal',
        'published',
        'zettelkasten',
        2,
        6,
        TIMESTAMP '2026-07-07 09:15:00',
        TIMESTAMP '2026-07-29 20:15:00'
    ),
    (
        'NotakingHub/zettelkasten/Self-Regulated Learning.md',
        'Self-Regulated Learning',
        'normal',
        'private',
        'zettelkasten',
        2,
        3,
        TIMESTAMP '2025-12-24 05:44:35',
        TIMESTAMP '2026-01-01 07:44:35'
    ),
    (
        'NotakingHub/zettelkasten/Simplex vs Full Duplex vs Half Duplex.md',
        'Simplex vs Full Duplex vs Half Duplex',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2026-03-21 18:17:00',
        TIMESTAMP '2026-04-21 23:17:00'
    ),
    (
        'NotakingHub/zettelkasten/Social Capital.md',
        'Social Capital',
        'normal',
        'draft',
        'zettelkasten',
        2,
        5,
        TIMESTAMP '2026-06-20 10:30:00',
        TIMESTAMP '2026-07-08 13:30:00'
    ),
    (
        'NotakingHub/zettelkasten/Social Cognitive Theory.md',
        'Social Cognitive Theory',
        'normal',
        'published',
        'zettelkasten',
        2,
        6,
        TIMESTAMP '2026-06-12 13:10:00',
        TIMESTAMP '2026-06-26 16:10:00'
    ),
    (
        'NotakingHub/zettelkasten/Social Identity Theory.md',
        'Social Identity Theory',
        'normal',
        'private',
        'zettelkasten',
        2,
        3,
        TIMESTAMP '2026-06-22 14:00:00',
        TIMESTAMP '2026-07-12 14:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Social Stratification.md',
        'Social Stratification',
        'normal',
        'draft',
        'zettelkasten',
        2,
        5,
        TIMESTAMP '2026-02-28 17:49:29',
        TIMESTAMP '2026-03-20 00:49:29'
    ),
    (
        'NotakingHub/zettelkasten/Số Đỏ.md',
        'Số Đỏ',
        'normal',
        'published',
        'zettelkasten',
        2,
        6,
        TIMESTAMP '2025-12-19 04:06:51',
        TIMESTAMP '2026-01-10 11:06:51'
    ),
    (
        'NotakingHub/zettelkasten/Spectral Clustering.md',
        'Spectral Clustering',
        'normal',
        'private',
        'zettelkasten',
        2,
        3,
        TIMESTAMP '2025-06-14 15:00:00',
        TIMESTAMP '2025-07-09 06:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Structural Functionalism.md',
        'Structural Functionalism',
        'normal',
        'published',
        'zettelkasten',
        2,
        6,
        TIMESTAMP '2026-06-23 09:50:00',
        TIMESTAMP '2026-07-02 21:50:00'
    ),
    (
        'NotakingHub/zettelkasten/Su Shi.md',
        'Su Shi',
        'normal',
        'private',
        'zettelkasten',
        2,
        3,
        TIMESTAMP '2026-05-16 18:17:33',
        TIMESTAMP '2026-06-15 12:17:33'
    ),
    (
        'NotakingHub/zettelkasten/Supervised Learning.md',
        'Supervised Learning',
        'normal',
        'private',
        'zettelkasten',
        NULL,
        NULL,
        NULL,
        NULL
    ),
    (
        'NotakingHub/zettelkasten/Support Vector Machines.md',
        'Support Vector Machines',
        'normal',
        'draft',
        'zettelkasten',
        2,
        5,
        TIMESTAMP '2026-06-24 07:16:34',
        TIMESTAMP '2026-07-23 02:16:34'
    ),
    (
        'NotakingHub/zettelkasten/Symbolic Interactionism.md',
        'Symbolic Interactionism',
        'normal',
        'draft',
        'zettelkasten',
        2,
        5,
        TIMESTAMP '2026-06-24 13:25:00',
        TIMESTAMP '2026-07-02 21:25:00'
    ),
    (
        'NotakingHub/zettelkasten/TTS.md',
        'TTS',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2026-03-21 17:58:00',
        TIMESTAMP '2026-04-19 01:58:00'
    ),
    (
        'NotakingHub/zettelkasten/Tang Poetry.md',
        'Tang Poetry',
        'normal',
        'published',
        'zettelkasten',
        2,
        6,
        TIMESTAMP '2026-06-28 16:37:56',
        TIMESTAMP '2026-07-08 10:37:56'
    ),
    (
        'NotakingHub/zettelkasten/Tao Te Ching.md',
        'Tao Te Ching',
        'normal',
        'published',
        'zettelkasten',
        2,
        6,
        TIMESTAMP '2026-04-02 14:00:37',
        TIMESTAMP '2026-04-10 10:00:37'
    ),
    (
        'NotakingHub/zettelkasten/Tại sao phải giấu diếm.md',
        'Tại sao phải giấu diếm',
        'normal',
        'draft',
        'zettelkasten',
        3,
        6,
        TIMESTAMP '2024-02-03 00:00:00',
        TIMESTAMP '2024-02-03 00:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Tech Ethics Discussions.md',
        'Tech Ethics Discussions',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2026-03-21 17:47:00',
        TIMESTAMP '2026-04-08 20:47:00'
    ),
    (
        'NotakingHub/zettelkasten/The Iliad.md',
        'The Iliad',
        'normal',
        'draft',
        'zettelkasten',
        2,
        5,
        TIMESTAMP '2026-07-20 23:56:06',
        TIMESTAMP '2026-07-24 11:56:06'
    ),
    (
        'NotakingHub/zettelkasten/The Metamorphosis.md',
        'The Metamorphosis',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2025-12-01 14:19:49',
        TIMESTAMP '2025-12-22 00:19:49'
    ),
    (
        'NotakingHub/zettelkasten/The Odyssey.md',
        'The Odyssey',
        'normal',
        'published',
        'zettelkasten',
        2,
        6,
        TIMESTAMP '2026-02-01 12:08:25',
        TIMESTAMP '2026-02-28 01:08:25'
    ),
    (
        'NotakingHub/zettelkasten/The True Story of Ah Q.md',
        'The True Story of Ah Q',
        'normal',
        'draft',
        'zettelkasten',
        2,
        5,
        TIMESTAMP '2026-01-24 02:20:43',
        TIMESTAMP '2026-02-10 17:20:43'
    ),
    (
        'NotakingHub/zettelkasten/Theories_of_motivation/SDT/Deci and Ryan 2000 - what and why.md',
        'Deci and Ryan 2000 - what and why',
        'normal',
        'draft',
        'zettelkasten',
        2,
        5,
        TIMESTAMP '2025-11-15 10:00:00',
        TIMESTAMP '2025-11-26 04:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Theories_of_motivation/SDT/Lavigne et al 2007.md',
        'Lavigne et al 2007',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2025-05-03 13:00:00',
        TIMESTAMP '2025-06-03 06:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Theories_of_motivation/SDT/Leon et al 2015.md',
        'Leon et al 2015',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2024-10-24 17:00:00',
        TIMESTAMP '2024-11-13 01:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Theories_of_motivation/SDT/Niemiec et al Ryan Deci 2009.md',
        'Niemiec et al Ryan Deci 2009',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2025-10-21 19:00:00',
        TIMESTAMP '2025-11-21 19:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Theories_of_motivation/SDT/Reeve 2009.md',
        'Reeve 2009',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2026-03-06 13:00:00',
        TIMESTAMP '2026-03-31 23:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Theories_of_motivation/SDT/Ryan and Deci 2000 - main.md',
        'Ryan and Deci 2000 - main',
        'normal',
        'draft',
        'zettelkasten',
        2,
        5,
        TIMESTAMP '2026-05-12 13:00:00',
        TIMESTAMP '2026-05-31 03:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Theories_of_motivation/SDT/SDT Reading Map.md',
        'SDT Reading Map',
        'topic',
        'draft',
        'zettelkasten',
        2,
        5,
        TIMESTAMP '2025-02-26 18:00:00',
        TIMESTAMP '2025-04-02 00:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Theories_of_motivation/SDT/Vallerand 2000.md',
        'Vallerand 2000',
        'normal',
        'draft',
        'zettelkasten',
        2,
        5,
        TIMESTAMP '2025-12-05 17:00:00',
        TIMESTAMP '2025-12-16 09:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Theories_of_motivation/SDT/Vansteenkiste et al 2005.md',
        'Vansteenkiste et al 2005',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2026-04-17 13:00:00',
        TIMESTAMP '2026-04-18 17:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Theories_of_motivation/SDT/Vansteenkiste et al 2009.md',
        'Vansteenkiste et al 2009',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2025-09-11 21:00:00',
        TIMESTAMP '2025-10-18 21:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Theories_of_motivation/SDT/Wang et al 2022.md',
        'Wang et al 2022',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2025-12-29 11:00:00',
        TIMESTAMP '2025-12-31 18:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Theories_of_motivation/SRT/Attribution Theory.md',
        'Attribution Theory',
        'normal',
        'private',
        'zettelkasten',
        2,
        3,
        TIMESTAMP '2025-11-02 15:00:00',
        TIMESTAMP '2025-11-25 19:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Theories_of_motivation/SRT/Panadero 2017.md',
        'Panadero 2017',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2024-06-05 08:00:00',
        TIMESTAMP '2024-06-10 13:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Theories_of_motivation/SRT/Pekrun et al 2002.md',
        'Pekrun et al 2002',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2024-08-30 08:00:00',
        TIMESTAMP '2024-10-04 11:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Theories_of_motivation/SRT/Schunk and DiBenedetto 2020.md',
        'Schunk and DiBenedetto 2020',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2025-02-19 09:00:00',
        TIMESTAMP '2025-04-02 23:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Theories_of_motivation/SRT/Self-Regulation Theory.md',
        'Self-Regulation Theory',
        'topic',
        'draft',
        'zettelkasten',
        2,
        5,
        TIMESTAMP '2025-02-21 11:00:00',
        TIMESTAMP '2025-03-24 13:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Theories_of_motivation/SRT/Stefanou et al 2013.md',
        'Stefanou et al 2013',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2025-05-26 19:00:00',
        TIMESTAMP '2025-07-05 06:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Theories_of_motivation/SRT/Sunger and Tekkaya 2006.md',
        'Sunger and Tekkaya 2006',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2025-11-20 16:00:00',
        TIMESTAMP '2025-12-29 18:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Theories_of_motivation/SRT/Weiner 1972 - main.md',
        'Weiner 1972 - main',
        'normal',
        'draft',
        'zettelkasten',
        2,
        5,
        TIMESTAMP '2025-01-16 08:00:00',
        TIMESTAMP '2025-02-08 18:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Theories_of_motivation/SRT/Weiner 2012.md',
        'Weiner 2012',
        'normal',
        'draft',
        'zettelkasten',
        2,
        5,
        TIMESTAMP '2025-01-08 15:00:00',
        TIMESTAMP '2025-02-17 10:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Theories_of_motivation/SRT/Wolters 1998.md',
        'Wolters 1998',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2024-07-01 11:00:00',
        TIMESTAMP '2024-07-12 01:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Theories_of_motivation/SRT/Wolters 2003.md',
        'Wolters 2003',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2025-01-26 17:00:00',
        TIMESTAMP '2025-02-13 01:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Theories_of_motivation/SRT/Zimmerman 2002 - main.md',
        'Zimmerman 2002 - main',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2025-09-11 15:00:00',
        TIMESTAMP '2025-10-23 00:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Theories_of_motivation/SRT/Zimmerman and Martinez Pons 1986.md',
        'Zimmerman and Martinez Pons 1986',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2026-04-15 10:00:00',
        TIMESTAMP '2026-05-10 05:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Theories_of_motivation/SRT/Zimmerman et al 1992.md',
        'Zimmerman et al 1992',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2025-04-03 19:00:00',
        TIMESTAMP '2025-04-20 14:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Theory of Mind.md',
        'Theory of Mind',
        'normal',
        'draft',
        'zettelkasten',
        2,
        5,
        TIMESTAMP '2026-04-25 09:31:52',
        TIMESTAMP '2026-05-11 01:31:52'
    ),
    (
        'NotakingHub/zettelkasten/There''s so much to learn, you own all your time.md',
        'There''s so much to learn, you own all your time',
        'normal',
        'draft',
        'zettelkasten',
        3,
        6,
        TIMESTAMP '2024-05-18 00:00:00',
        TIMESTAMP '2024-05-18 00:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Things I did and things I could have done (08-06-2024).md',
        'Things I did and things I could have done (08-06-2024)',
        'normal',
        'draft',
        'zettelkasten',
        3,
        6,
        TIMESTAMP '2024-06-08 00:00:00',
        TIMESTAMP '2024-06-08 00:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Things I did and things I could have done (11-03-2024).md',
        'Things I did and things I could have done (11-03-2024)',
        'normal',
        'draft',
        'zettelkasten',
        3,
        6,
        TIMESTAMP '2024-03-11 00:00:00',
        TIMESTAMP '2024-03-11 00:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Thơ Mới.md',
        'Thơ Mới',
        'normal',
        'private',
        'zettelkasten',
        2,
        3,
        TIMESTAMP '2026-01-09 14:24:05',
        TIMESTAMP '2026-01-22 22:24:05'
    ),
    (
        'NotakingHub/zettelkasten/Tớ bị làm sao thế.md',
        'Tớ bị làm sao thế',
        'normal',
        'draft',
        'zettelkasten',
        3,
        6,
        TIMESTAMP '2024-11-25 00:00:00',
        TIMESTAMP '2024-11-25 00:00:00'
    ),
    (
        'NotakingHub/zettelkasten/Translation Theory.md',
        'Translation Theory',
        'normal',
        'private',
        'zettelkasten',
        2,
        3,
        TIMESTAMP '2026-01-20 05:41:42',
        TIMESTAMP '2026-02-11 20:41:42'
    ),
    (
        'NotakingHub/zettelkasten/Truyện Kiều.md',
        'Truyện Kiều',
        'normal',
        'published',
        'zettelkasten',
        2,
        6,
        TIMESTAMP '2026-04-13 22:53:58',
        TIMESTAMP '2026-05-04 06:53:58'
    ),
    (
        'NotakingHub/zettelkasten/Tự Lực Văn Đoàn.md',
        'Tự Lực Văn Đoàn',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2026-03-23 18:17:28',
        TIMESTAMP '2026-03-27 01:17:28'
    ),
    (
        'NotakingHub/zettelkasten/Ulysses.md',
        'Ulysses',
        'normal',
        'draft',
        'zettelkasten',
        2,
        5,
        TIMESTAMP '2026-04-21 08:13:33',
        TIMESTAMP '2026-05-20 17:13:33'
    ),
    (
        'NotakingHub/zettelkasten/Universal Design for Learning.md',
        'Universal Design for Learning',
        'normal',
        'draft',
        'zettelkasten',
        2,
        5,
        TIMESTAMP '2026-07-17 13:45:00',
        TIMESTAMP '2026-07-26 15:45:00'
    ),
    (
        'NotakingHub/zettelkasten/Visualizing Latent Space.md',
        'Visualizing Latent Space',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2026-02-28 18:57:00',
        TIMESTAMP '2026-04-05 00:57:00'
    ),
    (
        'NotakingHub/zettelkasten/Voice AI.md',
        'Voice AI',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2026-03-21 19:17:00',
        TIMESTAMP '2026-03-29 13:17:00'
    ),
    (
        'NotakingHub/zettelkasten/Vũ Trọng Phụng.md',
        'Vũ Trọng Phụng',
        'normal',
        'private',
        'zettelkasten',
        2,
        3,
        TIMESTAMP '2026-07-13 14:18:43',
        TIMESTAMP '2026-07-20 16:18:43'
    ),
    (
        'NotakingHub/zettelkasten/War and Peace.md',
        'War and Peace',
        'normal',
        'draft',
        'zettelkasten',
        2,
        5,
        TIMESTAMP '2026-06-13 18:48:02',
        TIMESTAMP '2026-07-08 23:48:02'
    ),
    (
        'NotakingHub/zettelkasten/Water Margin.md',
        'Water Margin',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2026-04-02 21:14:07',
        TIMESTAMP '2026-04-16 05:14:07'
    ),
    (
        'NotakingHub/zettelkasten/Why do stacked ensemble models win data science competitions?.md',
        'Why do stacked ensemble models win data science competitions?',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2026-03-16 18:16:00',
        TIMESTAMP '2026-04-20 07:16:00'
    ),
    (
        'NotakingHub/zettelkasten/Working Memory.md',
        'Working Memory',
        'normal',
        'published',
        'zettelkasten',
        2,
        6,
        TIMESTAMP '2026-05-25 17:09:21',
        TIMESTAMP '2026-05-30 00:09:21'
    ),
    (
        'NotakingHub/zettelkasten/Xuân Diệu.md',
        'Xuân Diệu',
        'normal',
        'draft',
        'zettelkasten',
        2,
        5,
        TIMESTAMP '2026-05-26 11:05:25',
        TIMESTAMP '2026-06-16 22:05:25'
    ),
    (
        'NotakingHub/zettelkasten/Zhuangzi.md',
        'Zhuangzi',
        'normal',
        'private',
        'zettelkasten',
        2,
        3,
        TIMESTAMP '2026-01-12 23:00:14',
        TIMESTAMP '2026-01-18 19:00:14'
    ),
    (
        'NotakingHub/zettelkasten/Zone of Proximal Development.md',
        'Zone of Proximal Development',
        'normal',
        'published',
        'zettelkasten',
        2,
        6,
        TIMESTAMP '2026-07-18 09:00:00',
        TIMESTAMP '2026-08-06 15:00:00'
    ),
    (
        'NotakingHub/zettelkasten/scFates.md',
        'scFates',
        'normal',
        'private',
        'zettelkasten',
        NULL,
        NULL,
        NULL,
        NULL
    ),
    (
        'NotakingHub/zettelkasten/Đoạn Tuyệt.md',
        'Đoạn Tuyệt',
        'normal',
        'private',
        'zettelkasten',
        2,
        1,
        TIMESTAMP '2026-02-20 17:44:49',
        TIMESTAMP '2026-03-15 01:44:49'
    ),
    (
        'The Good Place/Braindump Location!.md',
        'Braindump Location!',
        'normal',
        'private',
        'inbox',
        NULL,
        NULL,
        NULL,
        NULL
    ),
    (
        'The Good Place/Friday.md',
        'Friday',
        'normal',
        'private',
        'inbox',
        NULL,
        NULL,
        NULL,
        NULL
    ),
    (
        'The Good Place/Resources.md',
        'Resources',
        'normal',
        'private',
        'inbox',
        NULL,
        NULL,
        NULL,
        NULL
    ),
    (
        'The Good Place/TGC_M2.md',
        'TGC_M2',
        'normal',
        'private',
        'inbox',
        NULL,
        NULL,
        TIMESTAMP '2026-06-06 00:00:00',
        NULL
    ),
    (
        'The Good Place/TGC_M4.md',
        'TGC_M4',
        'normal',
        'private',
        'inbox',
        NULL,
        NULL,
        TIMESTAMP '2026-06-06 00:00:00',
        NULL
    );

-- Aliases look their parent up by vault_path, the natural key,
-- rather than by a hardcoded id -- the pattern to use when the next
-- id is not knowable in advance.
INSERT INTO
    aliases (node_id, name)
VALUES (
        (
            SELECT node_id
            FROM nodes
            WHERE
                vault_path = 'NotakingHub/indexes/Topics/Computer Science.md'
        ),
        'technology'
    ),
    (
        (
            SELECT node_id
            FROM nodes
            WHERE
                vault_path = 'NotakingHub/indexes/Topics/Data Science.md'
        ),
        'DS'
    ),
    (
        (
            SELECT node_id
            FROM nodes
            WHERE
                vault_path = 'NotakingHub/indexes/Topics/Data Science.md'
        ),
        'data'
    ),
    (
        (
            SELECT node_id
            FROM nodes
            WHERE
                vault_path = 'NotakingHub/indexes/Topics/Machine Learning.md'
        ),
        'ML'
    ),
    (
        (
            SELECT node_id
            FROM nodes
            WHERE
                vault_path = 'NotakingHub/indexes/Topics/Pedagogy.md'
        ),
        'Learning Sciences'
    ),
    (
        (
            SELECT node_id
            FROM nodes
            WHERE
                vault_path = 'NotakingHub/zettelkasten/Basic Psychological Needs Theory.md'
        ),
        'BPNT'
    ),
    (
        (
            SELECT node_id
            FROM nodes
            WHERE
                vault_path = 'NotakingHub/zettelkasten/COURSES/DS5230-UnsupervisedML/02-19-26-Class7-TextMining.md'
        ),
        'textscraping'
    ),
    (
        (
            SELECT node_id
            FROM nodes
            WHERE
                vault_path = 'NotakingHub/zettelkasten/K-Means++.md'
        ),
        'kmeans++'
    ),
    (
        (
            SELECT node_id
            FROM nodes
            WHERE
                vault_path = 'NotakingHub/zettelkasten/K-Means++.md'
        ),
        'k-means plus plus'
    ),
    (
        (
            SELECT node_id
            FROM nodes
            WHERE
                vault_path = 'NotakingHub/zettelkasten/K-Means.md'
        ),
        'k-mean'
    ),
    (
        (
            SELECT node_id
            FROM nodes
            WHERE
                vault_path = 'NotakingHub/zettelkasten/K-Means.md'
        ),
        'kmean'
    ),
    (
        (
            SELECT node_id
            FROM nodes
            WHERE
                vault_path = 'NotakingHub/zettelkasten/SVD.md'
        ),
        'Singular Vector Decomposition'
    ),
    (
        (
            SELECT node_id
            FROM nodes
            WHERE
                vault_path = 'NotakingHub/zettelkasten/Self-Determination Theory.md'
        ),
        'SDT'
    ),
    (
        (
            SELECT node_id
            FROM nodes
            WHERE
                vault_path = 'NotakingHub/zettelkasten/TTS.md'
        ),
        'Text-to-Speech'
    ),
    (
        (
            SELECT node_id
            FROM nodes
            WHERE
                vault_path = 'NotakingHub/zettelkasten/Theories_of_motivation/SDT/SDT Reading Map.md'
        ),
        'SDT Papers'
    ),
    (
        (
            SELECT node_id
            FROM nodes
            WHERE
                vault_path = 'NotakingHub/zettelkasten/Universal Design for Learning.md'
        ),
        'UDL'
    ),
    (
        (
            SELECT node_id
            FROM nodes
            WHERE
                vault_path = 'NotakingHub/zettelkasten/Visualizing Latent Space.md'
        ),
        'latent space'
    ),
    (
        (
            SELECT node_id
            FROM nodes
            WHERE
                vault_path = 'NotakingHub/zettelkasten/Zone of Proximal Development.md'
        ),
        'ZPD'
    );

-- Link counts per note are lopsided: a few hubs carry dozens, most
-- carry none.
INSERT INTO
    node_links (
        source_node_id,
        target_node_id,
        link_type
    )
VALUES (4, 19, 'wiki_link'),
    (5, 123, 'wiki_link'),
    (6, 130, 'wiki_link'),
    (6, 97, 'wiki_link'),
    (6, 184, 'wiki_link'),
    (6, 252, 'wiki_link'),
    (6, 110, 'wiki_link'),
    (6, 205, 'wiki_link'),
    (6, 32, 'wiki_link'),
    (6, 256, 'wiki_link'),
    (6, 46, 'wiki_link'),
    (6, 204, 'wiki_link'),
    (6, 141, 'wiki_link'),
    (6, 98, 'wiki_link'),
    (6, 199, 'wiki_link'),
    (6, 149, 'wiki_link'),
    (6, 211, 'wiki_link'),
    (6, 9, 'wiki_link'),
    (9, 17, 'wiki_link'),
    (9, 6, 'wiki_link'),
    (9, 18, 'wiki_link'),
    (9, 144, 'wiki_link'),
    (9, 87, 'wiki_link'),
    (9, 243, 'wiki_link'),
    (9, 102, 'wiki_link'),
    (10, 200, 'wiki_link'),
    (10, 171, 'wiki_link'),
    (10, 91, 'wiki_link'),
    (10, 117, 'wiki_link'),
    (10, 143, 'wiki_link'),
    (10, 183, 'wiki_link'),
    (10, 201, 'wiki_link'),
    (10, 135, 'wiki_link'),
    (10, 131, 'wiki_link'),
    (10, 176, 'wiki_link'),
    (10, 139, 'wiki_link'),
    (11, 142, 'wiki_link'),
    (11, 77, 'wiki_link'),
    (12, 188, 'wiki_link'),
    (12, 40, 'wiki_link'),
    (12, 129, 'wiki_link'),
    (12, 105, 'wiki_link'),
    (12, 114, 'wiki_link'),
    (12, 109, 'wiki_link'),
    (12, 189, 'wiki_link'),
    (12, 15, 'wiki_link'),
    (12, 14, 'wiki_link'),
    (14, 113, 'wiki_link'),
    (14, 103, 'wiki_link'),
    (14, 247, 'wiki_link'),
    (14, 257, 'wiki_link'),
    (14, 187, 'wiki_link'),
    (14, 93, 'wiki_link'),
    (14, 12, 'wiki_link'),
    (14, 15, 'wiki_link'),
    (14, 16, 'wiki_link'),
    (15, 86, 'wiki_link'),
    (15, 119, 'wiki_link'),
    (15, 193, 'wiki_link'),
    (15, 85, 'wiki_link'),
    (15, 44, 'wiki_link'),
    (15, 12, 'wiki_link'),
    (15, 16, 'wiki_link'),
    (15, 14, 'wiki_link'),
    (16, 192, 'wiki_link'),
    (16, 121, 'wiki_link'),
    (16, 194, 'wiki_link'),
    (16, 198, 'wiki_link'),
    (16, 202, 'wiki_link'),
    (16, 15, 'wiki_link'),
    (16, 14, 'wiki_link'),
    (17, 76, 'wiki_link'),
    (17, 161, 'wiki_link'),
    (17, 9, 'wiki_link'),
    (18, 208, 'wiki_link'),
    (18, 210, 'wiki_link'),
    (18, 118, 'wiki_link'),
    (18, 168, 'wiki_link'),
    (18, 95, 'wiki_link'),
    (18, 122, 'wiki_link'),
    (18, 150, 'wiki_link'),
    (18, 96, 'wiki_link'),
    (18, 90, 'wiki_link'),
    (18, 251, 'wiki_link'),
    (18, 185, 'wiki_link'),
    (18, 151, 'wiki_link'),
    (18, 111, 'wiki_link'),
    (18, 115, 'wiki_link'),
    (18, 209, 'wiki_link'),
    (18, 160, 'wiki_link'),
    (18, 246, 'wiki_link'),
    (18, 169, 'wiki_link'),
    (18, 152, 'wiki_link'),
    (18, 9, 'wiki_link'),
    (27, 5, 'wiki_link'),
    (27, 13, 'wiki_link'),
    (28, 138, 'wiki_link'),
    (28, 136, 'wiki_link'),
    (28, 127, 'wiki_link'),
    (29, 114, 'wiki_link'),
    (29, 189, 'wiki_link'),
    (32, 205, 'wiki_link'),
    (32, 256, 'wiki_link'),
    (33, 198, 'wiki_link'),
    (33, 195, 'wiki_link'),
    (34, 83, 'wiki_link'),
    (34, 170, 'wiki_link'),
    (34, 116, 'wiki_link'),
    (37, 237, 'wiki_link'),
    (40, 188, 'wiki_link'),
    (40, 129, 'wiki_link'),
    (41, 43, 'wiki_link'),
    (44, 193, 'wiki_link'),
    (44, 129, 'wiki_link'),
    (46, 204, 'wiki_link'),
    (48, 8, 'wiki_link'),
    (48, 258, 'wiki_link'),
    (62, 156, 'wiki_link'),
    (62, 77, 'wiki_link'),
    (62, 177, 'wiki_link'),
    (63, 10, 'wiki_link'),
    (67, 8, 'wiki_link'),
    (68, 10, 'wiki_link'),
    (69, 10, 'wiki_link'),
    (69, 84, 'wiki_link'),
    (71, 10, 'wiki_link'),
    (81, 161, 'wiki_link'),
    (82, 238, 'wiki_link'),
    (83, 34, 'wiki_link'),
    (83, 80, 'wiki_link'),
    (83, 104, 'wiki_link'),
    (84, 133, 'wiki_link'),
    (84, 134, 'wiki_link'),
    (84, 31, 'wiki_link'),
    (84, 94, 'wiki_link'),
    (84, 120, 'wiki_link'),
    (84, 112, 'wiki_link'),
    (84, 197, 'wiki_link'),
    (84, 157, 'wiki_link'),
    (84, 166, 'wiki_link'),
    (84, 38, 'wiki_link'),
    (84, 30, 'wiki_link'),
    (85, 193, 'wiki_link'),
    (86, 254, 'wiki_link'),
    (86, 187, 'wiki_link'),
    (87, 243, 'wiki_link'),
    (87, 152, 'wiki_link'),
    (88, 143, 'wiki_link'),
    (88, 135, 'wiki_link'),
    (90, 251, 'wiki_link'),
    (90, 185, 'wiki_link'),
    (91, 171, 'wiki_link'),
    (92, 121, 'wiki_link'),
    (92, 192, 'wiki_link'),
    (93, 103, 'wiki_link'),
    (93, 194, 'wiki_link'),
    (94, 84, 'wiki_link'),
    (95, 115, 'wiki_link'),
    (96, 122, 'wiki_link'),
    (97, 110, 'wiki_link'),
    (97, 252, 'wiki_link'),
    (98, 141, 'wiki_link'),
    (98, 204, 'wiki_link'),
    (101, 133, 'wiki_link'),
    (102, 208, 'wiki_link'),
    (102, 210, 'wiki_link'),
    (103, 93, 'wiki_link'),
    (103, 192, 'wiki_link'),
    (105, 114, 'wiki_link'),
    (105, 189, 'wiki_link'),
    (107, 108, 'wiki_link'),
    (108, 107, 'wiki_link'),
    (109, 129, 'wiki_link'),
    (109, 113, 'wiki_link'),
    (110, 130, 'wiki_link'),
    (110, 184, 'wiki_link'),
    (110, 252, 'wiki_link'),
    (110, 97, 'wiki_link'),
    (111, 160, 'wiki_link'),
    (113, 109, 'wiki_link'),
    (113, 129, 'wiki_link'),
    (114, 29, 'wiki_link'),
    (114, 105, 'wiki_link'),
    (115, 95, 'wiki_link'),
    (118, 168, 'wiki_link'),
    (119, 189, 'wiki_link'),
    (119, 114, 'wiki_link'),
    (121, 92, 'wiki_link'),
    (121, 192, 'wiki_link'),
    (122, 150, 'wiki_link'),
    (122, 96, 'wiki_link'),
    (126, 76, 'wiki_link'),
    (129, 188, 'wiki_link'),
    (129, 109, 'wiki_link'),
    (130, 110, 'wiki_link'),
    (130, 184, 'wiki_link'),
    (131, 176, 'wiki_link'),
    (132, 84, 'wiki_link'),
    (132, 133, 'wiki_link'),
    (133, 84, 'wiki_link'),
    (140, 151, 'wiki_link'),
    (140, 185, 'wiki_link'),
    (141, 98, 'wiki_link'),
    (141, 204, 'wiki_link'),
    (144, 152, 'wiki_link'),
    (144, 160, 'wiki_link'),
    (147, 145, 'wiki_link'),
    (148, 133, 'wiki_link'),
    (149, 211, 'wiki_link'),
    (150, 122, 'wiki_link'),
    (151, 185, 'wiki_link'),
    (152, 169, 'wiki_link'),
    (152, 160, 'wiki_link'),
    (153, 190, 'wiki_link'),
    (153, 257, 'wiki_link'),
    (157, 84, 'wiki_link'),
    (159, 133, 'wiki_link'),
    (159, 117, 'wiki_link'),
    (160, 246, 'wiki_link'),
    (160, 111, 'wiki_link'),
    (167, 202, 'wiki_link'),
    (167, 85, 'wiki_link'),
    (168, 118, 'wiki_link'),
    (169, 152, 'wiki_link'),
    (171, 91, 'wiki_link'),
    (171, 183, 'wiki_link'),
    (175, 42, 'wiki_link'),
    (175, 41, 'wiki_link'),
    (176, 131, 'wiki_link'),
    (183, 171, 'wiki_link'),
    (183, 201, 'wiki_link'),
    (184, 110, 'wiki_link'),
    (184, 252, 'wiki_link'),
    (185, 90, 'wiki_link'),
    (185, 251, 'wiki_link'),
    (186, 155, 'wiki_link'),
    (186, 173, 'wiki_link'),
    (187, 257, 'wiki_link'),
    (187, 86, 'wiki_link'),
    (188, 40, 'wiki_link'),
    (188, 129, 'wiki_link'),
    (189, 193, 'wiki_link'),
    (189, 29, 'wiki_link'),
    (190, 153, 'wiki_link'),
    (190, 254, 'wiki_link'),
    (191, 249, 'wiki_link'),
    (192, 92, 'wiki_link'),
    (192, 121, 'wiki_link'),
    (193, 189, 'wiki_link'),
    (193, 44, 'wiki_link'),
    (194, 202, 'wiki_link'),
    (194, 93, 'wiki_link'),
    (195, 33, 'wiki_link'),
    (195, 92, 'wiki_link'),
    (198, 33, 'wiki_link'),
    (198, 202, 'wiki_link'),
    (199, 141, 'wiki_link'),
    (199, 98, 'wiki_link'),
    (201, 183, 'wiki_link'),
    (202, 194, 'wiki_link'),
    (202, 198, 'wiki_link'),
    (204, 141, 'wiki_link'),
    (204, 98, 'wiki_link'),
    (205, 256, 'wiki_link'),
    (205, 32, 'wiki_link'),
    (207, 203, 'wiki_link'),
    (208, 210, 'wiki_link'),
    (208, 102, 'wiki_link'),
    (209, 160, 'wiki_link'),
    (210, 208, 'wiki_link'),
    (210, 102, 'wiki_link'),
    (211, 149, 'wiki_link'),
    (212, 217, 'wiki_link'),
    (218, 212, 'wiki_link'),
    (218, 219, 'wiki_link'),
    (218, 220, 'wiki_link'),
    (218, 217, 'wiki_link'),
    (218, 216, 'wiki_link'),
    (218, 215, 'wiki_link'),
    (218, 221, 'wiki_link'),
    (218, 222, 'wiki_link'),
    (218, 213, 'wiki_link'),
    (218, 214, 'wiki_link'),
    (219, 217, 'wiki_link'),
    (223, 230, 'wiki_link'),
    (223, 231, 'wiki_link'),
    (227, 234, 'wiki_link'),
    (227, 235, 'wiki_link'),
    (227, 232, 'wiki_link'),
    (227, 236, 'wiki_link'),
    (227, 225, 'wiki_link'),
    (227, 233, 'wiki_link'),
    (227, 229, 'wiki_link'),
    (227, 228, 'wiki_link'),
    (227, 224, 'wiki_link'),
    (227, 226, 'wiki_link'),
    (237, 37, 'wiki_link'),
    (239, 240, 'wiki_link'),
    (240, 239, 'wiki_link'),
    (243, 87, 'wiki_link'),
    (246, 160, 'wiki_link'),
    (246, 210, 'wiki_link'),
    (247, 103, 'wiki_link'),
    (247, 187, 'wiki_link'),
    (248, 10, 'wiki_link'),
    (248, 84, 'wiki_link'),
    (248, 172, 'wiki_link'),
    (249, 191, 'wiki_link'),
    (249, 162, 'wiki_link'),
    (250, 161, 'wiki_link'),
    (251, 90, 'wiki_link'),
    (251, 185, 'wiki_link'),
    (252, 110, 'wiki_link'),
    (252, 184, 'wiki_link'),
    (254, 86, 'wiki_link'),
    (254, 237, 'wiki_link'),
    (256, 205, 'wiki_link'),
    (256, 32, 'wiki_link'),
    (257, 187, 'wiki_link'),
    (257, 153, 'wiki_link');

INSERT INTO
    node_topics (node_id, topic_tag_id)
VALUES (6, 2),
    (8, 4),
    (8, 5),
    (10, 6),
    (10, 4),
    (12, 8),
    (13, 1),
    (13, 8),
    (14, 8),
    (14, 11),
    (17, 2),
    (18, 2),
    (27, 10),
    (27, 1),
    (27, 8),
    (28, 4),
    (28, 7),
    (29, 9),
    (30, 6),
    (30, 7),
    (31, 6),
    (31, 7),
    (32, 3),
    (33, 11),
    (34, 4),
    (34, 7),
    (35, 6),
    (35, 7),
    (37, 8),
    (38, 6),
    (38, 7),
    (40, 9),
    (41, 6),
    (41, 5),
    (42, 6),
    (42, 5),
    (43, 6),
    (43, 5),
    (44, 8),
    (45, 13),
    (46, 3),
    (47, 4),
    (48, 1),
    (48, 6),
    (49, 4),
    (49, 6),
    (50, 4),
    (50, 6),
    (51, 4),
    (51, 6),
    (52, 4),
    (52, 6),
    (53, 4),
    (53, 6),
    (54, 4),
    (54, 6),
    (55, 4),
    (55, 6),
    (56, 4),
    (56, 6),
    (57, 4),
    (57, 6),
    (58, 4),
    (58, 6),
    (59, 4),
    (59, 6),
    (60, 4),
    (60, 7),
    (61, 4),
    (61, 7),
    (62, 4),
    (62, 7),
    (63, 4),
    (63, 7),
    (64, 4),
    (64, 7),
    (65, 4),
    (65, 7),
    (66, 4),
    (66, 7),
    (67, 6),
    (67, 7),
    (68, 6),
    (68, 7),
    (69, 6),
    (69, 7),
    (70, 6),
    (70, 7),
    (71, 6),
    (71, 7),
    (72, 6),
    (72, 7),
    (73, 6),
    (73, 7),
    (74, 6),
    (74, 7),
    (75, 6),
    (75, 7),
    (76, 13),
    (77, 6),
    (77, 5),
    (80, 4),
    (80, 7),
    (81, 13),
    (83, 4),
    (83, 7),
    (84, 6),
    (84, 7),
    (85, 8),
    (86, 8),
    (87, 2),
    (88, 6),
    (88, 7),
    (89, 4),
    (89, 6),
    (90, 14),
    (91, 6),
    (91, 7),
    (92, 11),
    (93, 12),
    (94, 6),
    (94, 7),
    (95, 14),
    (96, 14),
    (97, 3),
    (98, 3),
    (99, 7),
    (99, 4),
    (100, 7),
    (100, 6),
    (101, 6),
    (101, 7),
    (102, 2),
    (103, 12),
    (104, 4),
    (105, 9),
    (109, 9),
    (110, 3),
    (111, 14),
    (112, 6),
    (112, 7),
    (113, 12),
    (114, 9),
    (115, 14),
    (116, 4),
    (116, 7),
    (117, 6),
    (117, 7),
    (118, 14),
    (119, 8),
    (120, 6),
    (120, 7),
    (121, 11),
    (122, 14),
    (126, 13),
    (127, 4),
    (127, 7),
    (129, 9),
    (130, 3),
    (131, 6),
    (131, 7),
    (132, 6),
    (132, 7),
    (133, 6),
    (133, 7),
    (134, 6),
    (134, 7),
    (135, 6),
    (135, 7),
    (136, 4),
    (136, 7),
    (138, 4),
    (138, 7),
    (140, 14),
    (141, 3),
    (142, 6),
    (142, 5),
    (143, 6),
    (143, 7),
    (144, 2),
    (145, 3),
    (145, 2),
    (146, 3),
    (146, 2),
    (147, 3),
    (147, 2),
    (148, 6),
    (148, 7),
    (149, 3),
    (150, 14),
    (151, 14),
    (152, 14),
    (153, 12),
    (154, 4),
    (155, 6),
    (155, 5),
    (156, 6),
    (156, 5),
    (157, 6),
    (157, 7),
    (159, 6),
    (159, 7),
    (160, 14),
    (161, 13),
    (162, 4),
    (162, 7),
    (163, 13),
    (164, 13),
    (165, 13),
    (166, 6),
    (166, 7),
    (168, 14),
    (169, 14),
    (170, 4),
    (170, 7),
    (171, 6),
    (171, 7),
    (172, 6),
    (172, 7),
    (173, 6),
    (173, 5),
    (175, 6),
    (175, 5),
    (176, 6),
    (176, 7),
    (177, 6),
    (177, 5),
    (183, 6),
    (183, 7),
    (184, 3),
    (185, 14),
    (186, 6),
    (186, 5),
    (187, 12),
    (188, 9),
    (189, 9),
    (190, 12),
    (191, 4),
    (192, 11),
    (193, 8),
    (194, 11),
    (195, 11),
    (196, 13),
    (197, 6),
    (197, 7),
    (198, 11),
    (199, 3),
    (201, 6),
    (201, 7),
    (202, 11),
    (203, 4),
    (203, 7),
    (204, 3),
    (205, 3),
    (207, 4),
    (207, 11),
    (208, 14),
    (209, 14),
    (210, 14),
    (211, 3),
    (212, 9),
    (212, 8),
    (213, 9),
    (213, 12),
    (213, 8),
    (214, 9),
    (214, 12),
    (214, 8),
    (215, 9),
    (215, 12),
    (215, 8),
    (216, 9),
    (216, 12),
    (216, 8),
    (217, 9),
    (217, 8),
    (218, 9),
    (218, 12),
    (218, 8),
    (219, 9),
    (219, 8),
    (220, 9),
    (220, 12),
    (220, 8),
    (221, 9),
    (221, 12),
    (221, 8),
    (222, 9),
    (222, 12),
    (222, 8),
    (223, 9),
    (223, 8),
    (224, 9),
    (224, 12),
    (224, 8),
    (225, 9),
    (225, 12),
    (225, 8),
    (226, 9),
    (226, 12),
    (226, 8),
    (227, 9),
    (227, 12),
    (227, 8),
    (228, 9),
    (228, 12),
    (228, 8),
    (229, 9),
    (229, 12),
    (229, 8),
    (230, 9),
    (230, 8),
    (231, 9),
    (231, 8),
    (232, 9),
    (232, 12),
    (232, 8),
    (233, 9),
    (233, 12),
    (233, 8),
    (234, 9),
    (234, 12),
    (234, 8),
    (235, 9),
    (235, 12),
    (235, 8),
    (236, 9),
    (236, 12),
    (236, 8),
    (237, 8),
    (241, 13),
    (243, 2),
    (244, 13),
    (245, 13),
    (246, 14),
    (247, 12),
    (248, 6),
    (248, 7),
    (249, 4),
    (249, 7),
    (250, 13),
    (251, 14),
    (252, 3),
    (253, 6),
    (253, 7),
    (254, 8),
    (255, 13),
    (256, 3),
    (257, 12),
    (259, 13);

INSERT INTO
    node_tags (node_id, free_tag_id)
VALUES (5, 1),
    (11, 1),
    (13, 1),
    (24, 1),
    (42, 1),
    (43, 1),
    (49, 2),
    (50, 2),
    (51, 2),
    (51, 3),
    (52, 2),
    (54, 2),
    (60, 1),
    (65, 2),
    (67, 2),
    (70, 3),
    (77, 1),
    (80, 1),
    (89, 1),
    (99, 3),
    (104, 1),
    (116, 1),
    (127, 1),
    (135, 1),
    (136, 1),
    (138, 1),
    (143, 1),
    (155, 1),
    (156, 1),
    (158, 2),
    (159, 2),
    (170, 1),
    (172, 1),
    (177, 1),
    (213, 1),
    (214, 1),
    (215, 1),
    (216, 1),
    (220, 1),
    (221, 1),
    (222, 1),
    (224, 1),
    (225, 1),
    (226, 1),
    (228, 1),
    (229, 1),
    (232, 1),
    (233, 1),
    (234, 1),
    (235, 1),
    (236, 1);

INSERT INTO
    node_sources (node_id, source_id)
VALUES (7, 1),
    (27, 2),
    (27, 3),
    (27, 4),
    (27, 5),
    (27, 6),
    (30, 7),
    (31, 8),
    (34, 9),
    (35, 10),
    (38, 11),
    (49, 12),
    (50, 13),
    (51, 14),
    (52, 15),
    (54, 16),
    (55, 17),
    (56, 18),
    (57, 19),
    (58, 20),
    (59, 21),
    (59, 22),
    (60, 23),
    (61, 24),
    (61, 25),
    (61, 26),
    (61, 27),
    (62, 28),
    (62, 29),
    (63, 30),
    (63, 31),
    (63, 32),
    (65, 33),
    (65, 34),
    (65, 35),
    (67, 36),
    (70, 37),
    (71, 38),
    (94, 39),
    (94, 40),
    (99, 41),
    (100, 42),
    (100, 43),
    (100, 44),
    (100, 45),
    (100, 46),
    (120, 47),
    (132, 48),
    (133, 48),
    (142, 49),
    (157, 50),
    (157, 51),
    (159, 52),
    (159, 53),
    (162, 54),
    (162, 55),
    (166, 56),
    (181, 57),
    (186, 58),
    (203, 59),
    (207, 60),
    (207, 61),
    (207, 62),
    (207, 63),
    (207, 64),
    (212, 65),
    (213, 66),
    (214, 67),
    (215, 68),
    (216, 69),
    (217, 70),
    (219, 71),
    (220, 72),
    (221, 73),
    (222, 74),
    (224, 75),
    (225, 76),
    (226, 77),
    (228, 78),
    (229, 79),
    (230, 80),
    (231, 81),
    (232, 82),
    (233, 83),
    (234, 84),
    (235, 85),
    (236, 86),
    (249, 87),
    (249, 88),
    (249, 89),
    (249, 90),
    (249, 91),
    (253, 92),
    (253, 93),
    (253, 94),
    (253, 95),
    (253, 96);

INSERT INTO
    topic_hierarchy (
        parent_topic_tag_id,
        child_topic_tag_id
    )
VALUES (2, 3),
    (4, 6),
    (5, 6),
    (6, 7),
    (4, 7),
    (8, 9),
    (1, 10),
    (8, 10),
    (8, 12),
    (11, 12),
    (2, 13),
    (2, 14),
    (6, 15),
    (7, 15),
    (9, 16),
    (12, 16),
    (8, 16),
    (9, 17),
    (12, 17),
    (8, 17);

INSERT INTO
    term_topics (term_id, topic_tag_id)
VALUES (1, 10),
    (1, 1),
    (1, 8),
    (2, 10),
    (2, 1),
    (2, 8),
    (3, 10),
    (3, 1),
    (3, 8),
    (4, 6),
    (4, 7),
    (5, 6),
    (5, 7),
    (6, 6),
    (6, 7),
    (7, 6),
    (7, 7),
    (8, 6),
    (8, 7),
    (9, 6),
    (9, 7),
    (10, 6),
    (10, 7),
    (11, 6),
    (11, 7),
    (12, 6),
    (12, 7),
    (13, 6),
    (13, 7),
    (17, 6),
    (17, 7),
    (18, 6),
    (18, 7),
    (19, 6),
    (19, 7),
    (20, 6),
    (20, 5),
    (21, 6),
    (21, 5),
    (22, 6),
    (22, 5),
    (23, 6),
    (23, 5),
    (24, 6),
    (24, 5),
    (25, 6),
    (25, 5),
    (26, 4),
    (27, 4),
    (27, 6),
    (28, 4),
    (28, 6),
    (29, 4),
    (29, 6),
    (30, 4),
    (30, 6),
    (31, 4),
    (31, 6),
    (32, 4),
    (32, 6),
    (33, 4),
    (33, 6),
    (34, 4),
    (34, 6),
    (35, 4),
    (35, 6),
    (36, 4),
    (36, 6),
    (37, 4),
    (37, 6),
    (38, 4),
    (38, 6),
    (39, 4),
    (39, 6),
    (40, 4),
    (40, 6),
    (41, 4),
    (41, 6),
    (42, 4),
    (42, 6),
    (43, 4),
    (43, 6),
    (44, 4),
    (44, 6),
    (45, 4),
    (45, 6),
    (46, 4),
    (46, 6),
    (47, 4),
    (47, 6),
    (48, 4),
    (48, 6),
    (49, 4),
    (49, 6),
    (50, 4),
    (50, 6),
    (51, 4),
    (51, 6),
    (52, 4),
    (52, 6),
    (53, 4),
    (53, 6),
    (54, 4),
    (54, 6),
    (55, 4),
    (55, 6),
    (56, 4),
    (56, 6),
    (57, 4),
    (57, 6),
    (58, 4),
    (58, 6),
    (59, 4),
    (59, 6),
    (60, 4),
    (60, 6),
    (61, 4),
    (61, 6),
    (62, 4),
    (62, 6),
    (63, 4),
    (63, 6),
    (64, 4),
    (64, 6),
    (65, 4),
    (65, 6),
    (66, 4),
    (66, 6),
    (67, 4),
    (67, 6),
    (68, 4),
    (68, 6),
    (69, 4),
    (69, 7),
    (70, 4),
    (70, 7),
    (71, 4),
    (71, 7),
    (72, 4),
    (72, 7),
    (73, 4),
    (73, 7),
    (74, 4),
    (74, 7),
    (75, 4),
    (75, 7),
    (76, 4),
    (76, 7),
    (77, 4),
    (77, 7),
    (78, 4),
    (78, 7),
    (79, 4),
    (79, 7),
    (80, 4),
    (80, 7),
    (81, 4),
    (81, 7),
    (82, 4),
    (82, 7),
    (83, 4),
    (83, 7),
    (84, 4),
    (84, 7),
    (85, 4),
    (85, 7),
    (86, 4),
    (86, 7),
    (87, 4),
    (87, 7),
    (88, 4),
    (88, 7),
    (89, 4),
    (89, 7),
    (90, 4),
    (90, 7),
    (91, 4),
    (91, 7),
    (92, 4),
    (92, 7),
    (93, 4),
    (93, 7),
    (94, 4),
    (94, 7),
    (95, 6),
    (95, 7),
    (96, 6),
    (96, 7),
    (97, 6),
    (97, 7),
    (98, 6),
    (98, 7),
    (99, 6),
    (99, 7),
    (100, 6),
    (100, 7),
    (101, 6),
    (101, 7),
    (102, 6),
    (102, 7),
    (103, 6),
    (103, 7),
    (104, 6),
    (104, 7),
    (105, 6),
    (105, 7),
    (106, 6),
    (106, 7),
    (107, 6),
    (107, 7),
    (108, 6),
    (108, 7),
    (109, 6),
    (109, 7),
    (110, 6),
    (110, 7),
    (111, 6),
    (111, 7),
    (112, 6),
    (112, 7),
    (113, 6),
    (113, 7),
    (114, 6),
    (114, 7),
    (115, 6),
    (115, 7),
    (116, 6),
    (116, 7),
    (117, 6),
    (117, 7),
    (118, 6),
    (118, 7),
    (119, 6),
    (119, 7),
    (120, 6),
    (120, 7),
    (121, 6),
    (121, 7),
    (122, 6),
    (122, 7),
    (123, 6),
    (123, 7),
    (124, 6),
    (124, 7),
    (125, 6),
    (125, 7),
    (126, 6),
    (126, 7),
    (127, 6),
    (127, 7),
    (128, 6),
    (128, 7),
    (129, 6),
    (129, 7),
    (130, 6),
    (130, 7),
    (131, 6),
    (131, 7),
    (132, 6),
    (132, 7),
    (133, 6),
    (133, 7),
    (134, 6),
    (134, 7),
    (135, 6),
    (135, 7),
    (136, 4),
    (136, 6),
    (137, 6),
    (137, 7),
    (138, 6),
    (138, 7),
    (139, 6),
    (139, 7),
    (140, 6),
    (140, 7),
    (141, 6),
    (141, 7),
    (142, 6),
    (142, 7),
    (143, 7),
    (143, 4),
    (144, 7),
    (144, 4),
    (145, 7),
    (145, 4),
    (146, 7),
    (146, 6),
    (147, 7),
    (147, 6),
    (148, 7),
    (148, 6),
    (149, 7),
    (149, 6),
    (150, 7),
    (150, 6),
    (151, 7),
    (151, 6),
    (152, 6),
    (152, 7),
    (153, 6),
    (153, 7),
    (154, 6),
    (154, 7),
    (155, 6),
    (155, 7),
    (156, 6),
    (156, 7),
    (157, 6),
    (157, 7),
    (158, 6),
    (158, 7),
    (159, 6),
    (159, 7),
    (160, 6),
    (160, 7),
    (161, 6),
    (161, 7),
    (162, 6),
    (162, 7),
    (163, 6),
    (163, 7),
    (164, 6),
    (164, 7),
    (165, 6),
    (165, 7),
    (166, 6),
    (166, 7),
    (167, 6),
    (167, 7),
    (168, 6),
    (168, 7),
    (169, 6),
    (169, 7),
    (170, 6),
    (170, 7),
    (171, 6),
    (171, 7),
    (172, 6),
    (172, 7),
    (173, 6),
    (173, 7),
    (174, 6),
    (174, 7),
    (175, 6),
    (175, 7),
    (176, 6),
    (176, 7),
    (177, 6),
    (177, 7),
    (178, 6),
    (178, 7),
    (179, 6),
    (179, 7),
    (180, 6),
    (180, 5),
    (74, 6),
    (74, 5),
    (181, 6),
    (181, 5),
    (182, 6),
    (182, 5),
    (183, 6),
    (183, 5),
    (184, 6),
    (184, 5),
    (185, 6),
    (185, 7),
    (82, 6),
    (186, 6),
    (186, 7),
    (187, 3),
    (187, 2),
    (188, 3),
    (188, 2),
    (189, 3),
    (189, 2),
    (190, 3),
    (190, 2),
    (191, 3),
    (191, 2),
    (192, 3),
    (192, 2),
    (193, 6),
    (193, 7),
    (194, 6),
    (194, 7),
    (195, 6),
    (195, 7),
    (196, 6),
    (196, 7),
    (197, 6),
    (197, 7),
    (198, 6),
    (198, 7),
    (199, 6),
    (199, 7),
    (200, 6),
    (200, 7),
    (201, 6),
    (201, 7),
    (208, 6),
    (208, 7),
    (209, 6),
    (209, 7),
    (210, 6),
    (210, 7),
    (211, 6),
    (211, 7),
    (212, 6),
    (212, 7),
    (213, 4),
    (213, 7),
    (214, 4),
    (214, 7),
    (215, 4),
    (215, 7),
    (216, 4),
    (216, 7),
    (217, 4),
    (217, 7),
    (218, 4),
    (218, 7),
    (219, 6),
    (219, 7),
    (220, 6),
    (220, 7),
    (221, 6),
    (221, 7),
    (57, 7),
    (222, 6),
    (222, 5),
    (223, 6),
    (223, 5),
    (225, 6),
    (225, 5),
    (231, 6),
    (231, 5),
    (232, 6),
    (232, 5),
    (233, 6),
    (233, 5),
    (234, 6),
    (234, 5),
    (235, 6),
    (235, 5),
    (236, 4),
    (237, 4),
    (238, 4),
    (239, 6),
    (239, 7),
    (240, 6),
    (240, 7),
    (241, 6),
    (241, 7),
    (242, 4),
    (242, 7),
    (243, 4),
    (243, 7),
    (244, 9),
    (244, 8),
    (245, 9),
    (245, 8),
    (246, 9),
    (246, 8),
    (247, 9),
    (247, 8),
    (248, 9),
    (248, 8),
    (249, 9),
    (249, 8),
    (250, 9),
    (250, 8),
    (251, 9),
    (251, 8),
    (252, 9),
    (252, 8),
    (253, 9),
    (253, 8),
    (254, 9),
    (254, 8),
    (255, 9),
    (255, 8),
    (256, 9),
    (256, 12),
    (256, 8),
    (257, 9),
    (257, 12),
    (257, 8),
    (258, 9),
    (258, 12),
    (258, 8),
    (259, 9),
    (259, 8),
    (260, 9),
    (260, 8),
    (261, 9),
    (261, 8),
    (262, 9),
    (262, 12),
    (262, 8),
    (263, 9),
    (263, 12),
    (263, 8),
    (264, 6),
    (264, 7),
    (265, 6),
    (265, 7),
    (266, 4),
    (266, 7),
    (267, 4),
    (267, 7),
    (238, 7),
    (268, 4),
    (268, 7),
    (269, 4),
    (269, 7),
    (270, 4),
    (270, 7),
    (271, 6),
    (271, 7),
    (272, 6),
    (272, 7),
    (273, 6),
    (273, 7),
    (274, 6),
    (274, 7),
    (275, 6),
    (275, 7);

COMMIT;

-- =====================================================================
-- SECTION 6: TRIGGER
-- =====================================================================

-- Records every maturity-stage change: where the note moved from, where
-- it moved to, and which direction that was. Defined after the data so
-- the bulk load does not generate audit rows for notes that arrived at a
-- stage rather than moved to one.
--
-- This is not a CHECK constraint's job. A CHECK sees the row in front of
-- it, cannot see what that row used to say, and cannot write anywhere.
CREATE OR REPLACE FUNCTION fn_audit_node_stage() RETURNS TRIGGER AS $$
DECLARE
    -- Stage vocabulary in maturity order, so direction does not depend on
    -- the surrogate ids happening to be in order.
    v_order   TEXT[] := ARRAY['fetus', 'infant', 'toddler',
                              'adolescent', 'teen', 'adult'];
    v_old_pos INTEGER;
    v_new_pos INTEGER;
    v_direction VARCHAR(10);
BEGIN
    IF NEW.maturity_stage_id IS NOT DISTINCT FROM OLD.maturity_stage_id THEN
        RETURN NULL;
    END IF;

    SELECT array_position(v_order, ms.name) INTO v_old_pos
    FROM maturity_stages ms WHERE ms.maturity_stage_id = OLD.maturity_stage_id;

    SELECT array_position(v_order, ms.name) INTO v_new_pos
    FROM maturity_stages ms WHERE ms.maturity_stage_id = NEW.maturity_stage_id;

    v_direction := CASE
        WHEN v_old_pos IS NULL AND v_new_pos IS NOT NULL THEN 'classified'
        WHEN v_new_pos IS NULL THEN 'cleared'
        WHEN v_new_pos > v_old_pos THEN 'promoted'
        ELSE 'demoted'
    END;

    INSERT INTO node_stage_audit (
        node_id, old_maturity_stage_id, new_maturity_stage_id, direction
    )
    VALUES (
        NEW.node_id, OLD.maturity_stage_id, NEW.maturity_stage_id, v_direction
    );

    -- AFTER trigger: the return value is ignored. NULL by convention.
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_nodes_stage_audit
    AFTER UPDATE OF maturity_stage_id ON nodes
    FOR EACH ROW
    EXECUTE FUNCTION fn_audit_node_stage();

-- =====================================================================
-- SECTION 7: QUERIES Q1 - Q9
-- =====================================================================

-- Vocabulary note. The assignment's example questions say "permanent
-- note" and "topic MOC". In this vault those are:
--   permanent note = note_type 'normal' at stage 'teen' or 'adult'
--   topic MOC      = note_type 'topic', the index files under indexes/Topics
--
-- Q3, Q4 and Q7 answer suggested questions 1, 2 and 3.

-- ---------------------------------------------------------------------
-- Q1  LEFT JOIN
-- Which maturity stages have a topic MOC in them, and which stages does
-- no MOC occupy at all?
--
-- ('infant', NULL, NULL, NULL) is the row that exists only because this
-- is a LEFT JOIN; 'adolescent' is the same. No note in the vault sits at
-- either stage. The note_type filter is in the ON clause, not the WHERE
-- clause, which would discard those NULL rows and make this an inner
-- join.
-- ---------------------------------------------------------------------
SELECT
    ms.name AS maturity_stage,
    n.title AS topic_moc,
    n.publish_status,
    n.date_modified::DATE AS last_touched_on
FROM maturity_stages ms
LEFT JOIN nodes n
       ON n.maturity_stage_id = ms.maturity_stage_id
      AND n.note_type = 'topic'
ORDER BY ms.maturity_stage_id, n.title;

-- ---------------------------------------------------------------------
-- Q2  Join through the M:N junction
-- Which published notes are filed under the technical topics, and how
-- mature is each one?
--
-- nodes and topic_tags are many-to-many through node_topics. Neither can
-- answer this alone: nodes knows nothing about topics, topic_tags knows
-- nothing about publish status, and the pairing exists only in the
-- junction row. Filtered on nodes.publish_status and on topic_tags.topic.
-- ---------------------------------------------------------------------
SELECT
    tt.topic,
    n.title AS note_title,
    ms.name AS maturity_stage,
    n.date_created::DATE AS created_on
FROM nodes n
JOIN node_topics nt ON nt.node_id = n.node_id
JOIN topic_tags tt ON tt.topic_tag_id = nt.topic_tag_id
LEFT JOIN maturity_stages ms ON ms.maturity_stage_id = n.maturity_stage_id
WHERE n.publish_status = 'published'
  AND tt.topic IN ('Machine Learning', 'Data Science', 'Computer Science')
ORDER BY tt.topic, n.date_created;

-- ---------------------------------------------------------------------
-- Q3  Set operation (EXCEPT)
-- Which permanent notes has no topic MOC ever linked to?
--
-- I chose EXCEPT because the question is a set difference: every
-- permanent note, minus the ones some MOC points at. Written that way
-- each half is readable on its own. NOT EXISTS returns the same rows but
-- buries the comparison in a correlated subquery, and a self-join on
-- node_links would need an outer join plus IS NULL to say "never".
-- ---------------------------------------------------------------------
SELECT n.title, ms.name AS maturity_stage
FROM nodes n
    JOIN maturity_stages ms ON ms.maturity_stage_id = n.maturity_stage_id
WHERE
    n.note_type = 'normal'
    AND ms.name IN ('teen', 'adult') EXCEPT

SELECT n.title, ms.name
FROM
    nodes n
    JOIN maturity_stages ms ON ms.maturity_stage_id = n.maturity_stage_id
    JOIN node_links l ON l.target_node_id = n.node_id
    JOIN nodes moc ON moc.node_id = l.source_node_id
WHERE
    n.note_type = 'normal'
    AND ms.name IN ('teen', 'adult')
    AND moc.note_type = 'topic'
ORDER BY maturity_stage, title;

-- ---------------------------------------------------------------------
-- Q4  GROUP BY ... HAVING
-- What is the tag distribution across the vault, broken down by content
-- medium? (identity_tag is the medium: lecture, research or my own
-- thought. topic_tags is the tag system that is actually populated.)
--
-- GROUP BY produces 25 groups; HAVING COUNT(*) >= 3 keeps 17 and removes
-- 8, including ('uncategorized', 'Computer Science') at 2 notes and
-- ('research', 'Neuro Science') at 1.
-- ---------------------------------------------------------------------
SELECT
    it.title AS content_medium,
    tt.topic,
    COUNT(*) AS note_count,
    MIN(n.date_created)::DATE AS first_note_on,
    MAX(n.date_created)::DATE AS latest_note_on
FROM nodes n
JOIN identity_tags it ON it.identity_tag_id = n.identity_tag_id
JOIN node_topics nt ON nt.node_id = n.node_id
JOIN topic_tags tt ON tt.topic_tag_id = nt.topic_tag_id
GROUP BY it.title, tt.topic
HAVING COUNT(*) >= 3
ORDER BY note_count DESC, content_medium, tt.topic;

-- ---------------------------------------------------------------------
-- Q5  Aggregate across a LEFT JOIN
-- How many notes sit under each topic, including topics I created and
-- never wrote anything under?
--
-- COUNT(nt.node_topic_id) counts junction rows and ignores NULLs, so the
-- three empty topics come back as 0. COUNT(*) returns 1 for them instead:
-- the LEFT JOIN still emits one row per topic padded with NULLs, and
-- COUNT(*) counts that padding row because it counts rows, not values.
-- ---------------------------------------------------------------------
SELECT
    tt.topic,
    COUNT(nt.node_topic_id) AS note_count,
    COUNT(*) AS rows_returned_by_count_star
FROM topic_tags tt
    LEFT JOIN node_topics nt ON nt.topic_tag_id = tt.topic_tag_id
GROUP BY
    tt.topic_tag_id,
    tt.topic
ORDER BY note_count, tt.topic;

-- ---------------------------------------------------------------------
-- Q6  Subquery
-- Which notes did more outside reading than a typical note in this vault?
--
-- The scalar subquery computes the vault-wide average sources per note,
-- counting the many notes that cite nothing, and the outer query keeps
-- only the notes that beat it. A second scalar subquery in the SELECT
-- list prints that average so the comparison is visible.
-- ---------------------------------------------------------------------
SELECT
    n.title,
    COUNT(ns.source_id) AS sources_cited,
    (
        SELECT ROUND(AVG(per_note.cnt), 2)
        FROM (
                SELECT COUNT(ns2.source_id) AS cnt
                FROM nodes n2
                    LEFT JOIN node_sources ns2 ON ns2.node_id = n2.node_id
                GROUP BY
                    n2.node_id
            ) per_note
    ) AS vault_average
FROM nodes n
    JOIN node_sources ns ON ns.node_id = n.node_id
GROUP BY
    n.node_id,
    n.title
HAVING
    COUNT(ns.source_id) > (
        SELECT AVG(per_note.cnt)
        FROM (
                SELECT COUNT(ns2.source_id) AS cnt
                FROM nodes n2
                    LEFT JOIN node_sources ns2 ON ns2.node_id = n2.node_id
                GROUP BY
                    n2.node_id
            ) per_note
    )
ORDER BY sources_cited DESC, n.title
LIMIT 15;

-- ---------------------------------------------------------------------
-- Q7  Two chained CTEs
-- Which notes never produced anything downstream? A note is a seed:
-- within a month or so, some later note should have linked back to it.
--
-- aged    -- notes created more than 30 days ago, old enough to judge.
-- derived -- reads aged, keeping only links that came from a note written
--            more than 30 days after the note it points at. That date
--            comparison needs the parent's date in hand, which is why it
--            cannot collapse into one query.
-- aged is referenced twice: inside derived and in the outer query.
-- ---------------------------------------------------------------------
WITH aged AS (
    SELECT n.node_id, n.title, n.date_created
    FROM nodes n
    WHERE n.note_type = 'normal'
      AND n.date_created IS NOT NULL
      AND n.date_created < now() - INTERVAL '30 days'
),
derived AS (
    SELECT
        a.node_id AS parent_id,
        MIN(child.date_created) AS first_derived_on
    FROM aged a
    JOIN node_links l ON l.target_node_id = a.node_id
    JOIN nodes child ON child.node_id = l.source_node_id
    WHERE child.date_created > a.date_created + INTERVAL '30 days'
    GROUP BY a.node_id
)
SELECT
    a.title,
    a.date_created::DATE AS created_on,
    DATE_PART('day', now() - a.date_created)::INT AS days_since_created
FROM aged a
LEFT JOIN derived d ON d.parent_id = a.node_id
WHERE d.parent_id IS NULL
ORDER BY a.date_created
LIMIT 20;

-- ---------------------------------------------------------------------
-- Q8  Rank within a partition  (reads the view, calls the function)
-- What are the three healthiest notes under each substantial topic?
--
-- fn_note_health scores each note; RANK() OVER (PARTITION BY topic)
-- numbers notes inside each topic independently, so rank <= 3 gives a
-- top 3 per topic instead of a top 3 overall dominated by Data Science.
-- v_topic_activity supplies the topic totals, which lets the query skip
-- topics with fewer than 10 notes -- a top 3 out of 3 is not a ranking.
-- RANK, not ROW_NUMBER: ties are real and should show as ties.
-- ---------------------------------------------------------------------
WITH
    ranked AS (
        SELECT
            v.topic,
            v.note_count AS topic_note_count,
            n.title,
            fn_note_health (n.node_id) AS health_score,
            RANK() OVER (
                PARTITION BY
                    v.topic_tag_id
                ORDER BY fn_note_health (n.node_id) DESC
            ) AS rank_in_topic
        FROM
            v_topic_activity v
            JOIN node_topics nt ON nt.topic_tag_id = v.topic_tag_id
            JOIN nodes n ON n.node_id = nt.node_id
        WHERE
            v.note_count >= 10
    )
SELECT
    topic,
    topic_note_count,
    rank_in_topic,
    title,
    health_score
FROM ranked
WHERE
    rank_in_topic <= 3
ORDER BY topic, rank_in_topic, title;

-- ---------------------------------------------------------------------
-- Q9  Running total over time
-- How has the vault grown month by month, and how did each content
-- medium contribute?
--
-- The running total accumulates notes created, ordered by the month they
-- were created in, oldest first. running_total_in_medium partitions that
-- accumulation by content medium so each medium climbs its own curve;
-- running_total_all_media is the whole vault. Undated notes are excluded
-- rather than dumped into an arbitrary month.
-- ---------------------------------------------------------------------
WITH monthly AS (
    SELECT
        DATE_TRUNC('month', n.date_created)::DATE AS created_month,
        COALESCE(it.title, 'unclassified') AS content_medium,
        COUNT(*) AS notes_created
    FROM nodes n
    LEFT JOIN identity_tags it ON it.identity_tag_id = n.identity_tag_id
    WHERE n.date_created IS NOT NULL
    GROUP BY 1, 2
)
SELECT
    created_month,
    content_medium,
    notes_created,
    SUM(notes_created) OVER (
        PARTITION BY content_medium
        ORDER BY created_month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_total_in_medium,
    SUM(notes_created) OVER (
        ORDER BY created_month, content_medium
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_total_all_media
FROM monthly
ORDER BY created_month, content_medium;

-- =====================================================================
-- SECTION 8: DEMOS & TRANSACTIONS
-- =====================================================================

-- Notes are looked up by vault_path, not by hardcoded node_id.

-- ---------------------------------------------------------------------
-- Trigger demo: trg_nodes_stage_audit
-- ---------------------------------------------------------------------

-- 1. A stub grows up.
UPDATE nodes
SET
    maturity_stage_id = (
        SELECT maturity_stage_id
        FROM maturity_stages
        WHERE
            name = 'toddler'
    )
WHERE
    vault_path = 'NotakingHub/zettelkasten/Attachment Theory.md';

-- 2. A full rewrite skips a stage: fetus straight to teen.
UPDATE nodes
SET
    maturity_stage_id = (
        SELECT maturity_stage_id
        FROM maturity_stages
        WHERE
            name = 'teen'
    )
WHERE
    vault_path = 'NotakingHub/zettelkasten/Bayes.md';

-- 3. A note marked adult too early goes back down.
UPDATE nodes
SET
    maturity_stage_id = (
        SELECT maturity_stage_id
        FROM maturity_stages
        WHERE
            name = 'teen'
    )
WHERE
    vault_path = 'NotakingHub/zettelkasten/Working Memory.md';

-- 4. A publish-status edit is not a maturity change. The trigger is
--    declared AFTER UPDATE OF maturity_stage_id, so it does not fire.
UPDATE nodes
SET
    publish_status = 'draft'
WHERE
    vault_path = 'NotakingHub/zettelkasten/Bayes.md';

SELECT n.title, old_stage.name AS moved_from, new_stage.name AS moved_to, a.direction
FROM
    node_stage_audit a
    JOIN nodes n ON n.node_id = a.node_id
    LEFT JOIN maturity_stages old_stage ON old_stage.maturity_stage_id = a.old_maturity_stage_id
    LEFT JOIN maturity_stages new_stage ON new_stage.maturity_stage_id = a.new_maturity_stage_id
ORDER BY a.node_stage_audit_id;

-- Expected: three rows, and nothing for the publish_status edit.
--
--       title       | moved_from | moved_to | direction
-- ------------------+------------+----------+-----------
--  Attachment Theory| fetus      | toddler  | promoted
--  Bayes            | fetus      | teen     | promoted
--  Working Memory   | adult      | teen     | demoted
-- (3 rows)

-- ---------------------------------------------------------------------
-- T1: the transaction that commits
--
-- If the server lost power between statement 1 and statement 2, the
-- database would claim that a book by Bowlby is sitting in my source list
-- having been read for no note in particular, while 'Attachment Theory'
-- still cites nothing at all, which is false.
-- ---------------------------------------------------------------------

SELECT COUNT(*) AS sources_before
FROM node_sources ns
    JOIN nodes n ON n.node_id = ns.node_id
WHERE
    n.vault_path = 'NotakingHub/zettelkasten/Attachment Theory.md';
-- before: 0

BEGIN;

-- 1. The source enters the library.
INSERT INTO
    sources (
        source_type,
        title,
        link,
        author
    )
VALUES (
        'book',
        'A Secure Base: Parent-Child Attachment and Healthy Human Development',
        NULL,
        'Bowlby, J.'
    );

-- 2. The note that sent me to it now cites it.
INSERT INTO
    node_sources (node_id, source_id)
VALUES (
        (
            SELECT node_id
            FROM nodes
            WHERE
                vault_path = 'NotakingHub/zettelkasten/Attachment Theory.md'
        ),
        (
            SELECT source_id
            FROM sources
            WHERE
                title = 'A Secure Base: Parent-Child Attachment and Healthy Human Development'
        )
    );

-- 3. The note was edited, so its timestamp moves. Same unit of work.
UPDATE nodes
SET
    date_modified = now()
WHERE
    vault_path = 'NotakingHub/zettelkasten/Attachment Theory.md';

COMMIT;

SELECT s.title AS source_title, s.author, n.date_modified::DATE AS note_touched_on
FROM node_sources ns
JOIN nodes n ON n.node_id = ns.node_id
JOIN sources s ON s.source_id = ns.source_id
WHERE n.vault_path = 'NotakingHub/zettelkasten/Attachment Theory.md';
-- after: 1 row

-- ---------------------------------------------------------------------
-- T2: the transaction that rolls back
--
-- The rule: a note may not reach 'adult' until it cites at least one
-- source and links out to at least two other notes. That is a rule about
-- a note's whole neighbourhood, so no CHECK can enforce it -- a CHECK
-- sees one row of one table and cannot count rows in another. The count
-- has to happen after the writes, inside the transaction.
--
-- If the server lost power between statement 1 and statement 2, the
-- database would claim that 'MasteryCalculation' is a finished, adult
-- note that connects to nothing at all, which is false.
-- ---------------------------------------------------------------------

BEGIN;

-- 1. Promote it. This also fires the audit trigger.
UPDATE nodes
SET
    maturity_stage_id = (
        SELECT maturity_stage_id
        FROM maturity_stages
        WHERE
            name = 'adult'
    )
WHERE
    vault_path = 'NotakingHub/zettelkasten/MasteryCalculation.md';

-- 2. Connect it to the theory note it is calculating from.
INSERT INTO
    node_links (
        source_node_id,
        target_node_id,
        link_type
    )
VALUES (
        (
            SELECT node_id
            FROM nodes
            WHERE
                vault_path = 'NotakingHub/zettelkasten/MasteryCalculation.md'
        ),
        (
            SELECT node_id
            FROM nodes
            WHERE
                vault_path = 'NotakingHub/zettelkasten/Mastery Learning.md'
        ),
        'derived_from'
    );

-- Read our own uncommitted work. Nobody outside this transaction can see
-- either write yet. One link and no sources is below the bar for 'adult'.
SELECT
    ms.name AS stage_now,
    (
        SELECT COUNT(*)
        FROM node_links l
        WHERE
            l.source_node_id = n.node_id
    ) AS outgoing_links,
    (
        SELECT COUNT(*)
        FROM node_sources s
        WHERE
            s.node_id = n.node_id
    ) AS sources_cited
FROM nodes n
    JOIN maturity_stages ms ON ms.maturity_stage_id = n.maturity_stage_id
WHERE
    n.vault_path = 'NotakingHub/zettelkasten/MasteryCalculation.md';
-- inside the transaction: adult | 1 | 0   -> rule broken, back it out

ROLLBACK;

-- Everything is undone, not just the promotion: the link is gone and so
-- is the audit row the trigger wrote.
SELECT
    ms.name AS stage_now,
    (
        SELECT COUNT(*)
        FROM node_links l
        WHERE
            l.source_node_id = n.node_id
    ) AS outgoing_links,
    (
        SELECT COUNT(*)
        FROM node_stage_audit a
        WHERE
            a.node_id = n.node_id
    ) AS audit_rows
FROM nodes n
    JOIN maturity_stages ms ON ms.maturity_stage_id = n.maturity_stage_id
WHERE
    n.vault_path = 'NotakingHub/zettelkasten/MasteryCalculation.md';
-- after the rollback: teen | 0 | 0