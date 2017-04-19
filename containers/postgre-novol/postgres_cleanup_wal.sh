#!/bin/bash

set -o errexit
set -o errtrace
set -o nounset
set -o pipefail
set -o xtrace


#Cleanup inactive postgre WAL files as per http://serverfault.com/a/757984
#Must be run as postgres user
last_wal_file=$(pg_controldata "${PGDATA}" | grep "Latest checkpoint's REDO WAL file" | awk '{print $NF}') && \
find "${PGDATA}"/pg_xlog -maxdepth 1 -type f \
  \! -name "${last_wal_file}" \
  \! -newer "${PGDATA}/pg_xlog/${last_wal_file}" \
  -exec rm -v {} \;
