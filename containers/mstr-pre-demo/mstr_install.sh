#/bin/bash

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


#Install MSTR
cd /mnt/host_data/mstr_install/Installations/QueryReportingAnalysis_Linux
./setup.sh -silent -options "${DEMO_INSTALL_HOME}"/mstr_install_options.ini
#fix issue CXA-1650 as per https://community.microstrategy.com/t5/Server/TN307517-Configuration-Wizard-on-MicroStrategy-Secure-Analytics/ta-p/307517
rm -f "${MSTR_INSTALL_HOME}"/HealthCenterInstance/lib/libz.so "${MSTR_INSTALL_HOME}"/install/lib/libz.so.1.2.3 "${MSTR_INSTALL_HOME}"/install/lib/libz.so.1 "${MSTR_INSTALL_HOME}"/install/lib/libz.so
ln -s /usr/lib64/libz.so.1 "${MSTR_INSTALL_HOME}"/HealthCenterInstance/lib/libz.so
ln -s /usr/lib64/libz.so.1 "${MSTR_INSTALL_HOME}"/install/lib/libz.so

#Install MSTR webapp
ln -s "${MSTR_INSTALL_HOME}"/install/WebUniversal/MicroStrategy.war "${CATALINA_HOME}"/webapps/MicroStrategy.war
cd "${CATALINA_HOME}"/webapps/ && mkdir MicroStrategy && cd MicroStrategy && "${JAVA_HOME}"/bin/jar xf "${MSTR_INSTALL_HOME}"/install/WebUniversal/MicroStrategy.war
tar xf "${DEMO_INSTALL_HOME}"/plugins.tar.gz -C "${CATALINA_HOME}"/webapps/MicroStrategy/plugins/

