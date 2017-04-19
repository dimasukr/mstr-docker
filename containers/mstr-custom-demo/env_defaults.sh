function t() { [[ ${FUNCNAME[1]} == "source" ]] || { echo "This script must be sourced from another script" >&2; exit 1; }; }; t


### MSTR meta and history db ###

: ${META_DB_HOST:="postgre-mstr"}
: ${META_DB_PORT:=5432}
: ${META_DB_ADMIN:="postgres"}
: ${META_DB_ADMINPWD:='postgres1234'}

: ${META_DB_LOGIN:=mstr_meta}
: ${META_DB_PASSWORD:='postgres1234'}

#History List database is assumed on same type/server/port as meta
: ${META_HIST_LOGIN:=mstr_hist}
: ${META_HIST_PASSWORD:='postgres1234'}

#Because MSTR doesn't support stat DB on postgre these are not used for now
: ${META_STAT_LOGIN:=mstr_stat}
: ${META_STAT_PASSWORD:='postgres1234'}

### MSTR meta and history db ###

# values allowed: see file '$MSTR_INSTALL_PATH/inst/DTMAPPINGS.PDS'
# normally it would be: SQLSERVER, POSTGRESQL
: ${META_DB_TYPE:=POSTGRESQL}

# values allowed: see file '$MSTR_INSTALL_PATH/inst/DATABASE.PDS'
# search for 'DSSOBJECT' element, 'NAME' attribute
# normally it would be: 'Microsoft SQL Server 2008' / 'Microsoft SQL Server 2012' / 'Microsoft SQL Server 2014'
# or 'PostgreSQL 8.1' / 'PostgreSQL 8.2/8.3' / 'PostgreSQL 8.4' / 'PostgreSQL 9.x'
: ${META_DB_TYPE_EX:="PostgreSQL 9.x"}

: ${META_DB_DSN:=mstr_meta}
: ${META_HIST_DSN:=mstr_hist}


### Install locations ###

: ${DEMO_INSTALL_HOME:=/mstr_demo}
# tomcat will be in ${TOMCAT_INSTALL}/tomcat directory
: ${TOMCAT_INSTALL:=/opt}
: ${MSTR_INSTALL_HOME:=/var/opt/MicroStrategy}


### Environment ###

: ${JAVA_HOME:=/usr/java/latest}
JAVA="${JAVA_HOME}"/bin/java

MSTR_CONN_WIZ="${MSTR_INSTALL_HOME}"/bin/mstrconnectwiz
MSTR_CFG_WIZ="${MSTR_INSTALL_HOME}"/bin/mstrcfgwiz-editor
MSTR_CMD="${MSTR_INSTALL_HOME}"/bin/mstrcmdmgr
MSTR_IMP="${MSTR_INSTALL_HOME}"/bin/mstrimportpackage
MSTR_CTL="${MSTR_INSTALL_HOME}"/bin/mstrctl


### MSTR ###

: ${MSTR_INSTANCE:=mstr-main}
: ${MSTR_PORT:=34952}

: ${MSTR_LOGIN:="Administrator"}
#must be empty, as by default MSTR server definition is creaated with empty password
#otherwise 'mstrcfgwiz-editor fails
#can be changed later
: ${MSTR_PASSWORD:=''}


### MSTR environment and clustering ###

# Hostname of the host used to install MSTR container.
: ${MSTR_BUILD_HOST:=mstr-01}

# MAIN_HOST is by default <hostprefix>1. So if current host=mstr-02 then main host is mstr-01
: ${MSTR_MAIN_HOST:=${HOSTNAME%[[:digit:]]}1}
if [[ "${MSTR_MAIN_HOST}" = "${HOSTNAME}" ]]; then MSTR_IS_MAIN_HOST=true; else MSTR_IS_MAIN_HOST=false; fi

# MSTR cluster
# Secondary cluster node of MSTR cluster - must end with digits 2-9. Example: mstr-02
# Main node in this case must exist and be named with same prefix as secondary node and end with 1. Example mstr-01
# Checks if hostname ends with 2-9 then it is (by default) a cluster install
if [[ ${HOSTNAME:(-1)} =~ [2-9] ]]; then is_cluster="true"; else is_cluster="false"; fi
# this allows variable to be overriden
: ${MSTR_IS_CLUSTER:=${is_cluster}}

#MSTR project source
: ${MSTR_PROJECT_SOURCE:="DEMO"}
# used to execute commands on primary from non-primary instances
: ${MSTR_PROJECT_SOURCE_MAIN:="DEMO_MAIN"}

# default MSTR project name
: ${MSTR_PROJECT:="MSTR World 2017 Docker demo"}
: ${MSTR_PROJECT_DESC:="Demo project description"}


### External Ports ###

: ${TOMCAT_EXT_PORT:=8080}
: ${MSTR_EXT_PORT:=34952}
: ${HAPROXY_EXT_PORT:=8080}

### Logging ###

# Folder INSIDE CONTAINER where all MSTR log files are placed.
# This dir is also referenced as VOLUME in Dockerfile.
: ${MSTR_LOG_DIR:=/mnt/log}

### MSTR control functions ###

get_mstr_status () {
	echo $("${MSTR_CTL}" -s IntelligenceServer gs | xmlstarlet sel -t -v "//state")
}

#Shared MSTR and MSTR functions
mstr_start() {
	STATUS=$(get_mstr_status)
	# TODO: is there 'loading' state?
	if [[ ! $STATUS =~ ^(running|starting|loading)$ ]]; then
		"${MSTR_CTL}" -s IntelligenceServer start
	fi

	cnt=0
	while [[ $STATUS != "running" && $cnt -lt 30 ]]; do
		sleep 5
		STATUS=$(get_mstr_status)
		cnt=$((cnt+1))
	done

	[[ $cnt -ge 30 ]] && { echo "Failed to start MSTR server!"; exit 1; } || true

	#TODO abort after N attempts - and what?
}

mstr_stop() {
	#This stop command will return error=255 if server is not running
	"${MSTR_CTL}" -s IntelligenceServer stop || true

	cnt=0
	while [[ ! $STATUS =~ ^(stopped|terminated)$ && $cnt -lt 30 ]]; do
		sleep 5
		STATUS=$(get_mstr_status)
		cnt=$((cnt+1))
	done

	[[ $cnt -ge 30 ]] && { echo "Failed to stop MSTR server!"; exit 1; } || true
}


### Deploy-related functions ###

#This function creates DSN (connection) in MSTR and check output to make sure there is no error
# mstrconnectwiz doesn't return >0 code when there is an eror - just some error message in standard output.
# So need to match output against success message. 
#Exits if grep doesn't find match due to shell errexit setting
mstr_dsn_create() {
	"${MSTR_CONN_WIZ}" "$@" | grep -i "Data Source Name created successfully"
}

create_db_script()
#Creates all nessesary scripts for MSTR Database configuration
#Params: 1=DSN 2=DB_HOST 3=DB_PORT 4=LOGIN 5=PASSWORD 6=DB_TYPE 7=DB_TYPE_EX 8=Suffix (optional)
#  it assumes that "Database name"="Login name"
#Don't use database name or username in DBLOGIN name (or in names of other MSTR object names) 
# to make sure it doesn't have to be changed if database information is changed.
#Suffix is used to generate temp file so that can be compared to previous version and see if there has been a change.
{
	[[ $# -lt 7 ]] && { echo "${FUNCNAME[0]} expects these parameters: DSN DB_HOST DB_PORT LOGIN PASSWORD DB_TYPE DB_TYPE_EX" >&2; exit 2; }
	[[ -n ${8:-} ]] && local suffix="${8:-}"

	#create script for DSN
	#TODO mstrconnectwiz doesn't return exit code so need to check output to see if there was a success
	#mstrconnectwiz [-r] POSTGRESQL DataSourceName HostName PortNumber DatabaseName -u:uid [-p:pwd]
	cat <<-EOF > "${DEMO_INSTALL_HOME}"/"$1".dsn.sh"${suffix:-}"
		mstr_dsn_create -r '$6' '$1' '$2' '$3' '$4' -u:'$4' -p:'$5'
	EOF

	#CMD Manager script to create database in meta data
	cat <<-EOF > "${DEMO_INSTALL_HOME}"/"$1".create.scr
		CREATE DBLOGIN "$1" LOGIN "$4" PASSWORD "$5";
		CREATE DBCONNECTION "$1" ODBCDSN "$1" DEFAULTLOGIN "$1";
		CREATE DBINSTANCE "$1" DBCONNTYPE "$7" DBCONNECTION "$1";
	EOF

	#CMD Manager script to alter database in meta data
	#This script will be used if needed to change database info after creation (TODO use sha hash later in order not to store passwords)
	cat <<-EOF > "${DEMO_INSTALL_HOME}"/"$1".alter.scr"${suffix:-}"
		ALTER DBLOGIN "$1" LOGIN "$4" PASSWORD "$5";
	EOF

	#TODO do we need to update schema if GIM connection has changed?
	if [[ "$1" == "${GIM_CONN_NAME}" ]]; then
		cat <<-EOF >> "${DEMO_INSTALL_HOME}"/"$1".alter.scr"${suffix:-}"
			UPDATE SCHEMA FOR PROJECT "${MSTR_PROJECT}";
		EOF
	fi
}

create_all_db_scripts()
#Creates all db scripts for obbc DNSs as well as MSTR cmd scripts needed for them
#Params: 1=Script Suffix (optional)
{
	create_db_script "${META_DB_DSN}" 	"${META_DB_HOST}" "${META_DB_PORT}" "${META_DB_LOGIN}"   "${META_DB_PASSWORD}"   "${META_DB_TYPE}" "${META_DB_TYPE_EX}" "${1:-}"
	create_db_script "${META_HIST_DSN}" "${META_DB_HOST}" "${META_DB_PORT}" "${META_HIST_LOGIN}" "${META_HIST_PASSWORD}" "${META_DB_TYPE}" "${META_DB_TYPE_EX}" "${1:-}"
	
}

run_mstr_cmd_script()
#Runs MSTR command manager script using default credentials and project source
#Params: 1=Full path to script, 2=Project source name (optional)
#TODO check that it returns non 0 exit code on errors
{
	[[ $# -lt 1 ]] && { echo "${FUNCNAME[0]} expects this parameter: Full path to command manager script" >&2; exit 2; }
	[[ -f "$1" ]] || { echo "${FUNCNAME[0]}: script file $1 doesn't exist" >&2; exit 2; }
	set +u
	if [[ -n "$2" ]]; then
		PROJECT_SOURCE="$2"
	else
		PROJECT_SOURCE="${MSTR_PROJECT_SOURCE}"
	fi
	set -u
	"${MSTR_CMD}" -n "${PROJECT_SOURCE}" -u "${MSTR_LOGIN}" -p "${MSTR_PASSWORD}" -f "$1" -o "$MSTR_LOG_DIR/mstr/CMDMGR.log" -showoutput -i -e
}

# TODO: split into init and startup
mstr_config_tomcat()
#Configure MSTR tomcat to work with I-Server (connection, trust, etc)
#Should be called during initialization or if hostname change detected
{
	cat <<-EOF > "${CATALINA_HOME}"/webapps/MicroStrategy/WEB-INF/xml/sys_defaults.properties
		useSessionCookie=1
	EOF

	#Add I-Server to tomcat
	#	create sys_defaults
	rm -f "${CATALINA_HOME}"/webapps/MicroStrategy/WEB-INF/xml/sys_defaults_"${MSTR_BUILD_HOST^^}".properties || true
	cat <<-EOF > "${CATALINA_HOME}"/webapps/MicroStrategy/WEB-INF/xml/sys_defaults_"${HOSTNAME^^}".properties
		port=${MSTR_PORT}
		showLoginPageAfterLogout=false
		connectmode=auto
		keep_alive=true
	EOF

	#	update AdminServers.xml
	cat <<-EOF > "${CATALINA_HOME}/webapps/MicroStrategy/WEB-INF/xml/AdminServers.xml"
		<servers version="1.0">
			<server conn="false" name="${HOSTNAME^^}"/>
		</servers>
	EOF

	#- add trust
	cat <<-EOF > "${DEMO_INSTALL_HOME}/app.properties"
		mstr.server=${HOSTNAME}
		mstr.port=${MSTR_PORT}
		mstr.user=${MSTR_LOGIN}
		mstr.password=${MSTR_PASSWORD}
		mstr.project.name=${MSTR_PROJECT}

		mstr.trust.tomcat.path=${CATALINA_HOME}
		mstr.trust.server=${HOSTNAME}
		# name of web server instance, used as key for token value
		mstr.trust.webinstance=MSTR_${HOSTNAME}_${MSTR_VERSION}

		mstr.db.driver=org.postgresql.Driver
		mstr.db.url=jdbc:postgresql://${META_DB_HOST}:${META_DB_PORT}/${META_DB_LOGIN}
		mstr.db.login=${META_DB_LOGIN}
		mstr.db.password=${META_DB_PASSWORD}

		# DO NOT CHANGE mstr.db.token* PROPERTIES
		mstr.db.token.table=gcxi_sec_tokens
		mstr.db.token.column.webinst=webinst_name
		mstr.db.token.column.tokenval=trust_token
	EOF
	
	"${JAVA}" -cp "${DEMO_INSTALL_HOME}"/com.genesys.gcxi.mstr.utils.jar com.genesys.gcxi.mstr.utils.TrustTokenCreator --props="${DEMO_INSTALL_HOME}/app.properties"

	# redirect tomcat logs
	file="${CATALINA_HOME}/conf/logging.properties"
	sed -i "s|\${catalina.base}/logs|${MSTR_LOG_DIR}/tomcat|g" "${file}"

	# disable catalina.output
	str=".handlers = 1catalina.org.apache.juli.AsyncFileHandler, java.util.logging.ConsoleHandler"
	sed -i "/^${str}/a ${str%,*}" "${file}"
	sed -i "s/^${str}/# ${str}/g" "${file}"

	file="${CATALINA_HOME}/bin/catalina.sh"
	str='CATALINA_OUT="$CATALINA_BASE"'
	sed -i "/${str}/a \ \ CATALINA_OUT=/dev/null" "${file}"
	sed -i "s|${str}|# ${str}|g" "${file}"

	# redirect tomcat access log
	file="${CATALINA_HOME}/conf/server.xml"
	sed -i "s|AccessLogValve\" directory=\"logs\"|AccessLogValve\" directory=\"${MSTR_LOG_DIR}/tomcat\"|g" "${file}"

	# redirect MSTR web app logs
	file="${CATALINA_HOME}/webapps/MicroStrategy/WEB-INF/microstrategy.xml"
	sed -i "s|name=\"serverLogFilesDefaultLocation\" value=\"/WEB-INF/log/\"|name=\"serverLogFilesDefaultLocation\" value=\"ABSOLUTE:${MSTR_LOG_DIR}/mstrWeb\"|g" "${file}"
}
