-- migrate:up

CREATE TABLE auth_user (
  username TEXT NOT NULL PRIMARY KEY,
  password TEXT NOT NULL,
  email TEXT,
  is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
  created_at INTEGER NOT NULL DEFAULT (unixepoch())
);

CREATE TABLE auth_session (
  key TEXT NOT NULL PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES auth_user (username) ON DELETE CASCADE,
  expires_at INTEGER NOT NULL,
  revoked INTEGER NOT NULL DEFAULT 0 CHECK (revoked IN (0, 1)),
  created_at INTEGER NOT NULL DEFAULT (unixepoch())
);

CREATE INDEX idx_auth_session_user_id ON auth_session (user_id);
CREATE INDEX idx_auth_session_expires_at ON auth_session (expires_at);

CREATE TABLE dash_app (
  appname TEXT NOT NULL PRIMARY KEY,
  description TEXT
);

CREATE TABLE dash_binding (
  id INTEGER PRIMARY KEY,
  username TEXT NOT NULL REFERENCES auth_user (username) ON DELETE CASCADE,
  appname TEXT NOT NULL REFERENCES dash_app (appname) ON DELETE CASCADE,
  UNIQUE (username, appname)
);

CREATE INDEX idx_dash_binding_username ON dash_binding (username);

-- migrate:down

DROP TABLE IF EXISTS dash_binding;
DROP TABLE IF EXISTS dash_app;
DROP TABLE IF EXISTS auth_session;
DROP TABLE IF EXISTS auth_user;
