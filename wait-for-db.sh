#!/bin/sh
# wait-for-db.sh
# Wait for MySQL database to be available using PHP

set -e

DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-3306}"
DB_USER="${DB_USERNAME:-${DB_USER:-root}}"
DB_PASS="${DB_PASSWORD:-${DB_PASS:-}}"
TIMEOUT="${WAIT_FOR_DB_TIMEOUT:-120}"  # Increased to 120 seconds

echo "Waiting for DB at ${DB_HOST}:${DB_PORT} (timeout ${TIMEOUT}s)..."

php -r "
\$host = getenv('DB_HOST') ?: '${DB_HOST}';
\$port = (int)(getenv('DB_PORT') ?: ${DB_PORT});
\$user = getenv('DB_USERNAME') ?: getenv('DB_USER') ?: '${DB_USER}';
\$pass = getenv('DB_PASSWORD') ?: '${DB_PASS}';
\$timeout = (int)(getenv('WAIT_FOR_DB_TIMEOUT') ?: ${TIMEOUT});
for (\$i = 0; \$i < \$timeout; \$i++) {
  \$conn = @mysqli_connect(\$host, \$user, \$pass, '', \$port);
  if (\$conn) {
    mysqli_close(\$conn);
    exit(0);
  }
  sleep(1);
}
exit(1);
"

status=$?

if [ $status -eq 0 ]; then
  echo "Database is up."
  exit 0
else
  echo "Timed out waiting for database."
  exit 1
fi
