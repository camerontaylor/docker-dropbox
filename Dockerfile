FROM debian:buster
MAINTAINER Cameron Taylor <camerontaylor@gmail.com>
ENV DEBIAN_FRONTEND noninteractive

# Install Dropbox installer - https://www.dropbox.com/install-linux
RUN apt-get -qqy update \
	# python3-gpg is required to verify binary signatures
	&& apt-get -qqy install curl python3-gpg \
	# Fetch and install the .deb file
	&& curl -sL https://www.dropbox.com/download?dl=packages/debian/dropbox_2019.02.14_amd64.deb > /tmp/dropbox.deb \
	&& apt install -y --fix-broken /tmp/dropbox.deb \
	# Perform image clean up.
	&& apt-get -qqy autoclean \
	&& rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
	# Create service account and set permissions.
	&& groupadd dropbox \
	&& useradd -m -d /dbox -c "Dropbox Daemon Account" -s /usr/sbin/nologin -g dropbox dropbox

# Dropbox is weird: it insists on downloading its binaries itself via 'dropbox
# start -i'. So we switch to 'dropbox' user temporarily and let it do its thing.
USER dropbox
RUN mkdir -p /dbox/.dropbox /dbox/.dropbox-dist /dbox/Dropbox /dbox/base \
	&& echo y | dropbox start -i

# Switch back to root, since the run script needs root privs to chmod to the user's preferrred UID
USER root

# Dropbox has the nasty tendency to update itself without asking. In the processs it fills the
# file system over time with rather large files written to /dbox and /tmp. The auto-update routine
# also tries to restart the dockerd process (PID 1) which causes the container to be terminated.
RUN mkdir -p /opt/dropbox \
	# Prevent dropbox to overwrite its binary
	&& mv /dbox/.dropbox-dist/dropbox-lnx* /opt/dropbox/ \
	&& mv /dbox/.dropbox-dist/dropboxd /opt/dropbox/ \
	&& mv /dbox/.dropbox-dist/VERSION /opt/dropbox/ \
	&& chmod 755 `find /opt/dropbox -name 'libdropbox_apex.so'` \
	&& rm -rf /dbox/.dropbox-dist \
	&& install -dm0 /dbox/.dropbox-dist \
	# Prevent dropbox to write update files
	&& chmod u-w /dbox \
	&& chmod o-w /tmp \
	&& chmod g-w /tmp \
	# Prepare for command line wrapper
	&& mv /usr/bin/dropbox /usr/bin/dropbox-cli

# Install init script and dropbox command line wrapper
COPY run /root/
COPY dropbox /usr/bin/dropbox

WORKDIR /dbox/Dropbox
EXPOSE 17500
VOLUME ["/dbox/.dropbox", "/dbox/Dropbox"]
ENTRYPOINT ["/root/run"]
