FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

ARG ingest_venv_path="/ingest-venv"
ARG ingest_pip_package="irods-capability-automated-ingest==0.4.0"

RUN apt-get update && \
    apt-get install -y \
        python3 \
        python3-pip \
    && \
    python3 -m pip install --upgrade pip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/*

RUN python3 -m pip install ${ingest_pip_package}

ENTRYPOINT bash -c "sleep infinity"
