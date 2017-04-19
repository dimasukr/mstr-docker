function t() { [[ ${FUNCNAME[1]} == "source" ]] || { echo "This script must be sourced from another script" >&2; exit 1; }; }; t
. ${DEMO_INSTALL_HOME}/response_cr_project_source.ini.sh | 
	sed "s/ServerName=${HOSTNAME}/ServerName=${MSTR_MAIN_HOST}/g" | 
	sed "s/DataSource=${MSTR_PROJECT_SOURCE}/DataSource=${MSTR_PROJECT_SOURCE_MAIN}/g"
