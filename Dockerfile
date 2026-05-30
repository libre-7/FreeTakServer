FROM python:3.8

# don't use root, let's not have FTS be used as a priv escalation in the wild
RUN groupadd -r freetak && useradd -m -r -g freetak freetak
RUN mkdir /opt/FTSData ; chown -R freetak:freetak /opt/FTSData ; chmod a+w /var/log

# This needs the trailing slash
ENV FTS_DATA_PATH="/opt/FTSData/"
ENV FTS_DB_PATH="/opt/FTSData/FreeTAKServer.db"
ENV FTS_CONFIG_PATH="/opt/FTSData/FTSConfig.yaml"
# Override default MainPath — editable pip install resolves to
# dist-packages where ExCheck dirs don't exist
ENV FTS_MAINPATH="/FreeTAKServer/FreeTAKServer"

WORKDIR /FreeTAKServer
COPY . .
COPY --chown=freetak:freetak ./FreeTAKServer /FreeTAKServer

# Pre-create ExCheck subdirs that FTS writes to at runtime
RUN mkdir -p /FreeTAKServer/FreeTAKServer/ExCheck/checklist /FreeTAKServer/FreeTAKServer/ExCheck/template && \
    chown -R freetak:freetak /FreeTAKServer

# cryptography must be pinned (<38): eventlet/pyOpenSSL may pull latest
# which drops X509_V_FLAG_NOTIFY_POLICY
# MarkupSafe must be pinned (<2.1): Jinja2 2.11.2 uses soft_unicode
RUN pip3 install cryptography==36.0.2 markupsafe==2.0.1 --no-build-isolation -e /FreeTAKServer

# Drop privileges for runtime
USER freetak

# DataPackagePort
EXPOSE 8080
# CoTPort
EXPOSE 8087
# SSLCoTPort
EXPOSE 8089
# SSLDataPackagePort
EXPOSE 8443
# FederationPort
EXPOSE 9000
# APIPort
EXPOSE 19023

ENTRYPOINT [ "python3", "-m", "FreeTAKServer.controllers.services.FTS", "-DataPackageIP", "0.0.0.0", "-AutoStart", "True"]
