#!/bin/bash

set -e

FILES_DIR=$1
INSTALL_DIR=${2:-/opt/otrs}

NEW_VERSION=$(grep '^VERSION\s' "${FILES_DIR}/RELEASE" | sed 's/.*=\s*//')

source "${FILES_DIR}/scripts/update/update.sh"

stop_user_sessions "${FILES_DIR}" "${INSTALL_DIR}"

MAINT_ID=$(enable_maintenance_mode "${FILES_DIR}" "${INSTALL_DIR}" \
    "${NEW_VERSION}")

fix_cron_files_owner

#stop_background_jobs "${FILES_DIR}" "${INSTALL_DIR}"
shell_stop_background_jobs "${INSTALL_DIR}"

update_db "${FILES_DIR}" "${INSTALL_DIR}"

update_files "${FILES_DIR}" "${INSTALL_DIR}"

#start_background_jobs "${FILES_DIR}" "${INSTALL_DIR}"
shell_start_background_jobs "${INSTALL_DIR}"

reset_config_and_cache "${FILES_DIR}" "${INSTALL_DIR}"

restart_service $(get_webserver_service)

disable_maintenance_mode "${FILES_DIR}" "${INSTALL_DIR}" "${MAINT_ID}"
