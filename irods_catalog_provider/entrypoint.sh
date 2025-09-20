#! /bin/bash -e

catalog_db_hostname=irods-catalog

echo "Waiting for iRODS catalog database to be ready"

until pg_isready -h ${catalog_db_hostname} -d ICAT -U irods -q
do
    sleep 1
done

echo "iRODS catalog database is ready"

unattended_install_file=/unattended_install.json
if [ -e "${unattended_install_file}" ]; then
    echo "Running iRODS setup"
    sed -i "s/THE_HOSTNAME/${HOSTNAME}/g" ${unattended_install_file}

    python3 /var/lib/irods/scripts/setup_irods.py --json_configuration_file ${unattended_install_file}
    rm ${unattended_install_file}

    echo "Installing transfer totals script"
    su - irods -c 'bash /install_transfer_totals.sh'

    echo "Initializing server"
    su - irods -c 'irodsServer -d'

    # wait for server to respond
    until nc -z irods-catalog-provider 1247
    do
        sleep 1
    done

    # create s3 resource
    su - irods -c 'iadmin mkresc s3resc s3 irods-catalog-provider:/demobucket/thevault "S3_DEFAULT_HOSTNAME=minio:19000;S3_AUTH_FILE=/var/lib/irods/s3.keypair;S3_REGIONNAME=us-east-1;S3_RETRY_COUNT=1;S3_WAIT_TIME_SECONDS=3;S3_PROTO=HTTP;ARCHIVE_NAMING_POLICY=consistent;HOST_MODE=cacheless_attached"'

    # kill server and wait for it to stop
    kill $(cat /var/run/irods/irods-server.pid)
    while ps -p $(cat /var/run/irods/irods-server.pid) ; do
        sleep 1
    done
fi

echo "Starting server"
cd /usr/sbin
su irods -c 'irodsServer --stdout'
