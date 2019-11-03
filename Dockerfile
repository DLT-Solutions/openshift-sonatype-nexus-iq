FROM sonatype/nexus-iq-server:1.71.0

USER root

RUN yum install ca-certificates -y

ADD scripts/ss-ca-puller.sh /opt/sonatype/ss-ca-puller.sh

RUN chmod +x /opt/sonatype/ss-ca-puller.sh && \
    /opt/sonatype/ss-ca-puller.sh idm.fiercesw.network:636 www.kenmoini.com:443

USER nexus