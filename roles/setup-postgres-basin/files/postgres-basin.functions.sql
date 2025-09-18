
-- # create functions

-- Create a function per shadow table to properly split the infos
--- (let's keep tracking every update in the shadow table, if needed
--- later, a redundancy field could be added to call out unchanged
--- versions...)
CREATE OR REPLACE FUNCTION perform_insert_projects(
    in_name TEXT,
    in_uri TEXT,
    in_uuid UUID DEFAULT NULL,
    in_meta JSONB DEFAULT NULL,
    in_the_user TEXT DEFAULT NULL -- editing user (overridable in apps...)
) RETURNS INTEGER AS $$
DECLARE
    project_id INTEGER;
    uuid_ UUID;
    latest_version INTEGER;
    created_ts TIMESTAMPTZ;
    the_user TEXT;
BEGIN
    -- Try to find existing id and max version via UUID
    SELECT id, uuid, version, created
    INTO project_id, uuid_, latest_version, created_ts
    FROM shadow_projects
    WHERE uri = in_uri
    ORDER BY version DESC
    LIMIT 1;

    IF in_uuid IS NULL THEN
        uuid_ := gen_random_uuid();
    ELSE
        uuid_ := in_uuid;
    END IF;

    IF in_the_user IS NULL THEN
        the_user := SESSION_USER;
    ELSE
        the_user := in_the_user;
    END IF;

    IF project_id IS NULL THEN
        -- Create new anchor
        INSERT INTO projects(version, uri, name, uuid)
        VALUES (0, in_uri, in_name, uuid_)
        RETURNING id INTO project_id;

        latest_version := 0;
        created_ts := CURRENT_TIMESTAMP;
    ELSE
        -- Prepare next version
        latest_version := latest_version + 1;

        -- Update pointer
        UPDATE projects
            SET
                version = latest_version,
                uri = in_uri,
                name = in_name,
                uuid = uuid_
         WHERE id = project_id;
    END IF;

    -- Insert new shadow row
    INSERT INTO shadow_projects (
        id, version, uri, name, uuid,
        meta, created, lastmodifieddate, lastmodifieduser
    )
    VALUES (
        project_id, latest_version, in_uri, in_name, uuid_,
        in_meta, created_ts, CURRENT_TIMESTAMP, the_user
    );

    RETURN project_id;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION perform_insert_persons(
    in_name TEXT,
    in_uri TEXT,
    in_uuid UUID DEFAULT NULL,
    in_extid TEXT DEFAULT NULL,
    in_exttype TEXT DEFAULT NULL,
    in_isnatural BOOLEAN DEFAULT True,
    in_the_user TEXT DEFAULT NULL -- editing user (overridable in apps...)
) RETURNS INTEGER AS $$
DECLARE
    person_id INTEGER;
    latest_version INTEGER;
    created_ts TIMESTAMPTZ;
    the_user TEXT;
BEGIN
    -- Try to find existing id and max version via UUID
    SELECT id, version, created
    INTO person_id, latest_version, created_ts
    FROM shadow_persons
    WHERE uri = in_uri
    ORDER BY version DESC
    LIMIT 1;

    IF in_the_user IS NULL THEN
        the_user := SESSION_USER;
    ELSE
        the_user := in_the_user;
    END IF;

    IF person_id IS NULL THEN
        -- Create new anchor
        INSERT INTO persons(version, uri, name, uuid)
        VALUES (0, in_uri, in_name, in_uuid)
        RETURNING id INTO person_id;

        latest_version := 0;
        created_ts := CURRENT_TIMESTAMP;
    ELSE
        -- Prepare next version
        latest_version := latest_version + 1;

        -- Update pointer
        UPDATE persons
            SET
                version = latest_version,
                uri = in_uri,
                name = in_name,
                uuid = in_uuid
        WHERE id = person_id;
    END IF;

    -- Insert new shadow row
    INSERT INTO shadow_persons (
        id, version, uri, name, uuid,
        extid, extidtype, isnatural,
        created, lastmodifieddate, lastmodifieduser
    )
    VALUES (
        person_id, latest_version, in_uri, in_name, in_uuid,
        in_extid, in_extidtype, in_isnatural,
        created_ts, CURRENT_TIMESTAMP, the_user
    );

    RETURN person_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION perform_insert_contacts(
    in_name TEXT,
    in_uri TEXT,
    in_uuid UUID DEFAULT NULL,
    in_icard TEXT DEFAULT NULL,
    in_the_user TEXT DEFAULT NULL -- editing user (overridable in apps...)
) RETURNS INTEGER AS $$
DECLARE
    contact_id INTEGER;
    latest_version INTEGER;
    created_ts TIMESTAMPTZ;
    the_user TEXT;
BEGIN
    -- Try to find existing id and max version via UUID
    SELECT id, version, created
    INTO contact_id, latest_version, created_ts
    FROM shadow_contacts
    WHERE uuid = in_uuid
    ORDER BY version DESC
    LIMIT 1;

    IF in_the_user IS NULL THEN
        the_user := SESSION_USER;
    ELSE
        the_user := in_the_user;
    END IF;

    IF contact_id IS NULL THEN
        -- Create new anchor
        INSERT INTO contacts(version, uri, name, uuid)
        VALUES (0, in_uri, in_name, in_uuid)
        RETURNING id INTO contact_id;

        latest_version := 0;
        created_ts := CURRENT_TIMESTAMP;
    ELSE
        -- Prepare next version
        latest_version := latest_version + 1;

        -- Update pointer
        UPDATE contacts
            SET
                version = latest_version,
                uri = in_uri,
                name = in_name,
                uuid = in_uuid
        WHERE id = contact_id;
    END IF;

    -- Insert new shadow row
    INSERT INTO shadow_contacts (
        id, version, uri, name, uuid,
        icard,
        created, lastmodifieddate, lastmodifieduser
    )
    VALUES (
        contact_id, latest_version, in_uri, in_name, in_uuid,
        in_icard,
        created_ts, CURRENT_TIMESTAMP, the_user
    );

    RETURN contact_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION perform_insert_users(
    in_name TEXT,
    in_uri TEXT,
    in_email TEXT,
    in_passhash TEXT DEFAULT NULL,
    in_idtoken TEXT DEFAULT NULL,
    in_idtokenhash TEXT DEFAULT NULL,
    in_idtokentype VARCHAR(16) DEFAULT NULL,
    in_the_user TEXT DEFAULT NULL -- editing user (overridable in apps...)
) RETURNS INTEGER AS $$
DECLARE
    user_id INTEGER;
    realperson_id INTEGER;
    latest_version INTEGER;
    created_ts TIMESTAMPTZ;
    the_user TEXT;
BEGIN
    -- Try to link to an existing person first
    SELECT id INTO realperson_id
    FROM persons
    WHERE uri = in_uri -- URI is the same for user and person..
    LIMIT 1;

    IF in_the_user IS NULL THEN
        the_user := SESSION_USER;
    ELSE
        the_user := in_the_user;
    END IF;

    -- Try to find existing id and max version via UUID
    SELECT id, version, created
    INTO user_id, latest_version, created_ts
    FROM shadow_users
    WHERE uuid = in_uuid
    ORDER BY version DESC
    LIMIT 1;

    IF user_id IS NULL THEN
        -- Create new anchor
        INSERT INTO users(version)
        VALUES (0, in_uri, in_name, in_uuid)
        RETURNING id INTO user_id;

        latest_version := 0;
        created_ts := CURRENT_TIMESTAMP;
    ELSE
        -- Prepare next version
        latest_version := latest_version + 1;

        -- Update pointer
        UPDATE users
            SET
                version = latest_version,
                uri = in_uri,
                name = in_name,
                uuid = in_uuid
        WHERE id = user_id;
    END IF;

    -- Insert new shadow row
    INSERT INTO shadow_users (
        id, version, name,
        email, passhash, idtoken, idtokenhash,
        idtokentype, realpersonid,
        created, lastmodifieddate, lastmodifieduser
    )
    VALUES (
        user_id, latest_version, in_name,
        in_email, in_passhash, in_idtoken, in_idtokenhash,
        in_idtokentype, realperson_id,
        created_ts, CURRENT_TIMESTAMP, the_user
    );

    RETURN user_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION perform_insert_roles(
    in_name TEXT,
    in_project_uuid UUID,
    in_uri TEXT DEFAULT NULL,
    in_isowner BOOLEAN DEFAULT False,
    in_canread BOOLEAN DEFAULT False,
    in_canedit BOOLEAN DEFAULT False,
    in_cancreate BOOLEAN DEFAULT False,
    in_candelete BOOLEAN DEFAULT False,
    in_cangrant BOOLEAN DEFAULT False,
    in_the_user TEXT DEFAULT NULL -- editing user (overridable in apps...)
) RETURNS INTEGER AS $$
DECLARE
    role_id INTEGER;
    project_id INTEGER;
    latest_version INTEGER;
    created_ts TIMESTAMPTZ;
    the_user TEXT;
BEGIN
    -- First verify the mandatory project affiliation
    SELECT id INTO project_id
    FROM projects
    WHERE uuid = in_project_uuid
    LIMIT 1;

    IF in_the_user IS NULL THEN
        the_user := SESSION_USER;
    ELSE
        the_user := in_the_user;
    END IF;

    IF project_id IS NULL THEN
        RAISE EXCEPTION 'Project for role "%" not found, UUID: "%"',
            in_name, in_project_uuid;
    END IF;

    -- Try to find existing id and max version via UUID
    SELECT id, version, created
    INTO role_id, latest_version, created_ts
    FROM shadow_roles
    WHERE uuid = in_uuid
    ORDER BY version DESC
    LIMIT 1;

    IF role_id IS NULL THEN
        -- Create new anchor
        INSERT INTO roles(version)
        VALUES (0, in_uri, in_name)
        RETURNING id INTO role_id;

        latest_version := 0;
        created_ts := CURRENT_TIMESTAMP;
    ELSE
        -- Prepare next version
        latest_version := latest_version + 1;

        -- Update pointer
        UPDATE roles
            SET
                version = latest_version,
                uri = in_uri,
                name = in_name
        WHERE id = role_id;
    END IF;

    -- Insert new shadow row
    INSERT INTO shadow_roles (
        id, version, name, uri,
        projectid, isowner,
        canread, canedit, cancreate, cangrant,
        created, lastmodifieddate, lastmodifieduser
    )
    VALUES (
        role_id, latest_version, in_name, in_uri,
        project_id, in_isowner,
        in_canread, in_canedit, in_cancreate, in_cangrant,
        created_ts, CURRENT_TIMESTAMP, the_user
    );

    RETURN role_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION perform_insert_sourcetypes(
    in_name TEXT,
    in_uuid UUID,
    in_uri TEXT DEFAULT NULL,
    in_class TEXT DEFAULT NULL,
    in_devicetype TEXT DEFAULT NULL,
    in_realmname TEXT DEFAULT NULL,
    in_realmuuid UUID DEFAULT NULL,
    in_project_uuid UUID DEFAULT NULL,
    in_contentencoding VARCHAR(32) DEFAULT NULL,
    in_contenttype VARCHAR(32) DEFAULT NULL,
    in_contentrdfxtypes TEXT DEFAULT NULL,
    in_unit VARCHAR(16) DEFAULT NULL,
    in_unitencoding VARCHAR(16) DEFAULT NULL,
    in_tolerance INTEGER DEFAULT NULL,
    in_meta JSONB DEFAULT NULL,
    in_the_user TEXT DEFAULT NULL -- editing user (overridable in apps...)
) RETURNS INTEGER AS $$
DECLARE
    sourcetype_id INTEGER;
    global_sourcetype_id INTEGER;
    project_id INTEGER;
    latest_version INTEGER;
    global_latest_version INTEGER;
    created_ts TIMESTAMPTZ;
    global_created_ts TIMESTAMPTZ;
    the_user TEXT;
BEGIN
    -- First handle the optional project (or global) scope
    IF in_project_uuid IS NOT NULL THEN
        SELECT id INTO project_id
        FROM projects
        WHERE uuid = in_project_uuid
        LIMIT 1;

        -- Try to find existing id and max version via UUID in local scope
        SELECT id, version, created
        INTO sourcetype_id, latest_version, created_ts
        FROM shadow_sourcetypes
        WHERE uuid = in_uuid AND projectid IS NOT DISTINCT FROM project_id
        ORDER BY version DESC
        LIMIT 1;
    ELSE
        project_id := NULL;
    END IF;

    -- Try to find existing id and max version via UUID in global scope
    SELECT id, version, created
    INTO global_sourcetype_id, global_latest_version, global_created_ts
    FROM shadow_sourcetypes
    WHERE uuid = in_uuid AND projectid IS NULL
    ORDER BY version DESC
    LIMIT 1;

    IF in_the_user IS NULL THEN
        the_user := SESSION_USER;
    ELSE
        the_user := in_the_user;
    END IF;

    IF global_sourcetype_id IS NULL THEN
        IF project_id IS NOT NULL THEN
            -- Create new local anchor
            INSERT INTO sourcetypes(version, uri, name, uuid)
            VALUES (0, in_uri, in_name, in_uuid)
            RETURNING id INTO sourcetype_id;

            latest_version := 0;
            created_ts := CURRENT_TIMESTAMP;
        END IF;

        -- Create new global anchor
        INSERT INTO sourcetypes(version, uri, name, uuid)
        VALUES (0, in_uri, in_name, in_uuid)
        RETURNING id INTO global_sourcetype_id;

        global_latest_version := 0;
        global_created_ts := CURRENT_TIMESTAMP;
    ELSE
        -- Update local anchor
        IF project_id IS NOT NULL THEN
            -- Prepare next version
            latest_version := latest_version + 1;

            -- Update pointer
            UPDATE sourcetypes
                SET
                    version = latest_version,
                    uri = in_uri,
                    name = in_name,
                    uuid = in_uuid
            WHERE id = sourcetype_id;
        END IF;

        -- Udate global anchor
        -- Prepare next version
        global_latest_version := global_latest_version + 1;

        -- Update pointer
        UPDATE sourcetypes
            SET
                version = global_latest_version,
                uri = in_uri,
                name = in_name,
                uuid = in_uuid
        WHERE id = global_sourcetype_id;
    END IF;

    IF project_id IS NOT NULL THEN
        -- Insert new local shadow row
        INSERT INTO shadow_sourcetypes (
            id, version, uri, name, uuid,
            class, devicetype, realmname, realmuuid, projectid,
            contentencoding, contenttype, contentrdfxtypes,
            unit, unitencoding, tolerance, meta,
            created, lastmodifieddate, lastmodifieduser
        )
        VALUES (
            sourcetype_id, latest_version, in_uri, in_name, in_uuid,
            in_class, in_devicetype, in_realmname, in_realmuuid, project_id,
            in_contentencoding, in_contenttype, in_contentrdfxtypes,
            in_unit, in_unitencoding, in_tolerance, in_meta,
            created_ts, CURRENT_TIMESTAMP, the_user
        );
    END IF;

    -- Insert new global shadow row
    INSERT INTO shadow_sourcetypes (
        id, version, uri, name, uuid,
        class, devicetype, realmname, realmuuid, projectid,
        contentencoding, contenttype, contentrdfxtypes,
        unit, unitencoding, tolerance, meta,
        created, lastmodifieddate, lastmodifieduser
    )
    VALUES (
        global_sourcetype_id, global_latest_version, in_uri, in_name, in_uuid,
        in_class, in_devicetype, in_realmname, in_realmuuid, NULL,
        in_contentencoding, in_contenttype, in_contentrdfxtypes,
        in_unit, in_unitencoding, in_tolerance, in_meta,
        global_created_ts, CURRENT_TIMESTAMP, the_user
    );

    IF project_id IS NOT NULL THEN
        RETURN sourcetype_id;
    ELSE
        RETURN global_sourcetype_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION perform_insert_sources(
    in_name TEXT,
    in_uuid UUID,
    in_parent_uuid UUID,
    in_project_uuid UUID,
    in_sourcetype_uuid UUID,
    in_uri TEXT DEFAULT NULL,
    in_path LTREE DEFAULT NULL,
    in_extid TEXT DEFAULT NULL,
    in_context TEXT DEFAULT NULL,
    in_alt DOUBLE PRECISION DEFAULT NULL,
    in_lat DOUBLE PRECISION DEFAULT NULL,
    in_lon DOUBLE PRECISION DEFAULT NULL,
    in_mapzoom INTEGER DEFAULT NULL,
    in_geohash VARCHAR(12) DEFAULT NULL,
    in_timezone TEXT DEFAULT NULL,
    in_startdate TIMESTAMPTZ DEFAULT NULL,
    in_stopdate TIMESTAMPTZ DEFAULT NULL,
    in_samplerate INTEGER DEFAULT NULL,
    in_meta JSONB DEFAULT NULL,
    in_maintainer_uri TEXT DEFAULT NULL,
    in_softwareversion TEXT DEFAULT NULL,
    in_hardwareversion TEXT DEFAULT NULL,
    in_the_user TEXT DEFAULT NULL -- editing user (overridable in apps...)
) RETURNS INTEGER AS $$
DECLARE
    source_id INTEGER;
    project_id INTEGER;
    sourcetype_id INTEGER;
    parent_source_id INTEGER;
    uri_ TEXT;
    uri__ TEXT;
    maintainer_person_id INTEGER;
    latest_version INTEGER;
    created_ts TIMESTAMPTZ;
    the_user TEXT;
BEGIN
    -- First verify the mandatory project affiliation
    SELECT id INTO project_id
    FROM projects
    WHERE uuid = in_project_uuid
    LIMIT 1;

    IF in_the_user IS NULL THEN
        the_user := SESSION_USER;
    ELSE
        the_user := in_the_user;
    END IF;

    IF project_id IS NULL THEN
        RAISE EXCEPTION 'Project for source "%" not found, UUID: "%"',
            in_name, in_project_uuid;
    END IF;

    -- Every source is expected to have a corresponding type entry
    SELECT id, uri INTO sourcetype_id, uri_
    FROM sourcetypes
    WHERE uuid = in_sourcetype_uuid
    LIMIT 1;

    IF sourcetype_id IS NULL THEN
        RAISE EXCEPTION 'Sourcetype for source "%" not found, UUID: "%"',
            in_name, in_sourcetype_uuid;
    END IF;

    -- Try to link to an existing parent source first
    IF in_parent_uuid IS NOT NULL THEN
        SELECT id, uri INTO parent_source_id, uri__
        FROM sources
        WHERE uuid = in_parent_uuid
        LIMIT 1;

        IF parent_source_id IS NULL THEN
            RAISE EXCEPTION 'Parent for source "%" not found, UUID: "%"',
                in_name, in_sources_uuid;
        END IF;
    END IF;

    -- Set uri_ to either input, or sourcetype.uri; fall back to parent.uri
    IF in_uri IS NULL THEN
        IF uri_ IS NULL THEN
            uri_ := uri__;
        END IF;
    ELSE
        uri_ := in_uri;
    END IF;

    -- Try to link to an existing person first
    IF in_maintainer_uri IS NOT NULL THEN
        SELECT id INTO maintainer_person_id
        FROM persons
        WHERE uri = in_maintainer_uri
        LIMIT 1;

        IF maintainer_person_id IS NULL THEN
            RAISE EXCEPTION 'Maintainer for source "%" not found, UUID: "%"',
                in_name, in_maintainer_uri;
        END IF;
    END IF;

    -- Try to find existing id and max version via UUID
    SELECT id, version, created
    INTO source_id, latest_version, created_ts
    FROM shadow_sources
    WHERE uuid = in_uuid
    ORDER BY version DESC
    LIMIT 1;

    IF source_id IS NULL THEN
        -- Create new anchor
        INSERT INTO sources(version, uri, name, uuid, projectid)
        VALUES (0, uri_, in_name, in_uuid, project_id)
        RETURNING id INTO source_id;

        latest_version := 0;
        created_ts := CURRENT_TIMESTAMP;
    ELSE
        -- Prepare next version
        latest_version := latest_version + 1;

        -- Update pointer
        UPDATE sources
            SET
                version = latest_version,
                uri = uri_,
                name = in_name,
                uuid = in_uuid,
                projectid = project_id
        WHERE id = source_id;
    END IF;

    -- Insert new shadow row
    INSERT INTO shadow_sources (
        id, version, uuid, name, uri,
        extid, path, context, sourcetypeid,
        projectid, parentid,
        alt, lat, lon, mapzoom, geohash,
        timezone, startdate, stopdate, samplerate,
        meta, maintainerpersonid,
        softwareversion, hardwareversion,
        created, lastmodifieddate, lastmodifieduser
    )
    VALUES (
        source_id, latest_version, in_uuid, in_name, uri_,
        in_extid, in_path, in_context, sourcetype_id,
        project_id, parent_source_id,
        in_alt, in_lat, in_lon, in_mapzoom, in_geohash,
        in_timezone, in_startdate, in_stopdate, in_samplerate,
        in_meta, maintainer_person_id,
        in_softwareversion, in_hardwareversion,
        created_ts, CURRENT_TIMESTAMP, the_user
    );

    RETURN source_id;
END;
$$ LANGUAGE plpgsql;

-- Create some functions to check for anchor/shadow coherence
-- 1. return a table with the id-version pairs missing (hopefully empty)
CREATE OR REPLACE FUNCTION check_shadow_differences(anchor_table TEXT, shadow_table TEXT)
RETURNS TABLE(id INTEGER, version INTEGER) AS $$
DECLARE
    sql TEXT;
BEGIN
    -- Validate that both tables exist
    IF NOT EXISTS (
        SELECT 1 FROM pg_class WHERE relname = anchor_table AND relkind = 'r'
    ) THEN
        RAISE EXCEPTION 'Anchor table "%" does not exist.', anchor_table;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_class WHERE relname = shadow_table AND relkind = 'r'
    ) THEN
        RAISE EXCEPTION 'Shadow table "%" does not exist.', shadow_table;
    END IF;

    -- Build the query
    sql := format('SELECT a.id, a.version
            FROM %I a
       LEFT JOIN %I s
              ON a.id = s.id AND a.version = s.version
         WHERE s.id IS NULL',
        anchor_table,
        shadow_table
    );

    RETURN QUERY EXECUTE sql;
END;
$$ LANGUAGE plpgsql;

-- 2. verify that the table from above really is empty..
CREATE OR REPLACE FUNCTION shadow_is_consistent(anchor_table TEXT, shadow_table TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    mismatch_count INTEGER;
BEGIN
    -- Count the number of missing entries by querying the first function
    SELECT COUNT(*) INTO mismatch_count
    FROM check_shadow_differences(anchor_table, shadow_table);

    -- True = everything matched
    RETURN mismatch_count = 0;
END;
$$ LANGUAGE plpgsql;

-- 3. complain if the above two tests fail for any of our table pairs.
CREATE OR REPLACE FUNCTION enforce_shadow_consistency()
RETURNS VOID AS $$
BEGIN
    -- Example: Projects
    IF NOT shadow_is_consistent('projects', 'shadow_projects') THEN
        RAISE EXCEPTION 'Shadow inconsistency detected in table "projects"';
    END IF;

    -- Example: Persons
    IF NOT shadow_is_consistent('persons', 'shadow_persons') THEN
        RAISE EXCEPTION 'Shadow inconsistency detected in table "persons"';
    END IF;

    -- Example: Contacts
    IF NOT shadow_is_consistent('contacts', 'shadow_contacts') THEN
        RAISE EXCEPTION 'Shadow inconsistency detected in table "contacts"';
    END IF;

    -- Example: Users
    IF NOT shadow_is_consistent('users', 'shadow_users') THEN
        RAISE EXCEPTION 'Shadow inconsistency detected in table "users"';
    END IF;

    -- Example: Roles
    IF NOT shadow_is_consistent('roles', 'shadow_roles') THEN
        RAISE EXCEPTION 'Shadow inconsistency detected in table "roles"';
    END IF;

    -- Example: Sourcetypes
    IF NOT shadow_is_consistent('sourcetypes', 'shadow_sourcetypes') THEN
        RAISE EXCEPTION 'Shadow inconsistency detected in table "sourcetypes"';
    END IF;

    -- Example: Sources
    IF NOT shadow_is_consistent('sources', 'shadow_sources') THEN
        RAISE EXCEPTION 'Shadow inconsistency detected in table "sources"';
    END IF;

    RAISE NOTICE 'Shadow consistency verified for all checked tables.';
END;
$$ LANGUAGE plpgsql;

-- 4. now, let's call it from pg_cron..?

-- Create functions to handle the LTREE path in shadow_sources
CREATE OR REPLACE FUNCTION ltree_sanitize_label(in_name TEXT)
RETURNS TEXT AS $$
DECLARE
    clean_name TEXT;
BEGIN
    -- Replace all illegal characters with _
    clean_name := regexp_replace(in_name, '[^A-Za-z0-9_]', '_', 'g');

    -- Ensure it doesn't start with a digit (prefix _ if so)
    IF clean_name ~ '^[0-9]' THEN
        clean_name := '_' || clean_name;
    END IF;

    -- Optional: lower-case it
    clean_name := lower(clean_name);

    RETURN clean_name;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;

-- used once to clean up..
-- UPDATE shadow_sources
-- SET path = (
--     SELECT path || ltree_sanitize_label(my_table.name)
--    FROM sources parent
--    WHERE parent.id = sources.parentid
-- )
-- WHERE parentid IS NOT NULL;

CREATE OR REPLACE FUNCTION update_ltree_path()
RETURNS TRIGGER AS $$
DECLARE
    parent_path LTREE;
    self_label TEXT;
BEGIN
    -- Sanitize the current name
    self_label := ltree_sanitize_label(NEW.name);

    -- If no parent, this is a root node
    IF NEW.parentid IS NULL THEN
        NEW.path := self_label::ltree;

    ELSE
        -- Get parent's path
        SELECT path INTO parent_path
        FROM shadow_sources
        WHERE id = NEW.parentid
        ORDER BY version DESC
        LIMIT 1;

        IF parent_path IS NULL THEN
            RAISE EXCEPTION
                'Parent with id % has no path set yet.', NEW.parentid;
        END IF;

        -- Build full path
        NEW.path := parent_path || self_label;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create a function to manage partitions and subpartitions
CREATE OR REPLACE FUNCTION manage_recordings_partitions()
RETURNS void AS $$
DECLARE
    current_year INTEGER;
    next_year INTEGER;
    project_id INTEGER;
    partition_name TEXT;
    subpartition_name TEXT;
BEGIN
    current_year := EXTRACT(YEAR FROM CURRENT_DATE);
    next_year := current_year + 1;

    -- Loop through all project IDs
    FOR project_id IN SELECT DISTINCT id FROM projects
    LOOP
        -- Create the partition for the projectid if it does not exixt
        partition_name := 'recordings_projectid' || project_id;
        IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = partition_name) THEN
            EXECUTE 'CREATE TABLE ' || partition_name || ' PARTITION OF recordings FOR VALUES IN (' || project_id || ') PARTITION BY RANGE (timestamp)';
        END IF;

        -- Create the sub-partition for the current year if it does not exist
        subpartition_name := 'recordings_projectid' || project_id || '_year' || TO_CHAR(current_year, 'FM0000');
        IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = subpartition_name) THEN
            EXECUTE 'CREATE TABLE ' || subpartition_name || ' PARTITION OF ' || partition_name || ' FOR VALUES FROM (''' || TO_CHAR(current_year, 'FM0000') || '-01-01'') TO (''' || TO_CHAR(current_year + 1, 'FM0000') || '-01-01'')';
        END IF;

        -- Create the sub-partition for the next year if it does not exist
        subpartition_name := 'recordings_projectid' || project_id || '_year' || TO_CHAR(next_year, 'FM0000');
        IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = subpartition_name) THEN
            EXECUTE 'CREATE TABLE ' || subpartition_name || ' PARTITION OF ' || partition_name || ' FOR VALUES FROM (''' || TO_CHAR(next_year, 'FM0000') || '-01-01'') TO (''' || TO_CHAR(next_year + 1, 'FM0000') || '-01-01'')';
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- new projects create recording partitions
CREATE OR REPLACE FUNCTION insert_project_post_process()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM manage_recordings_partitions();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- processing staged recordings and clean up or warn
CREATE OR REPLACE FUNCTION process_staged_recordings()
RETURNS VOID AS $$
DECLARE
    staging_valid_ids INTEGER[];
    staging_invalid_ids INTEGER[];
BEGIN
    -- Warn on 'many' staging table entries (queue).
    IF (SELECT COUNT(*) FROM recordings_staging) > 10000 THEN
        RAISE WARNING 'Too many entries in staging table, consider increasing interval or optimizing job';
    END IF;
    -- Create a lock file to block new processes, resp. quit if another process is running..
    PERFORM pg_advisory_lock(1);

    BEGIN
    -- Select the IDs of the valid and invalid records
        SELECT array_agg(rs.id) INTO staging_valid_ids
        FROM recordings_staging rs
        WHERE EXISTS (
            SELECT 1
            FROM sources s
            WHERE s.uuid = rs.sourceuuid
        ) AND (rs.value IS NOT NULL OR rs.altvalue IS NOT NULL)
          AND rs.timestamp IS NOT NULL AND rs.sourceuuid IS NOT NULL;

        -- Identify invalid (orphaned) records
        SELECT array_agg(id) INTO staging_invalid_ids
        FROM recordings_staging rs
        WHERE NOT EXISTS (
            SELECT 1
            FROM sources s
            WHERE s.uuid = rs.sourceuuid
        );

        -- Insert matching data into recordings table
        INSERT INTO recordings (
            timestamp, value, altvalue, lat, lon, alt,
            geohash, projectid, sourceid, meta
        )
        SELECT
            rs.timestamp, rs.value, rs.altvalue, rs.lat, rs.lon, rs.alt,
            rs.geohash, s.projectid, s.id, rs.meta
        FROM recordings_staging rs
        JOIN sources s ON rs.sourceuuid = s.uuid
        WHERE rs.id = ANY(staging_valid_ids)
        ON CONFLICT (timestamp, projectid, sourceid) DO NOTHING;

        -- Insert non-matching data into _recordings_orphaned table
        INSERT INTO _recordings_orphaned (
            timestamp, value, altvalue, lat, lon, alt,
            geohash, sourceuuid, meta
        )
        SELECT
            rs.timestamp, rs.value, rs.altvalue, rs.lat, rs.lon, rs.alt,
            rs.geohash, rs.sourceuuid, rs.meta
        FROM recordings_staging rs
        WHERE rs.id = ANY(staging_invalid_ids);

        -- Delete the processed records from the staging table
        DELETE FROM recordings_staging
        WHERE id = ANY(staging_valid_ids) OR id = ANY(staging_invalid_ids);
    EXCEPTION
        WHEN foreign_key_violation THEN
            RAISE WARNING 'Foreign key violation: %', SQLERRM;
        WHEN invalid_table_definition THEN
            RAISE WARNING 'Invalid table definition: %', SQLERRM;
        WHEN OTHERS THEN
            RAISE WARNING 'Error: %', SQLERRM;
    END;
    -- Clean up lock file
    PERFORM pg_advisory_unlock(1);
END;
$$ LANGUAGE plpgsql;



