# syntax=docker/dockerfile:1
ARG FTL_SOURCE=remote

# Pull Stable images
FROM alpine:3.22 AS base

ARG TARGETPLATFORM
ARG WEB_BRANCH="master"
ARG CORE_BRANCH="master"
ARG FTL_BRANCH="master"
ARG MITHRIL_TAG="dev-localbuild"
ARG PADD_BRANCH="master"

ARG CORE_FORK="pi-hole"
ARG WEB_FORK="pi-hole"
ARG PADD_FORK="pi-hole"

ARG PIHOLE_UID=1000
ARG PIHOLE_GID=1000

ENV DNSMASQ_USER=pihole
ENV FTL_CMD=no-daemon

RUN apk add --no-cache \
    bash \
    bash-completion \
    bind-tools \
    binutils \
    coreutils \
    curl \
    git \
    grep \
    iproute2 \
    jq \
    libcap \
    logrotate \
    ncurses \
    procps-ng \
    psmisc \
    shadow \
    sudo \
    tzdata \
    unzip \
    wget

ADD https://ftl.pi-hole.net/macvendor.db /macvendor.db
COPY crontab.txt /crontab.txt

# Add PADD to the container
RUN git clone --depth 1 https://github.com/${PADD_FORK}/PADD /opt/padd && \
    if [ "${PADD_BRANCH}" != "master" ]; then \
        cd /opt/padd && \
        git fetch --depth 1 origin "${PADD_BRANCH}" && \
        git checkout "${PADD_BRANCH}"; \
    fi && \
    chmod +x /opt/padd/padd.sh && \
    ln -s /opt/padd/padd.sh /usr/local/bin/padd

# Download FTL from Pi-hole
FROM base AS remote-ftl-install

ARG TARGETPLATFORM
ARG FTL_BRANCH

RUN FTL_ARCH="" && \
    case "${TARGETPLATFORM}" in \
        "linux/amd64")   FTL_ARCH="amd64" ;; \
        "linux/386")     FTL_ARCH="386" ;; \
        "linux/arm/v6")  FTL_ARCH="armv6" ;; \
        "linux/arm/v7")  FTL_ARCH="armv7" ;; \
        "linux/arm64")   FTL_ARCH="arm64" ;; \
        "linux/riscv64") FTL_ARCH="riscv64" ;; \
    esac && \
    curl -sSL "https://ftl.pi-hole.net/${FTL_BRANCH}/pihole-FTL-${FTL_ARCH}" -o /usr/bin/pihole-FTL && \
    chmod +x /usr/bin/pihole-FTL && \
    readelf -h /usr/bin/pihole-FTL || (echo "Downloaded FTL binary doesn't match" && exit 1)

# Clone core and web repositories
RUN clone_repo() { \
        FORK="$1"; \
        REPO="$2"; \
        BRANCH="$3"; \
        TARGET="$4"; \
        if [ "${BRANCH}" = "master" ]; then \
            git clone --depth 1 "https://github.com/${FORK}/${REPO}.git" "${TARGET}"; \
        else \
            git clone "https://github.com/${FORK}/${REPO}.git" "${TARGET}" && \
            cd "${TARGET}" && \
            git checkout "${BRANCH}"; \
        fi; \
    }; \
    clone_repo "${WEB_FORK}" "web" "${WEB_BRANCH}" "/var/www/html/admin"; \
    clone_repo "${CORE_FORK}" "pi-hole" "${CORE_BRANCH}" "/etc/.pihole"

RUN cd /etc/.pihole && \
    install -Dm755 -d /opt/pihole && \
    install -Dm755 -t /opt/pihole gravity.sh && \
    install -Dm755 -t /opt/pihole ./advanced/Scripts/*.sh && \
    install -Dm755 -t /opt/pihole ./advanced/Scripts/COL_TABLE && \
    install -Dm755 -d /etc/pihole && \
    install -Dm644 -t /etc/pihole ./advanced/Templates/logrotate && \
    install -Dm755 -d /var/log/pihole && \
    install -Dm755 -d /var/lib/logrotate && \
    install -Dm755 -t /usr/local/bin pihole && \
    install -Dm644 ./advanced/bash-completion/pihole.bash /etc/bash_completion.d/pihole && \
    install -Dm644 ./advanced/bash-completion/pihole-ftl.bash /etc/bash_completion.d/pihole-FTL && \
    install -T -m 0755 ./advanced/Templates/pihole-FTL-prestart.sh /opt/pihole/pihole-FTL-prestart.sh && \
    install -T -m 0755 ./advanced/Templates/pihole-FTL-poststop.sh /opt/pihole/pihole-FTL-poststop.sh && \
    addgroup -S pihole -g ${PIHOLE_GID} && adduser -S pihole -G pihole -u ${PIHOLE_UID} && \
    echo "${MITHRIL_TAG}" > /mithril.docker.tag

COPY --chmod=0755 bash_functions.sh /usr/bin/bash_functions.sh
COPY --chmod=0755 start.sh /usr/bin/start.sh

EXPOSE 53 53/udp
EXPOSE 67/udp
EXPOSE 80
EXPOSE 443

# Local FTL build option
FROM base AS local-ftl-install
COPY --chmod=0755 pihole-FTL /usr/bin/pihole-FTL
RUN readelf -h /usr/bin/pihole-FTL || (echo "Error with local FTL binary" && exit 1)

# Final stage
FROM ${FTL_SOURCE}-ftl-install AS final

HEALTHCHECK CMD dig -p $(pihole-FTL --config dns.port) +short +norecurse +retry=0 @127.0.0.1 pi.hole || exit 1

ENTRYPOINT ["start.sh"]
