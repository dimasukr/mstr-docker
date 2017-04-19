function t() { [[ ${FUNCNAME[1]} == "source" ]] || { echo "This script must be sourced from another script" >&2; exit 1; }; }; t
cat << EOF
[Client]
Client=1
EncryptPassword=0
DataSource=${MSTR_PROJECT_SOURCE}
ConnType=3
DSN=
UserName=
UserPwd=
MDPrefix=
ServerName=${HOSTNAME}
Port=${MSTR_PORT}
Timeout=30
Authentication=1
EOF
