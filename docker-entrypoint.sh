#!/bin/sh
set -eu

mkdir -p "$(dirname "${DB_URL}")"
export DATABASE_URL="sqlite:${DB_URL}"
dbmate --migrations-dir /app/migrations --no-dump-schema up

if [ "${LOAD_SAMPLE_DATA}" = "1" ]; then
  sqlite3 "${DB_URL}" < /app/fixtures/sample-data.sql
fi

if [ "$#" -eq 0 ]; then
  set -- urmom --port "${PORT}" --database "${DB_URL}"
fi

exec "$@"
