#!/bin/bash

SCRIPTPATH=$(dirname $(readlink -f "$0"))
. "${SCRIPTPATH}"/script_preamble.sh
. "${SCRIPTPATH}"/env_defaults_build.sh

# Note: MSTR meta and GIM variables must be initialized before this script run.
# One of the env_defaults_*.sh script must be sourced.


#update hostname
if [[ "${MSTR_BUILD_HOST}" != "${HOSTNAME}" ]]; then
	sed -i  "s/${MSTR_BUILD_HOST}/${HOSTNAME}/g" "${MSTR_INSTALL_HOME}/IntelligenceServer/status-iserver.xml"
	sed -i  "s/${MSTR_BUILD_HOST}/${HOSTNAME}/g" "${MSTR_INSTALL_HOME}/MSIReg.reg"
	files=("${MSTR_INSTALL_HOME}"/IntelligenceServer/Cube/mstr-main/Server_"${MSTR_BUILD_HOST}"_*)
	for file in "${files[@]}"; do
		[[ -e "${file}" ]] && mv "${file}" "${file//${MSTR_BUILD_HOST}/${HOSTNAME}}"
	done
	#TODO rewrite as function	
	files=("${MSTR_INSTALL_HOME}"/IntelligenceServer/Caches/mstr-main/Server_"${MSTR_BUILD_HOST}"_*)
	for file in "${files[@]}"; do
		[[ -e "${file}" ]] && mv "${file}" "${file//${MSTR_BUILD_HOST}/${HOSTNAME}}"
	done
fi


### Update connectivity staff ###

#update project sources
for filename in "${DEMO_INSTALL_HOME}"/*.ini.sh; do
	. "${filename}" > "${filename%.sh}";
done
# project source pointing to main node
"${MSTR_CFG_WIZ}" -r "${DEMO_INSTALL_HOME}"/response_cr_project_source.ini
"${MSTR_CFG_WIZ}" -r "${DEMO_INSTALL_HOME}"/response_cr_project_source_main.ini

#TODO optimize repeated restarts in this sequence if both DB changed and cluster detected
#update databases if needed
. "${DEMO_INSTALL_HOME}"/mstr_update_dsn.sh

# rm MSTR ini file, as they contain passwords
rm -f "${DEMO_INSTALL_HOME}"/response_*.ini

mstr_start


### Change Administrator password ###

# password change is done by primary node at first start, '${DEMO_INSTALL_HOME}/password' file serves as a flag
if [[ $MSTR_IS_CLUSTER != "true" && -f "${DEMO_INSTALL_HOME}/password" ]]; then
	[[ "${newpwd}" != "${oldpwd}" ]] && mstr_change_admin_pwd "${oldpwd}" "${newpwd}" || true
	export MSTR_PASSWORD="${newpwd}"

	# this restart for proper history db setup
	mstr_stop
	mstr_start
fi
rm -f "${DEMO_INSTALL_HOME}/password"


# this procedure needs server up
if [[ "${MSTR_BUILD_HOST}" != "${HOSTNAME}" ]]; then
	mstr_config_tomcat
fi


setup_cluster()
{	
	#If this is not the main server but a second host then add it to cluster
	#In MSTR adding server to cluster actually means that you add the main node to cluster from second server
	if [[ $MSTR_IS_CLUSTER == "true" ]]; then
		CMD="ALTER SERVER CONFIGURATION SERVERTOREFORMATSTARTUP \"${MSTR_MAIN_HOST}\", \"${HOSTNAME}\";";

		alter_script=$DEMO_INSTALL_HOME/alter_cluster.scr
		cat <<-EOF > "${alter_script}"
			ADD SERVER "${MSTR_MAIN_HOST}" TO CLUSTER;
			${CMD}
		EOF
		run_mstr_cmd_script "${alter_script}"

		# this shoukd be executed on behalf of the opposite host, 
		# otherwise error "Server is trying to join itself in cluster" occurs
		cat <<-EOF > "${alter_script}"
			ADD SERVER "${HOSTNAME}" TO CLUSTER;
			${CMD}
		EOF
		run_mstr_cmd_script "${alter_script}" "${MSTR_PROJECT_SOURCE_MAIN}"

		sleep 10
	fi
}
# TODO: error occurs if opposite server unavailable, make reliable checks
set +e
setup_cluster
set -e


"${CATALINA_HOME}"/bin/startup.sh
#TODO change to dynamic check to see if MSTR is up instead of large time delay
sleep 5

#Check the status of MSTR instance and output it to console
#TODO this should be replaced by health check
#health check should fail (and therefore exit container) if MSTR fails
#health check should check and restart tomcat if tomcat fails or if its memory growth to some large value (TODO)
while true; do
  "${MSTR_INSTALL_HOME}"/bin/mstrctl -s IntelligenceServer gs
  # if first node restarted it exits from cluster until second node restarted
  # TODO: handle it better
  set +e
  setup_cluster
  set -e
  
  ps -auxw --sort pmem
  sleep 180
done
