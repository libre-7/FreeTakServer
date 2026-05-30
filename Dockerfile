FROM python:3.8

# don't use root, let's not have FTS be used as a priv escalation in the wild
RUN groupadd -r freetak && useradd -m -r -g freetak freetak
RUN chmod a+w /var/log

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

# Pre-create ExCheck subdirs and FTSConfig.yaml to skip interactive wizard.
# v1.9.8 MainConfig.py has first_start=True hardcoded and calls
# ask_user_for_config() which blocks in Docker. We patch first_start
# to False after the YAML is generated.
RUN mkdir -p /opt/FTSData /FreeTAKServer/FreeTAKServer/ExCheck/checklist /FreeTAKServer/FreeTAKServer/ExCheck/template && \
    printf "System:\n  FTS_MAINLOOP_DELAY: 100\n  FTS_DATABASE_TYPE: SQLite\nAddresses:\n  FTS_COT_PORT: 8087\n  FTS_SSLCOT_PORT: 8089\n  FTS_DP_ADDRESS: 0.0.0.0\n  FTS_USER_ADDRESS: 0.0.0.0\n  FTS_API_PORT: 19023\n  FTS_FED_PORT: 9000\n  FTS_API_ADDRESS: 0.0.0.0\nFileSystem:\n  FTS_DB_PATH: /opt/FTSData/FreeTAKServer.db\n  FTS_MAINPATH: /FreeTAKServer/FreeTAKServer\n  FTS_CERTS_PATH: /FreeTAKServer/FreeTAKServer/certs\n  FTS_EXCHECK_PATH: /FreeTAKServer/FreeTAKServer/ExCheck\n  FTS_DATAPACKAGE_PATH: /FreeTAKServer/FreeTAKServer/FreeTAKServerDataPackageFolder\n" > /opt/FTSData/FTSConfig.yaml && \
    sed -i 's/first_start = True/first_start = False/' /FreeTAKServer/FreeTAKServer/controllers/configuration/MainConfig.py && \
    chown -R freetak:freetak /FreeTAKServer /opt/FTSData

# Pin transitive deps for Flask 1.1.2 / Jinja 2.11.2 compatibility:
# - cryptography<38: pyOpenSSL uses X509_V_FLAG_NOTIFY_POLICY
# - markupsafe<2.1: Jinja2 uses soft_unicode
# - werkzeug<2.1: Flask expects itsdangerous.json
# - itsdangerous<2.1: >=2.1 removed json module
RUN pip3 install cryptography==36.0.2 markupsafe==2.0.1 werkzeug==2.0.3 itsdangerous==2.0.1 pyOpenSSL==22.0.0 --no-build-isolation -e /FreeTAKServer

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
