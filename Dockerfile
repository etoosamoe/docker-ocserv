FROM ubuntu:14.04

RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
		autoconf autogen ca-certificates curl gcc gnutls-bin \
		libdbus-1-dev libgnutls28-dev libnl-route-3-dev libpam0g-dev libreadline-dev libwrap0-dev \
		make pkg-config xz-utils \
# NOT FOUND?
# 		libfreeradius-client-dev liblz4-dev libsystemd-daemon-dev
# Use included:
# 		libhttp-parser-dev libpcl1-dev libprotobuf-c0-dev libtalloc-dev
	&& rm -r /var/lib/apt/lists/*

# Install LZ4
RUN set -x \
	&& LZ4_VERSION=`curl "https://github.com/Cyan4973/lz4/releases/latest" | sed -n 's/^.*tag\/\(.*\)".*/\1/p'` \
	&& curl -SL "https://github.com/Cyan4973/lz4/archive/$LZ4_VERSION.tar.gz" -o lz4.tar.gz \
	&& mkdir -p /usr/src/lz4 \
	&& tar -xf lz4.tar.gz -C /usr/src/lz4 --strip-components=1 \
	&& rm lz4.tar.gz \
	&& cd /usr/src/lz4 \
	&& make -j"$(nproc)" \
	&& make install \
	&& make clean

# Install OpenConnect Server
RUN set -x \
	&& OC_VERSION=`curl "http://www.infradead.org/ocserv/download.html" | sed -n 's/^.*version is <b>\(.*$\)/\1/p'` \
	&& curl -SL "ftp://ftp.infradead.org/pub/ocserv/ocserv-$OC_VERSION.tar.xz" -o ocserv.tar.xz \
	&& curl -SL "ftp://ftp.infradead.org/pub/ocserv/ocserv-$OC_VERSION.tar.xz.sig" -o ocserv.tar.xz.sig \
	&& gpg --keyserver pgp.mit.edu --recv-key 96865171 \
	&& gpg --verify ocserv.tar.xz.sig \
	&& mkdir -p /usr/src/ocserv \
	&& tar -xf ocserv.tar.xz -C /usr/src/ocserv --strip-components=1 \
	&& rm ocserv.tar.xz* \
	&& cd /usr/src/ocserv \
	&& ./configure --enable-linux-namespaces \
	&& make -j"$(nproc)" \
	&& make install \
	&& make clean

# Setup config
COPY route.txt /tmp/
RUN set -x \
	&& mkdir -p /etc/ocserv \
	&& cp /usr/src/ocserv/doc/sample.config /etc/ocserv/ocserv.conf \
	&& sed -i 's/\.\/sample\.passwd/\/etc\/ocserv\/ocpasswd/' /etc/ocserv/ocserv.conf \
	&& sed -i 's/\.\.\/test/\/etc\/ocserv/' /etc/ocserv/ocserv.conf \
	&& sed -i '/^ipv4-network = /{s/192.168.1.0/192.168.0.0/}' /etc/ocserv/ocserv.conf \
	&& sed -i 's/192.168.1.2/8.8.8.8/' /etc/ocserv/ocserv.conf \
	&& sed -i 's/^route/#route/' /etc/ocserv/ocserv.conf \
	&& cat /tmp/route.txt >> /etc/ocserv/ocserv.conf \
	&& rm -fr /tmp/route.txt

COPY docker-entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 443
CMD ["ocserv", "-c", "/etc/ocserv/ocserv.conf", "-f"]