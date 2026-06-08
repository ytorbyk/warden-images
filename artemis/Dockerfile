ARG ARTEMIS_VERSION=2.53.0
FROM apache/artemis:${ARTEMIS_VERSION}-alpine   

USER root

RUN mkdir -p /var/lib/artemis-instance/etc-override && \
    chown -R artemis:artemis /var/lib/artemis-instance/etc-override

COPY .warden/artemis/etc-override/jolokia-access.xml \
     /var/lib/artemis-instance/etc-override/jolokia-access.xml

USER artemis
