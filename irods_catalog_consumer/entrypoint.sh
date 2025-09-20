#! /bin/bash -e

unattended_install_file=/unattended_install.json
if [ -e "${unattended_install_file}" ]; then
    echo "Running iRODS setup"
    sed -i "s/THE_HOSTNAME/${HOSTNAME}/g" ${unattended_install_file}

    python3 /var/lib/irods/scripts/setup_irods.py --json_configuration_file ${unattended_install_file}
    rm ${unattended_install_file}

    echo "Installing transfer totals script"
    apt update && apt install -y postgresql-client
    su - irods -c 'bash /install_transfer_totals.sh'
fi

echo "Starting server"

cd /usr/sbin
su irods -c 'irodsServer --stdout'
