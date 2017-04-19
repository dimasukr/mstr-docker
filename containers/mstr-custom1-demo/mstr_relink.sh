#!/bin/bash
#Re-link MSTR to updated meta DB, e. g. after DB restored from dump

SCRIPTPATH=$(dirname $(readlink -f "$0"))
. "${SCRIPTPATH}"/script_preamble.sh
. "${SCRIPTPATH}"/env_global.sh

# Note: MSTR meta and GIM variables must be initialized before this script run.
# One of the env_defaults_*.sh script must be sourced.

. "${DEMO_INSTALL_HOME}"/response_lnk_server.ini.sh > "${DEMO_INSTALL_HOME}"/response_lnk_server.ini
"${MSTR_CFG_WIZ}" -r "${DEMO_INSTALL_HOME}"/response_lnk_server.ini
mstr_start

# we need forcefully upgrade login credentials, since they are preserved from source db
cmd_scr="${DEMO_INSTALL_HOME}"/alter_dblogin.scr
cat <<-EOF > "${cmd_scr}"
	ALTER DBLOGIN "${META_DB_DSN}" LOGIN "${META_DB_LOGIN}" PASSWORD "${META_DB_PASSWORD}";
	ALTER DBLOGIN "${META_HIST_DSN}" LOGIN "${META_HIST_LOGIN}" PASSWORD "${META_HIST_PASSWORD}";
EOF
run_mstr_cmd_script "${cmd_scr}"
rm -f "${cmd_scr}" || true

mstr_stop
