FROM ubuntu:14.04

# URL from which to download Elastalert.
ENV ELASTALERT_VERSION 0.1.29
ENV ELASTALERT_URL https://github.com/Yelp/elastalert/archive/v${ELASTALERT_VERSION}.zip

# Directory holding configuration for Elastalert and Supervisor.
ENV CONFIG_DIR /opt/config
# Elastalert rules directory.
ENV RULES_DIRECTORY /opt/rules
# Elastalert configuration file path in configuration directory.
ENV ELASTALERT_CONFIG ${CONFIG_DIR}/config.yaml
# Directory to which Elastalert and Supervisor logs are written.
ENV LOG_DIR /opt/logs
# Elastalert home directory name.
ENV ELASTALERT_DIRECTORY_NAME elastalert
# Elastalert home directory full path.
ENV ELASTALERT_HOME /opt/${ELASTALERT_DIRECTORY_NAME}
# Supervisor configuration file for Elastalert.
ENV ELASTALERT_SUPERVISOR_CONF ${CONFIG_DIR}/elastalert_supervisord.conf
# Alias, DNS or IP of Elasticsearch host to be queried by Elastalert. Set in default Elasticsearch configuration file.
ENV ELASTICSEARCH_HOST es_host
# Port on above Elasticsearch host. Set in default Elasticsearch configuration file.
ENV ELASTICSEARCH_PORT 9200

ENV S3_BUCKET=staging_elastalert_rules

# Python has a problem with SSL certificate verification
ENV PYTHONHTTPSVERIFY=0

RUN apt-get update && apt-get install -y bash gcc musl-dev openssl gettext  wget python python-dev python-setuptools && \
    apt-get install -y build-essential wget ca-certificates unzip && \
    wget "https://bootstrap.pypa.io/get-pip.py" -O /dev/stdout | python && \
    apt remove -y build-essential

WORKDIR /opt

COPY ./config ${CONFIG_DIR}
COPY ./start-elastalert.sh /opt/

RUN \
# Install AWS CLI
    pip install awscli &&\
    pip install setuptools --upgrade &&\

# Download and unpack Elastalert.
    wget --no-check-certificate ${ELASTALERT_URL} && \
    unzip *.zip && \
    rm *.zip &&\
    mv e* ${ELASTALERT_DIRECTORY_NAME}

WORKDIR ${ELASTALERT_HOME}

# Install Elastalert.
RUN python setup.py install && \
    pip install -e . && \

# Install Supervisor.
    pip install supervisor && \

# Make the start-script executable.
    chmod +x /opt/start-elastalert.sh && \

# Create directories.
    mkdir -p ${CONFIG_DIR} && \
    mkdir -p ${RULES_DIRECTORY} && \
    mkdir -p ${LOG_DIR} && \

# Copy default configuration files to configuration directory.
    cp ${ELASTALERT_HOME}/supervisord.conf.example ${ELASTALERT_SUPERVISOR_CONF} && \


# Elastalert Supervisor configuration:
    # Redirect Supervisor log output to a file in the designated logs directory.
    sed -i -e"s|logfile=.*log|logfile=${LOG_DIR}/elastalert_supervisord.log|g" ${ELASTALERT_SUPERVISOR_CONF} && \
    # Redirect Supervisor stderr output to a file in the designated logs directory.
    sed -i -e"s|stderr_logfile=.*log|stderr_logfile=${LOG_DIR}/elastalert_stderr.log|g" ${ELASTALERT_SUPERVISOR_CONF} && \
    # Modify the start-command.
    sed -i -e"s|python elastalert.py|python -m elastalert.elastalert --config ${ELASTALERT_CONFIG}|g" ${ELASTALERT_SUPERVISOR_CONF} && \

# Add Elastalert to Supervisord.
    supervisord -c ${ELASTALERT_SUPERVISOR_CONF} && \

# Clean up.
    apt remove -y python-dev && \
    apt remove -y musl-dev && \
    apt remove -y gcc && \
    rm -rf /var/cache/apt/*


# Define mount points.
VOLUME [ "${CONFIG_DIR}", "${RULES_DIRECTORY}", "${LOG_DIR}"]

# Launch Elastalert when a container is started.
CMD ["/opt/start-elastalert.sh"]
