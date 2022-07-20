FROM uitstor/uitstor:latest

ENV PATH=/opt/bin:$PATH

COPY ./uitstor /opt/bin/uitstor
COPY dockerscripts/docker-entrypoint.sh /usr/bin/docker-entrypoint.sh

ENTRYPOINT ["/usr/bin/docker-entrypoint.sh"]

VOLUME ["/data"]

CMD ["uitstor"]
