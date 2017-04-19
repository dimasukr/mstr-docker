#!/bin/bash

SCRIPTPATH=$(dirname $(readlink -f "$0"))
. "${SCRIPTPATH}"/script_preamble.sh

#generate DB scripts using tmp suffix so that it can be compared to previously generated on this containder
create_all_db_scripts ".tmp"

batch_script="${DEMO_INSTALL_HOME}"/alter_batch.scr
rm -f "${batch_script}" || true

#go thru all tmp DSN sh scripts and update DSN them if they are changed
for script in "${DEMO_INSTALL_HOME}"/*.dsn.sh.tmp; do
	orig_script="${script%.tmp}"
	if ! cmp -s "${orig_script}" "${script}"; then
		#This means that some DSN connection parameter has been changed compared to initial and so need to run correction scripts
		. "${script}"
		rm -f "${orig_script}"
		mv "${script}" "${orig_script}"
		#Get the name of the changed connection
		tmp_scr=${orig_script%.dsn.sh}
		changed_dsn=${tmp_scr##*/}
		#If any of META_DB_* vars have been updated need to update server definition config
		if [[ "${changed_dsn}" == "${META_DB_DSN}" ]]; then
			. "${DEMO_INSTALL_HOME}"/response_lnk_server.ini.sh > "${DEMO_INSTALL_HOME}"/response_lnk_server.ini
			# this command stops running MSTR server, and don't starts it again
			"${MSTR_CFG_WIZ}" -r "${DEMO_INSTALL_HOME}"/response_lnk_server.ini
		fi

		alter_script="${tmp_scr}".alter.scr.tmp
		cat "${alter_script}" >> "${batch_script}"
		rm -f "${tmp_scr}".alter.scr
		mv "${alter_script}" "${tmp_scr}".alter.scr
	fi
done

#Run script batch if it was generated
if [[ -e "${batch_script}" ]]; then
	mstr_start
	run_mstr_cmd_script "${batch_script}"
fi
