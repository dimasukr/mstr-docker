#This script contains statements that should sourced by every non-inline (i.e not "sourced") script.
#By adding these lines to a script
#SCRIPTPATH=$(dirname $(readlink -f "$0"))
#. "${SCRIPTPATH}"/script_preamble.sh

function t() { [[ ${FUNCNAME[1]} == "source" ]] || { echo "This script must be sourced from another script" >&2; exit 1; }; }; t

if [[ ! "${SCRIPT_PREAMBLE:-}" = true ]]; then
	SCRIPT_PREAMBLE=true
	# Exit on error. Append || true if you expect an error.
	set -o errexit
	# Exit on error inside any functions or subshells.
	set -o errtrace
	# Do not allow use of undefined vars. Use ${VAR:-} to use an undefined VAR
	set -o nounset
	# Catch the error in case mysqldump fails (but gzip succeeds) in `mysqldump |gzip`
	set -o pipefail
	# Turn on traces, useful while debugging but commented out by default
	# For docker builds it is usefull to enable
	set -o xtrace
fi
