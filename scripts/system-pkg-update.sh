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

get_webserver_group() {
    if [ -e /etc/redhat-release ]; then
        echo 'apache'
    elif [ -e /etc/debian_version ]; then
        echo 'www-data'
    fi
}

run_as_otrs_user() {
    setpriv --euid $(id -u otrs) --ruid $(id -u otrs) \
        --egid $(id -g $(get_webserver_group)) \
        --rgid $(id -g $(get_webserver_group)) \
        --keep-groups \
        $*
}

stop_background_jobs() {
    cd "${INSTALL_DIR}"
    run_as_otrs_user bin/Cron.sh stop
    run_as_otrs_user bin/otrs.Daemon.pl stop
}

start_background_jobs() {
    cd "${INSTALL_DIR}"
    run_as_otrs_user bin/otrs.Daemon.pl start
    run_as_otrs_user bin/Cron.sh start
}

enable_maintenance_mode() {
    local MAINT_ID=$(
        perl -I"${INSTALL_DIR}" -I"${INSTALL_DIR}/Kernel/cpan-lib" \
            -MKernel::System::ObjectManager \
            -e '
                use strict;
                use warnings;

                local $Kernel::OM = Kernel::System::ObjectManager->new();

                my $Version = shift;

                # Log out users
                my $SessionObject =
                    $Kernel::OM->Get("Kernel::System::AuthSession");
                $SessionObject->CleanUp();

                # Start maintenance mode
                my $SysMaintObject =
                    $Kernel::OM->Get("Kernel::System::SystemMaintenance");
                my $MaintID = $SysMaintObject->SystemMaintenanceAdd(
                    StartDate        => time,
                    StopDate         => time + (60 * 60 * 24),
                    Comment          => "Update to $Version",
                    ShowLoginMessage => 1,
                    ValidID          => 1,
                    UserID           => 1,
                );

                print "$MaintID\n";
            ' \
            "${NEW_VERSION}"
    )

    echo $MAINT_ID
}

disable_maintenance_mode() {
    local MAINT_ID=$1

    perl -I"${INSTALL_DIR}" -I"${INSTALL_DIR}/Kernel/cpan-lib" \
        -MKernel::System::ObjectManager \
        -e '
            use strict;
            use warnings;

            local $Kernel::OM = Kernel::System::ObjectManager->new();

            my $MaintID = shift;

            my $SysMaintObject =
                $Kernel::OM->Get("Kernel::System::SystemMaintenance");
            
            my $Maint = $SysMaintObject->SystemMaintenanceGet(
                ID     => $MaintID,
                UserID => 1,
            );

            # Stop maintenance mode by setting stop date to current time
            $SysMaintObject->SystemMaintenanceUpdate(
                ID        => $Maint->{ID},
                StartDate => $Maint->{StartDate},
                StopDate  => time,
                Comment   => $Maint->{Comment},
                ValidID   => 1,
                UserID    => 1,
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
    find "${FILES_DIR}" -type f | while read FILE; do
        FILE=${FILE#$FILES_DIR}
        DIR=${FILE%/*}

        if [ "${DIR}" = "${FILE}" ]; then
            DIR=""
        fi

        if [ ! -d "${INSTALL_DIR}/${DIR}" ]; then
            echo mkdir -p "${INSTALL_DIR}/${DIR}"
            mkdir -p "${INSTALL_DIR}/${DIR}"
        fi
        
        cp "${FILES_DIR%/}/${FILE}" "${INSTALL_DIR}/${FILE}"
    done
}

MAINT_ID=$(enable_maintenance_mode)

stop_background_jobs &> /dev/null

update_db

update_files

start_background_jobs &> /dev/null

disable_maintenance_mode "${MAINT_ID}"
