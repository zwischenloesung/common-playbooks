-- # create roles and permissions

-- TODO:
-- The uncommented roles are not yet used and are candidates for
-- policy based IAM in a hybrid setup, so we might want to create
-- a template here and make it optional, resp. configurable.
-- The supplier and the main_admin at least, will remain role based
-- for the supplier we do not want too much overhead, the main_admin
-- should be as low tech as possible, IMO.

-- idempotent version..
DO $$
BEGIN
    -- admin role with local super powers
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'main_admin') THEN
        CREATE ROLE main_admin;
    END IF;
    -- omni project - roles with access to all projects
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'omni_admin') THEN
        -- projects admin role with lots of privledges
        CREATE ROLE omni_admin;
    END IF;
--    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'omni_reader') THEN
        -- role to read most information
--        CREATE ROLE omni_reader;
--    END IF;
--    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'omni_creator') THEN
        -- role to also add information
--        CREATE ROLE omni_creator;
--    END IF;
--    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'omni_editor') THEN
        -- role to edit existing information
--        CREATE ROLE omni_editor;
--    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'omni_supplier') THEN
        -- role to only add recordings to the staging area
        CREATE ROLE omni_supplier;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'omni_consumer') THEN
        -- role to read by views
        CREATE ROLE omni_consumer;
    END IF;
END $$;

-- revoke permissions
REVOKE ALL ON SCHEMA public FROM
    omni_reader,
    omni_creator,
    omni_editor,
    omni_supplier,
    omni_consumer;

-- persons permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON persons TO main_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON persons TO omni_admin;
--GRANT SELECT ON persons TO omni_reader;
--GRANT INSERT ON persons TO omni_creator;
--GRANT UPDATE ON persons TO omni_editor;

-- contacts permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON contacts TO main_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON contacts TO omni_admin;
--GRANT SELECT ON contacts TO omni_reader;
--GRANT INSERT ON contacts TO omni_creator;
--GRANT UPDATE ON contacts TO omni_editor;

-- personcontacts permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON personcontacts TO main_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON personcontacts TO omni_admin;
--GRANT SELECT ON personcontacts TO omni_reader;
--GRANT INSERT ON personcontacts TO omni_creator;
--GRANT UPDATE ON personcontacts TO omni_editor;

-- projects permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON projects TO main_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON projects TO omni_admin;
--GRANT SELECT ON projects TO omni_reader;
--GRANT INSERT ON projects TO omni_creator;
--GRANT UPDATE ON projects TO omni_editor;

-- users permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON users TO main_admin;

-- roles permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON roles TO main_admin;

-- userroles permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON userroles TO main_admin;

-- sources permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON sources TO main_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON sources TO omni_admin;
--GRANT SELECT ON sources TO omni_reader;
--GRANT INSERT ON sources TO omni_creator;
--GRANT UPDATE ON sources TO omni_editor;

-- recordings main permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON recordings TO main_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON recordings TO omni_admin;
--GRANT SELECT ON all_recordings_view TO omni_reader;
--GRANT SELECT ON all_recordings_view TO omni_consumer;

-- recorings staging permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON recordings_staging TO main_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON recordings_staging TO omni_admin;
GRANT INSERT ON recordings_staging TO omni_supplier;

-- recordings orphaned permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON _recordings_orphaned TO main_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON _recordings_orphaned TO omni_admin;

