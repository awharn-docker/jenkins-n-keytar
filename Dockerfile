# This Dockerfile is used to build an image capable of running the npm keytar node module
# It must be given the capability of IPC_LOCK or be run in privilaged mode to properly operate
FROM ubuntu:noble

USER root

ARG IMAGE_VERSION_ARG
ARG DEFAULT_NODE_VERSION=${IMAGE_VERSION_ARG:-20}
ENV DEBIAN_FRONTEND="noninteractive"

# Change source list to use HTTPS mirror
RUN apt-get -q update &&\
    apt-get -qqy install --no-install-recommends ca-certificates &&\
    sed -i 's/deb http:\/\/archive.ubuntu.com\/ubuntu\//deb https:\/\/mirrors.wikimedia.org\/ubuntu\//g' /etc/apt/sources.list &&\
    sed -i 's/deb http:\/\/security.ubuntu.com\/ubuntu\//deb https:\/\/mirrors.wikimedia.org\/ubuntu\//g' /etc/apt/sources.list

# Upgrade and install packages, use HTTPS mirrors
RUN apt-get -q update &&\
    apt-get -qqy upgrade --no-install-recommends &&\
    apt-get -qqy install --no-install-recommends locales sudo xxd wget unzip zip git curl libxss1 sshpass vim nano expect build-essential software-properties-common gnome-keyring libsecret-1-dev dbus-x11 rsync &&\
    locale-gen en_US.UTF-8 &&\
    apt-get -qqy install --no-install-recommends openssh-server &&\
    apt-get -q autoremove &&\
    sed -i 's|session    required     pam_loginuid.so|session    optional     pam_loginuid.so|g' /etc/pam.d/sshd &&\
    mkdir -p /var/run/sshd &&\
    # Install JDK 11 and 17
    # Add node version 20 which should bring in npm, add maven and build essentials and required ssl certificates to contact maven central
    # expect is also installed so that you can use that to login to your npm registry if you need to
    curl -sL "https://deb.nodesource.com/setup_$DEFAULT_NODE_VERSION.x" | bash - &&\
    apt-get -q update &&\
    apt-get -qqy install --no-install-recommends nodejs openjdk-17-jre-headless openjdk-11-jre-headless openjdk-17-jdk openjdk-11-jdk maven ca-certificates-java &&\
    update-ca-certificates -f &&\
    apt-get -q autoremove &&\
    ## Install GH CLI
    (type -p wget >/dev/null || (sudo apt update && sudo apt-get install wget -y)) &&\
    mkdir -p -m 755 /etc/apt/keyrings &&\
    out=$(mktemp) &&\
    wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg &&\
    cat $out | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null &&\
	chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg &&\
	echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null &&\
	apt-get -q update &&\
	apt-get -qqy install gh &&\
    apt-get -q clean -y &&\
    rm -rf /var/lib/apt/lists/* /var/cache/apt/*.bin

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Get rid of dash and use bash instead
RUN echo "dash dash/sh boolean false" | debconf-set-selections
RUN dpkg-reconfigure dash

ENV JAVA_HOME_AMD=/usr/lib/jvm/java-11-openjdk-amd64
ENV JAVA_HOME_ARM=/usr/lib/jvm/java-11-openjdk-arm64

# Add Jenkins user
RUN useradd jenkins --shell /bin/bash --create-home
RUN usermod -a -G sudo jenkins
RUN echo 'ALL ALL = (ALL) NOPASSWD: ALL' >> /etc/sudoers
RUN echo 'jenkins:jenkins' | chpasswd

COPY openssl.cnf /etc/ssl/openssl.cnf

# dd the jenkins users
RUN groupadd npmusers
RUN usermod -aG npmusers jenkins
RUN chown -R root:npmusers /usr/lib/node_modules && chmod -R 775 /usr/lib/node_modules
RUN mkdir -p /usr/local/lib/node_modules && chown -R root:npmusers /usr/local/lib/node_modules && chmod -R 775 /usr/local/lib/node_modules
RUN mkdir -p /usr/local/bin && chown -R root:npmusers /usr/local/bin && chmod -R 775 /usr/local/bin
RUN npm install -g n

# Also install rust for user jenkins
USER jenkins
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- --default-toolchain stable -y
USER root

ARG tempDir=/tmp/jenkins-n-keytar
ARG bashEnv=/etc/bash.bashrc
ARG shEnv=/etc/profile

# Next, make the file available to all to read and source
# RUN chmod +r /usr/local/env.sh
ENV ENV=${shEnv}

# Copy the setup script and node/n scripts for execution (allow anyone to run them)
ARG scriptsDir=/usr/local/bin/
COPY docker-entrypoint.sh ${scriptsDir}
COPY install_node.sh ${scriptsDir}

RUN install_node.sh ${DEFAULT_NODE_VERSION}

ARG sshEnv=/etc/profile.d/dbus_start.sh
ARG loginFile=pam.d.config

# Copy the PAM configuration options to allow auto unlocking of the gnome keyring
RUN mkdir ${tempDir}
COPY ${loginFile} ${tempDir}/${loginFile}
COPY env.profile ${tempDir}/env.profile
COPY local.profile ${tempDir}/.profile

# Enable unlocking for ssh
RUN cat ${tempDir}/${loginFile}>>/etc/pam.d/sshd

# Enable unlocking for regular login
RUN cat ${tempDir}/${loginFile}>>/etc/pam.d/login

# Copy the profile script 
COPY dbus_start ${tempDir}/dbus_start

# Enable dbus for ssh and most other native shells (interactive)
RUN touch ${sshEnv}
RUN echo '#!/bin/sh'>>${sshEnv}
RUN cat ${tempDir}/dbus_start>>${sshEnv}

# Enable for all bash profiles
# Add the dbus launch before exiting when not running interactively
RUN printf "\n. /etc/profile\n" >> /home/jenkins/.bashrc
RUN printf "\necho jenkins | gnome-keyring-daemon --unlock --components=secrets > /dev/null\n" >> /home/jenkins/.profile
RUN cat ${tempDir}/env.profile >> /etc/profile && cp ${tempDir}/.profile /home/jenkins/.profile && chown jenkins:jenkins /home/jenkins/.profile && cp ${tempDir}/.profile /root/.profile


# Cleanup any temp files we have created
RUN rm -rdf ${tempDir}

# Execute the setup script when the image is run. Setup will install the desired version via 
# nvm for both the root user and jenkins - then start the ssh service
ENTRYPOINT ["docker-entrypoint.sh"]

# Standard SSH port
EXPOSE 22

# Exec ssh
CMD ["/usr/sbin/sshd", "-D"]
