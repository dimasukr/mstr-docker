function t() { [[ ${FUNCNAME[1]} == "source" ]] || { echo "This script must be sourced from another script" >&2; exit 1; }; }; t
cat << EOF
[Repository]
Repository=1
EncryptPassword=0
CreateMDTables=1
CreateHistListTables=1
CreateStatTables=0
MetadataPath=${MSTR_INSTALL_HOME}/install/mdpostgresql.sql
HistoryListPath=${MSTR_INSTALL_HOME}/install/content_server_db_PostgreSQL.sql
DSNName=${META_DB_DSN}
UserName=${META_DB_LOGIN}
UserPwd=${META_DB_PASSWORD}
MDPrefix=
DBName=
TBName=
DSNNameHist=${META_HIST_DSN}
UserNameHist=${META_HIST_LOGIN}
UserPwdHist=${META_HIST_PASSWORD}
HistoryPrefix=
HistoryDBName=
HistoryTBName=
DSNNameStats=${META_STAT_DSN}
UserNameStats=${META_STAT_LOGIN}
UserPwdStats=${META_STAT_PASSWORD}
StatisticsPrefix=
StatisticsPath=${MSTR_INSTALL_HOME}/install/StatisticsEnterpriseManagerScripts/DDLScripts/CreateTablesScript.sql
EOF
