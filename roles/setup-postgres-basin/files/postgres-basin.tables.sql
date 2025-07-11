-- # create tables

-- meta table to store internal info, like the schema version
CREATE TABLE IF NOT EXISTS _meta (
    schemaversion TEXT PRIMARY KEY,
    timestamp TIMESTAMPTZ NOT NULL,
    adminname TEXT DEFAULT NULL,
    meta JSONB DEFAULT NULL
);

-- persons to know, like users or project representatives
CREATE TABLE IF NOT EXISTS persons (
    id INTEGER PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY,
    name TEXT DEFAULT NULL,
    uri TEXT DEFAULT NULL,
    uuid UUID DEFAULT NULL,
    version INTEGER NOT NULL -- see shadow
);

CREATE TABLE IF NOT EXISTS shadow_persons (
    id INTEGER NOT NULL REFERENCES persons(id),
    version INTEGER NOT NULL DEFAULT 0,
    name TEXT NOT NULL,
    uri TEXT NOT NULL, -- e.g. email - can distiguish person-contract
    uuid UUID DEFAULT NULL, -- could still show identity - not UNIQUE!
    extid TEXT DEFAULT NULL,
    extidtype VARCHAR(32) DEFAULT NULL,
    isnatural BOOLEAN DEFAULT True,
    created TIMESTAMPTZ DEFAULT NULL,
    lastmodifieddate TIMESTAMPTZ DEFAULT NULL,
    lastmodifieduser INTEGER DEFAULT NULL,
    PRIMARY KEY(id, version),
    UNIQUE(uri, version)
);

CREATE UNIQUE INDEX IF NOT EXISTS shadow_persons_uuid
ON shadow_persons (
    uuid, version
) WHERE uuid IS NOT NULL;

-- all sorts of contact data
CREATE TABLE IF NOT EXISTS contacts (
    id INTEGER PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY,
    name TEXT DEFAULT NULL,
    uri TEXT DEFAULT NULL,
    uuid UUID DEFAULT NULL,
    version INTEGER NOT NULL -- see shadow
);

CREATE TABLE IF NOT EXISTS shadow_contacts (
    id INTEGER REFERENCES contacts(id),
    version INTEGER NOT NULL DEFAULT 0,
    name TEXT NOT NULL,
    uri TEXT NOT NULL, -- e.g. email
    uuid UUID DEFAULT NULL,
    icard TEXT DEFAULT NULL,
    ownertable TEXT DEFAULT NULL, -- try to keep contacts aligned to ..
    ownerid INTEGER DEFAULT NULL, -- .. other tables.
    created TIMESTAMPTZ NULL,
    lastmodifieddate TIMESTAMPTZ DEFAULT NULL,
    lastmodifieduser INTEGER DEFAULT NULL,
    PRIMARY KEY(id, version),
    UNIQUE(name, ownertable, ownerid, version),
    UNIQUE(uri, version)
);

CREATE UNIQUE INDEX IF NOT EXISTS shadow_contacts_uuid
ON shadow_contacts (
    uuid, version
) WHERE uuid IS NOT NULL;

-- all data needs a project context
CREATE TABLE IF NOT EXISTS projects (
    id INTEGER PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY,
    name TEXT DEFAULT NULL,
    uri TEXT DEFAULT NULL,
    uuid UUID DEFAULT NULL,
    version INTEGER NOT NULL -- see shadow
);

CREATE TABLE IF NOT EXISTS shadow_projects (
    id INTEGER NOT NULL REFERENCES projects(id),
    version INTEGER NOT NULL DEFAULT 0,
    name TEXT NOT NULL,
    uri TEXT NOT NULL, -- e.g. web/email
    uuid UUID DEFAULT gen_random_uuid(),
    representativepersonid INTEGER REFERENCES persons(id),
    publiccontactid INTEGER REFERENCES contacts(id),
    meta JSONB DEFAULT NULL,
    created TIMESTAMPTZ DEFAULT NULL,
    lastmodifieddate TIMESTAMPTZ DEFAULT NULL,
    lastmodifieduser INTEGER DEFAULT NULL,
    PRIMARY KEY(id, version),
    UNIQUE(uuid, version),
    UNIQUE(name, version),
    UNIQUE(uri, version)
);

-- connecting people with contacts
CREATE TABLE IF NOT EXISTS personcontacts (
    personsubjectid INTEGER REFERENCES persons(id) NOT NULL,
    contactobjectid INTEGER REFERENCES contacts(id),
    projectcontextid INTEGER REFERENCES projects(id),
    isprimarycontact BOOLEAN DEFAULT False,
    PRIMARY KEY(personsubjectid, contactobjectid, projectcontextid)
);

-- the actual users on the system
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY,
    name TEXT DEFAULT NULL,
    uri TEXT DEFAULT NULL,
    uuid UUID DEFAULT NULL,
    version INTEGER NOT NULL -- see shadow
);

CREATE TABLE IF NOT EXISTS shadow_users (
    id INTEGER NOT NULL REFERENCES users(id),
    version INTEGER NOT NULL DEFAULT 0,
    name TEXT NOT NULL,
    uuid UUID DEFAULT NULL,
    uri TEXT NOT NULL, -- e.g. email
    email TEXT NOT NULL,
    passhash TEXT DEFAULT NULL,
    idtoken TEXT DEFAULT NULL,
    idtokenhash VARCHAR(8) DEFAULT NULL,
    idtokentype VARCHAR(16) DEFAULT NULL,
    realpersonid INTEGER REFERENCES persons(id),
    created TIMESTAMPTZ DEFAULT NULL,
    lastmodifieddate TIMESTAMPTZ DEFAULT NULL,
    lastmodifieduser INTEGER DEFAULT NULL,
    PRIMARY KEY(id, version),
    UNIQUE(name, version),
    UNIQUE(uri, version)
);

CREATE UNIQUE INDEX IF NOT EXISTS shadow_users_uuid
ON shadow_users (
    uuid, version
) WHERE uuid IS NOT NULL;

-- role based user permissions
CREATE TABLE IF NOT EXISTS roles (
    id INTEGER PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY,
    name TEXT DEFAULT NULL,
    uri TEXT DEFAULT NULL,
    version INTEGER NOT NULL -- see shadow
);

CREATE TABLE IF NOT EXISTS shadow_roles (
    id INTEGER NOT NULL REFERENCES roles(id),
    version INTEGER NOT NULL DEFAULT 0,
    name TEXT NOT NULL,
    uri TEXT DEFAULT NULL, -- e.g. RDF
    projectid INTEGER REFERENCES projects(id),
    isowner BOOLEAN DEFAULT False,
    canread BOOLEAN DEFAULT False,
    canedit BOOLEAN DEFAULT False,
    cancreate BOOLEAN DEFAULT False,
    candelete BOOLEAN DEFAULT False,
    cangrant BOOLEAN DEFAULT False,
    created TIMESTAMPTZ DEFAULT NULL,
    lastmodifieddate TIMESTAMPTZ DEFAULT NULL,
    lastmodifieduser INTEGER DEFAULT NULL,
    PRIMARY KEY(id, version),
    UNIQUE(name, version)
);

-- connecting users to roles
CREATE TABLE IF NOT EXISTS userroles (
    userid INTEGER REFERENCES users(id) NOT NULL,
    roleid INTEGER GENERATED ALWAYS AS IDENTITY NOT NULL,
    PRIMARY KEY(userid, roleid)
);

-- the type of data sources available
CREATE TABLE IF NOT EXISTS sourcetypes (
    id INTEGER PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY, -- db internal
    name TEXT DEFAULT NULL,
    uri TEXT DEFAULT NULL,
    uuid UUID DEFAULT NULL,
    version INTEGER NOT NULL -- see shadow
);

CREATE TABLE IF NOT EXISTS shadow_sourcetypes (
    id INTEGER NOT NULL REFERENCES sourcetypes(id), -- db internal
    version INTEGER NOT NULL DEFAULT 0,
    name TEXT NOT NULL, -- kind of source: location/site, vehicle, node, sensor, actuator api, etc.
    uuid UUID DEFAULT gen_random_uuid(), -- global id, e.g. comparable sensors
    uri TEXT DEFAULT NULL, -- e.g. RDF - as type, not UNIQUE
    class TEXT DEFAULT NULL, -- only for devices, e.g. EdgeGateway
    devicetype TEXT DEFAULT NULL, -- see above, e.g. RaspberryPi3
    realmname TEXT DEFAULT NULL, -- Lifebase service
    realmuuid UUID DEFAULT NULL, -- Lifebase service
    contentencoding VARCHAR(32) DEFAULT NULL,
    contenttype VARCHAR(32) DEFAULT NULL,
    contentrdfxtypes TEXT DEFAULT NULL,
    unit VARCHAR(16) DEFAULT NULL, --
    unitencoding VARCHAR(16) DEFAULT NULL,
    tolerance INTEGER DEFAULT NULL,
    meta JSONB DEFAULT NULL,
    created TIMESTAMPTZ DEFAULT NULL,
    lastmodifieddate TIMESTAMPTZ DEFAULT NULL,
    lastmodifieduser INTEGER DEFAULT NULL,
    PRIMARY KEY(id, version),
    UNIQUE(uuid, version),
    UNIQUE(name, version)
);

-- the data sources explaining all details of the recordings
--    uuid UUID DEFAULT public.uuid_generate_v4(),
CREATE TABLE IF NOT EXISTS sources (
    id INTEGER PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY, -- db internal
    name TEXT DEFAULT NULL,
    uri TEXT DEFAULT NULL,
    uuid UUID DEFAULT NULL,
    tree LTREE NOT NULL, -- hierarchical info
    version INTEGER NOT NULL -- see shadow
);

CREATE TABLE IF NOT EXISTS shadow_sources (
    id INTEGER NOT NULL REFERENCES sources(id), -- db internal
    version INTEGER NOT NULL DEFAULT 0,
    uuid UUID DEFAULT gen_random_uuid(), -- global id
    uri TEXT DEFAULT NULL, -- one source, many projects...?
    extid TEXT DEFAULT NULL, -- alternative for preexisting external reference if needed
    tree LTREE NOT NULL, -- hierarchical info
    name TEXT NOT NULL, -- short name, usually part of 'tree'..
    context TEXT DEFAULT NULL, --
    sourcetypeid INTEGER REFERENCES sourcetypes(id) NOT NULL,
    projectid INTEGER REFERENCES projects(id) NOT NULL,
    parentid INTEGER REFERENCES sources(id) DEFAULT NULL,
    alt DOUBLE PRECISION DEFAULT NULL,
    lat DOUBLE PRECISION DEFAULT NULL,
    lon DOUBLE PRECISION DEFAULT NULL,
    mapzoom INTEGER DEFAULT NULL, -- for map displays, usually osm.org zoom
    geohash VARCHAR(12) DEFAULT NULL,
    timezone TEXT DEFAULT NULL, -- e.g. 'Europe/Zurich'
    startdate TIMESTAMPTZ DEFAULT NULL,
    stopdate TIMESTAMPTZ DEFAULT NULL,
    samplerate INTEGER DEFAULT NULL,
    meta JSONB DEFAULT NULL,
    maintainerpersonid INTEGER REFERENCES persons(id),
    softwareversion TEXT DEFAULT NULL,
    hardwareversion TEXT DEFAULT NULL,
    created TIMESTAMPTZ DEFAULT NULL,
    lastmodifieddate TIMESTAMPTZ DEFAULT NULL,
    lastmodifieduser INTEGER DEFAULT NULL,
    PRIMARY KEY(id, version),
    UNIQUE(tree, version),
    UNIQUE(uuid, version),
    UNIQUE(name, version)
);

CREATE UNIQUE INDEX IF NOT EXISTS shadow_sources_uri
ON shadow_sources (
    uri, projectid, version
) WHERE uri IS NOT NULL;

-- optional permission
CREATE TABLE IF NOT EXISTS personpermissions (
    roleid INTEGER REFERENCES roles(id) NOT NULL,
    projectid INTEGER REFERENCES projects(id) NOT NULL,
    personid INTEGER REFERENCES persons(id) NOT NULL,
    PRIMARY KEY(roleid, projectid, personid)
);

-- optional permission
CREATE TABLE IF NOT EXISTS contactpermissions (
    roleid INTEGER REFERENCES roles(id) NOT NULL,
    projectid INTEGER REFERENCES projects(id) NOT NULL,
    contactid INTEGER REFERENCES contacts(id) NOT NULL,
    PRIMARY KEY(roleid, projectid, contactid)
);

-- optional permission
CREATE TABLE IF NOT EXISTS sourcepermissions (
    roleid INTEGER REFERENCES roles(id) NOT NULL,
    projectid INTEGER REFERENCES projects(id) NOT NULL,
    sourceid INTEGER REFERENCES sources(id) NOT NULL,
    PRIMARY KEY(roleid, projectid, sourceid)
);

-- the actual data
--   projectid: double check that the project exists, we also create partitions here of
--   sourceid: inserts from sources will look up their and project ids on inserts
CREATE TABLE IF NOT EXISTS recordings (
    id BIGINT GENERATED ALWAYS AS IDENTITY,
    timestamp TIMESTAMPTZ NOT NULL,
    value DOUBLE PRECISION DEFAULT NULL, -- if it's NULL, see altvalue
    altvalue JSONB DEFAULT NULL,
    lat DOUBLE PRECISION DEFAULT NULL,
    lon DOUBLE PRECISION DEFAULT NULL,
    alt DOUBLE PRECISION DEFAULT NULL,
    geohash VARCHAR(12) DEFAULT NULL,
    projectid INTEGER REFERENCES projects(id) NOT NULL,
    sourceid INTEGER REFERENCES sources(id) NOT NULL,
    meta JSONB DEFAULT NULL,
    UNIQUE (timestamp, projectid, sourceid),
    PRIMARY KEY(id, timestamp, projectid)
) PARTITION BY LIST (projectid);

-- temporary storage for incoming data
CREATE TABLE IF NOT EXISTS recordings_staging (
    id INTEGER GENERATED ALWAYS AS IDENTITY,
    timestamp TIMESTAMPTZ NOT NULL,
    value DOUBLE PRECISION DEFAULT NULL, -- if it's NULL, see altvalue
    altvalue JSONB DEFAULT NULL,
    lat DOUBLE PRECISION DEFAULT NULL,
    lon DOUBLE PRECISION DEFAULT NULL,
    alt DOUBLE PRECISION DEFAULT NULL,
    geohash VARCHAR(12) DEFAULT NULL,
    sourceuuid UUID NOT NULL,
    meta JSONB DEFAULT NULL,
    PRIMARY KEY(id)
);

-- temporary storage for incoming data
CREATE TABLE IF NOT EXISTS _recordings_orphaned (
    id INTEGER GENERATED ALWAYS AS IDENTITY,
    timestamp TIMESTAMPTZ NOT NULL,
    value DOUBLE PRECISION DEFAULT NULL, -- if it's NULL, see altvalue
    altvalue JSONB DEFAULT NULL,
    lat DOUBLE PRECISION DEFAULT NULL,
    lon DOUBLE PRECISION DEFAULT NULL,
    alt DOUBLE PRECISION DEFAULT NULL,
    geohash VARCHAR(12) DEFAULT NULL,
    sourceuuid UUID NOT NULL,
    meta JSONB DEFAULT NULL,
    PRIMARY KEY(id)
);

