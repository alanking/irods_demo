FROM python:3.10

RUN pip install --upgrade pip

ARG PIP_PACKAGE="irods-capability-automated-ingest==0.4.0"

RUN pip install ${PIP_PACKAGE}

ENTRYPOINT ["celery", "-A", "irods_capability_automated_ingest.sync_task", "worker", "-Q", "restart,path,file"]
CMD ["-c 2"]
