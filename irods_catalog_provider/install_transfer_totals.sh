#! /bin/bash -e

######
# 1. create new db table

PGPASSWORD=testpassword psql ICAT -h irods-catalog -c "\
  CREATE TABLE r_transfer_totals ( \
  user_id BIGINT NOT NULL, \
  action VARCHAR(250) NOT NULL, \
  exbibytes BIGINT NOT NULL, \
  bytes BIGINT NOT NULL, \
  CONSTRAINT unique_user_action UNIQUE (user_id, action) \
) \
"

######
# 2. chmod +x msiExecCmd_bin/add_transfer.sh

cat << 'EOF' > /var/lib/irods/msiExecCmd_bin/add_transfer.sh
#!/bin/bash

USER_ID="$1"
ACTION="$2"
BYTES="$3"

# does not handle the rollover at each exbibyte
# - exbibyte is 2^60
# - BIGINT can hold 2^63 - 1
# separate script/process will handle rollover transactionally
# - if bytes > 2^60:
#      exbibytes = bytes / 2^60
#      bytes = bytes % 2^60
PGPASSWORD=testpassword psql ICAT -h irods-catalog -c " \
  INSERT INTO R_TRANSFER_TOTALS (user_id, action, exbibytes, bytes) \
  VALUES (${USER_ID}, '${ACTION}', 0, ${BYTES}) \
  ON CONFLICT (user_id, action) DO UPDATE SET \
    bytes = R_TRANSFER_TOTALS.bytes + EXCLUDED.bytes; \
"
EOF
chmod +x /var/lib/irods/msiExecCmd_bin/add_transfer.sh

######
# 3. add PEPs to core.re

ed -s /etc/irods/core.re << EOF
0a
add_transfer(*user, *direction, *bytes){
  *query = "select USER_ID where USER_NAME = '*user'";
  msiExecStrCondQuery(*query, *res);
  foreach(*res) {*userid = *res.USER_ID};
  *theargs = "*userid *direction *bytes";
  msiExecCmd("add_transfer.sh", *theargs, "null", "null", "null", *result);
}

pep_api_data_obj_write_post(*INSTANCE_NAME, *COMM, *DATAOBJWRITEINP, *BUFFER) {
  add_transfer(*COMM.user_user_name, 'in', *DATAOBJWRITEINP.len);
}

pep_api_data_obj_read_post(*INSTANCE_NAME, *COMM, *DATAOBJREADINP, *BUFFER) {
  add_transfer(*COMM.user_user_name, 'out', *DATAOBJREADINP.len);
}

pep_api_data_obj_put_post(*INSTANCE_NAME, *COMM, *DATAOBJINP, *BUFFER, *PORTAL_OPR_OUT) {
  add_transfer(*COMM.user_user_name, 'in', *DATAOBJINP.data_size);
}

pep_api_data_obj_get_post(*INSTANCE_NAME, *COMM, *DATAOBJINP, *BUFFER, *PORTAL_OPR_OUT) {
  add_transfer(*COMM.user_user_name, 'out', *DATAOBJINP.data_size);
}

pep_api_data_obj_rsync_post(*INSTANCE_NAME, *COMM, *DATAOBJINP, *OUTPARAMARRAY) {
  # this is not needed since rsync just calls put and get
#  writeLine('serverLog', *DATAOBJINP);
}

pep_api_bulk_data_obj_put_post(*INSTANCE_NAME, *COMM, *BULKOPRINP, *BUFFER) {
  # bulk can hold up to 50 files, with sizes in data_size_0 through data_size_49
  # walk through and sum the sizes
#  writeLine('serverLog', *BULKOPRINP);

  *counter = 0;
  *totalbytes = 0;
  foreach(*k in *BULKOPRINP) {
    if (*k like "data_size_*") then {
      *counter = *counter + 1;
      *totalbytes = *totalbytes + int(*BULKOPRINP.*k);
#      writeLine('serverLog', '[' ++ str(*counter) ++ '] adding [' ++ *BULKOPRINP.*k ++ '], new total [' ++ str(*totalbytes) ++ ']')
    }
  }
  add_transfer(*COMM.user_user_name, 'in', *totalbytes);
}

.
w
q
EOF
