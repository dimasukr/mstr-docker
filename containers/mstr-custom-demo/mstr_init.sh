#!/bin/bash
#Create empty project with proper name, configurations and connections

SCRIPTPATH=$(dirname $(readlink -f "$0"))
. "${SCRIPTPATH}"/script_preamble.sh
. "${SCRIPTPATH}"/env_defaults.sh

### Configure logging ###

# redirect Kafka logs

path="/var/opt/MicroStrategy/install/MessagingServices/Kafka/kafka*"
for folder in ${path}; do
	file="${folder}/bin/kafka-run-class.sh"
	str='LOG_DIR="$base_dir"'
	sed -i "/${str}/a LOG_DIR=\"${MSTR_LOG_DIR}/mstr/kafka\"" "${file}"
	sed -i "s|${str}|# ${str}|g" "${file}"
	
	file="${folder}/config/server.properties"
	sed -i "s|log.dirs=${MSTR_INSTALL_HOME}|log.dirs=${MSTR_LOG_DIR}/mstr/kafka|g" "${file}"
done


### Configure empty project ###

create_all_db_scripts

#Create dsn for all databases using generated scripts
for filename in "${DEMO_INSTALL_HOME}"/*.dsn.sh; do
	. "${filename}";
done

#Create ini files for MSTR connectivity objects
for filename in "${DEMO_INSTALL_HOME}"/*.ini.sh; do
	. "${filename}" > "${filename%.sh}";
done

#TODO check that editor returns exit code in case of error
"${MSTR_CFG_WIZ}" -r "${DEMO_INSTALL_HOME}"/response_db_config.ini
"${MSTR_CFG_WIZ}" -r "${DEMO_INSTALL_HOME}"/response_cr_server.ini
"${MSTR_CFG_WIZ}" -r "${DEMO_INSTALL_HOME}"/response_cr_project_source.ini


INIT_MSTR_CMD_FILE="${DEMO_INSTALL_HOME}"/init_cmdmgr.scr
cat "${DEMO_INSTALL_HOME}"/*.create.scr > "${INIT_MSTR_CMD_FILE}"
cat <<-EOF >> "${INIT_MSTR_CMD_FILE}"
	ALTER SERVER CONFIGURATION ENABLEMESSAGINGSERVICES FALSE;
EOF
mstr_start
run_mstr_cmd_script "${INIT_MSTR_CMD_FILE}"


### Configure server ###

# modify Content Repository database and Affinity Cluster flag
# switch History List storage to database (instead of filesystem)
cat <<-EOF > "${DEMO_INSTALL_HOME}/app.properties"
	mstr.server=${HOSTNAME}
	mstr.port=${MSTR_PORT}
	mstr.user=${MSTR_LOGIN}
	mstr.password=${MSTR_PASSWORD}

	mstr.history.db=${META_HIST_DSN}
	mstr.user.affinityFlag=1

EOF
"${JAVA}" -cp "${DEMO_INSTALL_HOME}"/com.genesys.gcxi.mstr.utils.jar com.genesys.gcxi.mstr.utils.ServerConfigApplier --props="${DEMO_INSTALL_HOME}/app.properties"


mstr_stop


### Apply Customization ###

mstr_start

# add MSTR fonts to system
cp -rf "${DEMO_INSTALL_HOME}"/fonts/*.ttf /usr/share/fonts/
fc-cache -fv

# update fonts in Tomcat
cp -rf "${DEMO_INSTALL_HOME}"/fonts/fontNamesPicker.xml "${CATALINA_HOME}"/webapps/MicroStrategy/WEB-INF/xml/config/

# update favicon in Tomcat
FAVICON_DIR="${CATALINA_HOME}/webapps/MicroStrategy/style/mstr/images"
mv -f "${FAVICON_DIR}/favicon.ico" "${FAVICON_DIR}/favicon.ico.bkp"
cp -f "${DEMO_INSTALL_HOME}/img/favicon.ico" "${FAVICON_DIR}/favicon.ico"

#Configure MSTR tomcat to work with I-Server (connection, trust, etc)
mstr_config_tomcat

mstr_stop
sleep 15
