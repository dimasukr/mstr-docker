#!/bin/bash

#Build script uses bash shell features


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

. ./env_defaults.sh

#MSTR_INSTALL_SOURCE is a directory on docker build host where MSTR installation files are located it should:
#	it should have Installations/QueryReportingAnalysis_Linux subdirectory
#	be in available rw mode
#This directory will be mount to /mnt/host_data/mstr_install in the container
: ${MSTR_BUILD_TAG:=MicroStrategy_10.7_Linux}
: ${MSTR_INSTALL_PARENT:=/mnt/host_data/mstr}
MSTR_INSTALL_SOURCE="${MSTR_INSTALL_PARENT}"/"${MSTR_BUILD_TAG}"
[[ ! -d "${MSTR_INSTALL_SOURCE}/Installations" ]] && { echo "${MSTR_INSTALL_SOURCE}/Installations directory with MSTR install source doesnt exist" >&2; exit 1; }

#This dir is where resulting containers and dump files are saved
: ${MSTR_EXPORT_FS:=/mnt/host_data/mstr/docker_export}
mkdir -p "${MSTR_EXPORT_FS}"

#Remove container with all its volumes and ignore all errors
docker_rm(){
	docker rm -f -v "${1:?Docker container name is required as parameter}" || true
}


#Build steps
docker build --file ./containers/mstr-pre-demo/Dockerfile --tag mstr-pre-demo:latest ./containers/mstr-pre-demo/
docker_rm mstr-install-demo
docker run --name mstr-install-demo -v "${MSTR_INSTALL_SOURCE}":/mnt/host_data/mstr_install --shm-size=1g --hostname="mstr-01" -it mstr-pre-demo /bin/bash -c '${DEMO_INSTALL_HOME}/mstr_install.sh'
sleep 5

docker commit -p mstr-install-demo mstr-install-demo:latest
#docker commit -p "${cont}" "${cont}":"${cont_sum}" && docker tag "${cont}":"${cont_sum}" "${cont}":latest && docker_rm "${cont}"

#Build container for RDBMS server that will hold your meta database (Postgre)
docker build --file ./containers/postgre-novol/Dockerfile --tag postgre-novol:latest ./containers/postgre-novol/
#Start it
docker run --name "postgre-novol" --hostname="postgre-mstr" -e POSTGRES_PASSWORD="${META_DB_ADMINPWD}" -d "postgre-novol"
sleep 15

docker build --file ./containers/mstr-custom-demo/Dockerfile --tag mstr-custom-demo:latest ./containers/mstr-custom-demo/
docker build --file ./containers/mstr-custom1-demo/Dockerfile --tag mstr-custom-demo1:latest ./containers/mstr-custom1-demo/


#Export container images that need to transferred somewhere as files
docker save mstr-pre-demo:latest | gzip -9 > "${MSTR_EXPORT_FS}"/mstr-pre-demo.tar.gz
docker save mstr-install-demo:latest | gzip -9 > "${MSTR_EXPORT_FS}"/mstr-install-demo.tar.gz


