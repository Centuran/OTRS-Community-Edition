#!/bin/bash

FILES_DIR=$1
INSTALL_DIR=${2:-/opt/otrs}

NEW_VERSION=$(grep '^VERSION\s' "${FILES_DIR}/RELEASE" | sed 's/.*=\s*//')

stop_service() {
    local SERVICE=$1

    systemctl stop "${SERVICE}"
}

start_service() {
    local SERVICE=$1

    systemctl start "${SERVICE}"
}

restart_service() {
    local SERVICE=$1

    systemctl restart "${SERVICE}"
}

get_webserver_group() {
    if [ -e /etc/redhat-release ]; then
        echo 'apache'
    elif [ -e /etc/debian_version ]; then
        echo 'www-data'
    fi
}

get_webserver_service() {
    if [ -e /etc/redhat-release ]; then
        echo 'httpd'
    elif [ -e /etc/debian_version ]; then
        echo 'apache2'
    fi
}

run_as_otrs_user() {
    setpriv --euid $(id -u otrs) --ruid $(id -u otrs) \
        --egid $(id -g $(get_webserver_group)) \
        --rgid $(id -g $(get_webserver_group)) \
        --keep-groups \
        "$@"
}

stop_background_jobs() {
    perl -I"${FILES_DIR}" -I"${FILES_DIR}/Kernel/cpan-lib" \
        -I"${INSTALL_DIR}" -I"${INSTALL_DIR}/Kernel/cpan-lib" \
        -MKernel::System::ObjectManager \
        -e '
            use strict;
            use warnings;

            local $Kernel::OM = Kernel::System::ObjectManager->new();

            my $UpdateObject = $Kernel::OM->Get("Kernel::System::Update");

            $UpdateObject->StopBackgroundTasks();
        '
}

start_background_jobs() {
    perl -I"${FILES_DIR}" -I"${FILES_DIR}/Kernel/cpan-lib" \
        -I"${INSTALL_DIR}" -I"${INSTALL_DIR}/Kernel/cpan-lib" \
        -MKernel::System::ObjectManager \
        -e '
            use strict;
            use warnings;

            local $Kernel::OM = Kernel::System::ObjectManager->new();

            my $UpdateObject = $Kernel::OM->Get("Kernel::System::Update");

            $UpdateObject->StartBackgroundTasks();
        '
}

stop_user_sessions() {
    perl -I"${FILES_DIR}" -I"${FILES_DIR}/Kernel/cpan-lib" \
        -I"${INSTALL_DIR}" -I"${INSTALL_DIR}/Kernel/cpan-lib" \
        -MKernel::System::ObjectManager \
        -e '
            use strict;
            use warnings;

            local $Kernel::OM = Kernel::System::ObjectManager->new();

            my $UpdateObject = $Kernel::OM->Get("Kernel::System::Update");

            $UpdateObject->StopUserSessions();
        '
}

enable_maintenance_mode() {
    local MAINT_ID=$(
        perl -I"${FILES_DIR}" -I"${FILES_DIR}/Kernel/cpan-lib" \
            -I"${INSTALL_DIR}" -I"${INSTALL_DIR}/Kernel/cpan-lib" \
            -MKernel::System::ObjectManager \
            -e '
                use strict;
                use warnings;

                local $Kernel::OM = Kernel::System::ObjectManager->new();

                my $Version = shift;

                my $UpdateObject = $Kernel::OM->Get("Kernel::System::Update");

                my $MaintID = $UpdateObject->EnableMaintenanceMode(
                    DistVersion => $Version,
                );

                print "$MaintID\n";
            ' \
            "${NEW_VERSION}"
    )

    echo $MAINT_ID
}

disable_maintenance_mode() {
    local MAINT_ID=$1

    perl -I"${FILES_DIR}" -I"${FILES_DIR}/Kernel/cpan-lib" \
        -I"${INSTALL_DIR}" -I"${INSTALL_DIR}/Kernel/cpan-lib" \
        -MKernel::System::ObjectManager \
        -e '
            use strict;
            use warnings;

            local $Kernel::OM = Kernel::System::ObjectManager->new();

            my $MaintID = shift;

            my $UpdateObject = $Kernel::OM->Get("Kernel::System::Update");

            $UpdateObject->DisableMaintenanceMode(
                SystemMaintenanceID => $MaintID,
            );
        ' \
        "${MAINT_ID}"
}

update_db() {
    perl -I"${FILES_DIR}" -I"${FILES_DIR}/Kernel/cpan-lib" \
        -I"${INSTALL_DIR}" -I"${INSTALL_DIR}/Kernel/cpan-lib" \
        -MKernel::System::ObjectManager \
        -e '
            use strict;
            use warnings;

            local $Kernel::OM = Kernel::System::ObjectManager->new();
            
            my $DistPath = shift;

            my $UpdateObject = $Kernel::OM->Get("Kernel::System::Update");

            $UpdateObject->UpdateDatabase(
                DistPath => $DistPath,
            );
        ' \
        "${FILES_DIR}"
}

update_files() {
    perl -I"${FILES_DIR}" -I"${FILES_DIR}/Kernel/cpan-lib" \
        -I"${INSTALL_DIR}" -I"${INSTALL_DIR}/Kernel/cpan-lib" \
        -MKernel::System::ObjectManager \
        -e '
            use strict;
            use warnings;

            local $Kernel::OM = Kernel::System::ObjectManager->new();
            
            my $DistPath = shift;

            my $UpdateObject = $Kernel::OM->Get("Kernel::System::Update");

            $UpdateObject->CopyFiles(
                DistPath => $DistPath,
            );
        ' \
        "${FILES_DIR}"
}

stop_user_sessions

MAINT_ID=$(enable_maintenance_mode)

stop_background_jobs

update_db

update_files

start_background_jobs

restart_service $(get_webserver_service)

disable_maintenance_mode "${MAINT_ID}"
