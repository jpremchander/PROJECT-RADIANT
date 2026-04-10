FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        iproute2 \
        suricata \
    && rm -rf /var/lib/apt/lists/*

COPY suricata.yaml /etc/suricata/suricata.yaml
COPY rules/ /etc/suricata/rules/

RUN mkdir -p /var/log/suricata

CMD ["suricata", "-c", "/etc/suricata/suricata.yaml", "-i", "eth0"]