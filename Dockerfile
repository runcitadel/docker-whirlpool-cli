FROM    debian:bullseye as builder

RUN     set -ex && \
        apt update && \
        apt install -y libevent-dev zlib1g-dev libssl-dev gcc make automake ca-certificates autoconf musl-dev coreutils gpg wget default-jdk 

# Install Tor
ENV     WHIRLPOOL_TOR_URL             https://dist.torproject.org
ENV     WHIRLPOOL_TOR_MIRROR_URL      https://tor.eff.org/dist
ENV     WHIRLPOOL_TOR_VERSION         0.4.6.9
ENV     WHIRLPOOL_TOR_GPG_KS_URI      hkp://keyserver.ubuntu.com:80
ENV     WHIRLPOOL_TOR_GPG_KEY1        0xEB5A896A28988BF5
ENV     WHIRLPOOL_TOR_GPG_KEY2        0xC218525819F78451
ENV     WHIRLPOOL_TOR_GPG_KEY3        0x21194EBB165733EA
ENV     WHIRLPOOL_TOR_GPG_KEY4        0x6AFEE6D49E92B601

RUN     set -ex && \
        mkdir -p /usr/local/src/ && \
        cd /usr/local/src && \
        res=0; \
        wget -qO "tor-$WHIRLPOOL_TOR_VERSION.tar.gz" "$WHIRLPOOL_TOR_URL/tor-$WHIRLPOOL_TOR_VERSION.tar.gz" || res=$?; \
        if [ $res -gt 0 ]; then \
          wget -qO "tor-$WHIRLPOOL_TOR_VERSION.tar.gz" "$WHIRLPOOL_TOR_MIRROR_URL/tor-$WHIRLPOOL_TOR_VERSION.tar.gz"; \
        fi && \
        res=0; \
        wget -qO "tor-$WHIRLPOOL_TOR_VERSION.tar.gz.asc" "$WHIRLPOOL_TOR_URL/tor-$WHIRLPOOL_TOR_VERSION.tar.gz.asc" || res=$?; \
        if [ $res -gt 0 ]; then \
          wget -qO "tor-$WHIRLPOOL_TOR_VERSION.tar.gz.asc" "$WHIRLPOOL_TOR_MIRROR_URL/tor-$WHIRLPOOL_TOR_VERSION.tar.gz.asc" ; \
        fi && \
        gpg --keyserver "$WHIRLPOOL_TOR_GPG_KS_URI" --recv-keys "$WHIRLPOOL_TOR_GPG_KEY1" && \
        gpg --keyserver "$WHIRLPOOL_TOR_GPG_KS_URI" --recv-keys "$WHIRLPOOL_TOR_GPG_KEY2" && \
        gpg --keyserver "$WHIRLPOOL_TOR_GPG_KS_URI" --recv-keys "$WHIRLPOOL_TOR_GPG_KEY3" && \
        gpg --keyserver "$WHIRLPOOL_TOR_GPG_KS_URI" --recv-keys "$WHIRLPOOL_TOR_GPG_KEY4" && \
        gpg --verify "tor-$WHIRLPOOL_TOR_VERSION.tar.gz.asc" && \
        tar -xzvf "tor-$WHIRLPOOL_TOR_VERSION.tar.gz" -C /usr/local/src && \
        mv "/usr/local/src/tor-$WHIRLPOOL_TOR_VERSION" /usr/local/src/tor-latest && \
        cd "/usr/local/src/tor-latest" && \
        ./configure \
            --disable-asciidoc \
            --sysconfdir=/etc \
            --disable-unittests && \
        make -j$(nproc) && \
        make install && \
        cd .. && \
        rm "tor-$WHIRLPOOL_TOR_VERSION.tar.gz" && \
        rm "tor-$WHIRLPOOL_TOR_VERSION.tar.gz.asc"

FROM debian:bullseye-slim

ENV     WHIRLPOOL_HOME                /home/whirlpool
ENV     WHIRLPOOL_DIR                 /usr/local/whirlpool-cli

RUN addgroup --system -gid 1000 whirlpool && \
        adduser --system --ingroup whirlpool -uid 1000 whirlpool && \
        mkdir -p "$WHIRLPOOL_HOME/.whirlpool-cli" && \
        chown -Rv whirlpool:whirlpool "$WHIRLPOOL_HOME" && \
        chmod -R 750 "$WHIRLPOOL_HOME" && \
        mkdir -p "$WHIRLPOOL_DIR"


# Libraries (linked)
COPY  --from=builder /usr/lib /usr/lib
# Copy all the TOR files
COPY  --from=builder /usr/local/bin/tor*  /usr/local/bin/

# We use make install, so this is required
RUN apt update && apt -y install wget && apt clean && rm -rf /var/lib/apt/lists/*

# Install whirlpool-cli
ENV     WHIRLPOOL_URL                 https://code.samourai.io/whirlpool/whirlpool-client-cli/uploads
ENV     WHIRLPOOL_VERSION             0.10.13
ENV     WHIRLPOOL_VERSION_HASH        c1bb32bac6d4b377f625c996387375c2
ENV     WHIRLPOOL_JAR                 "whirlpool-client-cli-$WHIRLPOOL_VERSION-run.jar"
ENV     WHIRLPOOL_SHA256              78894b934716988eddb8da6db9c6734a3ded416fe68434bedb730f71ded7649d

RUN     set -ex && \
        cd "$WHIRLPOOL_DIR" && \
        echo "$WHIRLPOOL_SHA256 *$WHIRLPOOL_JAR" > WHIRLPOOL_CHECKSUMS && \
        wget -qO "$WHIRLPOOL_JAR" "$WHIRLPOOL_URL/$WHIRLPOOL_VERSION_HASH/$WHIRLPOOL_JAR" && \
        sha256sum -c WHIRLPOOL_CHECKSUMS 2>&1 | grep OK && \
        mv "$WHIRLPOOL_JAR" whirlpool-client-cli-run.jar && \
        chown -Rv whirlpool:whirlpool "$WHIRLPOOL_DIR" && \
        chmod -R 750 "$WHIRLPOOL_DIR"

# Copy restart script
COPY    ./entrypoint.sh /entrypoint.sh

RUN     chown whirlpool:whirlpool /entrypoint.sh && \
        chmod u+x /entrypoint.sh && \
        chmod g+x /entrypoint.sh

# Expose HTTP API port
EXPOSE  8898

# Switch to user whirlpool
USER    whirlpool

ENTRYPOINT [ "/entrypoint.sh" ]