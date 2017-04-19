function t() { [[ ${FUNCNAME[1]} == "source" ]] || { echo "This script must be sourced from another script" >&2; exit 1; }; }; t
. ${DEMO_INSTALL_HOME}/response_cr_server.ini.sh | sed "s/Action=4/Action=2/g"
