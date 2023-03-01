# This recipe uses pawsey astrop-deps package 
# to add the ASKAP TOS packages
ARG BASE_IMAGE="pawsey:askap-astrodeps"
FROM ${BASE_IMAGE}

# need to pass ssh args
ARG SSH_KEY_PRI
ARG SSH_KEY_PUB
ARG SSH_KNOWNHOSTS 

# What version/branch of your repo do you want to build this container from?
# For tostool, we pick up the most recent head of master, so the REPO_VERSION 
# does not make much sense in this context.  
ARG REPO_NAME=tostool
ARG REPO_VERSION=2.0
ARG PY3VERSION=10

#  set build and install directories
ARG BUILD_DIR=/tmp/
ARG INSTALL_DIR=/usr/local/askappy/
WORKDIR /

# Record useful metadata: See https://docs.docker.com/config/labels-custom-metadata/
LABEL org.opencontainers.image.created="2023-02"
LABEL org.opencontainers.image.authors="Pascal Jahan Elahi <pascaljelahi@gmail.com>"
LABEL org.opencontainers.image.documentation="https://github.com/"
LABEL org.opencontainers.image.source="https://github.com/pelahi/docker-recipes/spack-base/"
LABEL org.opencontainers.image.vendor="Pawsey Supercomputing Research Centre"
LABEL org.opencontainers.image.licenses="GNU GPL3.0"
LABEL org.opencontainers.image.title="tostool"
LABEL org.opencontainers.image.description="The image provides ASKAP TOS tools \
needed by ASKAPpipeline to run various services and \
askap-python tools." 
LABEL org.opencontainers.image.base.name="askap/askaptos"

# Set default python to python3:
# this is specific to ubuntu
# will need to generalize
RUN update-alternatives --remove python /usr/bin/python2 \
      && update-alternatives --install /usr/bin/python python /usr/bin/python3 ${PY3VERSION} \
      && python3 -m pip install -U --force-reinstall pip \
      && pip3 install setuptools

# You may want to define the repo Ver as an environment variable:
ENV TOSTOOL_VERSION="${REPO_NAME}/${REPO_VERSION}"

RUN echo "Setting up ssh " \ 
    # setup ssh \ 
    && mkdir -p /root/.ssh && chmod 0700 /root/.ssh \
    && echo ${SSH_KEY_PRI} > /root/.ssh/id_rsa \
    # because using cat to pass the private key, need to reformat it \
    && sed -i 's| |\n|g' /root/.ssh/id_rsa \ 
    && numlines=$(wc -l /root/.ssh/id_rsa | awk '{print $1}') \
    && istart=$(($numlines - 4)) && iend=$(($istart - 4)) \ 
    && head -n ${istart} /root/.ssh/id_rsa | tail -n ${iend} > /root/.ssh/id_rsa.keyonly \
    && echo "-----BEGIN OPENSSH PRIVATE KEY-----" >> /root/.ssh/id_rsa.head \ 
    && echo "-----END OPENSSH PRIVATE KEY-----" >> /root/.ssh/id_rsa.tail \
    && cat /root/.ssh/id_rsa.head /root/.ssh/id_rsa.keyonly /root/.ssh/id_rsa.tail > /root/.ssh/id_rsa \
    && echo ${SSH_KEY_PUB} > /root/.ssh/id_rsa.pub \
    && echo ${SSH_KNOWNHOSTS} > /root/.ssh/known_hosts \
    # && ssh-keyscan bitbucket.csiro.au >> /root/.ssh/known_hostd \
    && chmod 700 /root/.ssh/id_rsa \ 
    && chown -R root:root /root/.ssh \ 
    && echo "IdentityFile /root/.ssh/id_rsa" >> ~/.ssh/config \
    # && echo "Host *" >> /root/.ssh/config \
    # && echo "User ubuntu" >> /root/.ssh/config \
    && echo "Host bitbucket.csiro.au\n\tStrictHostKeyChecking no\n" >> ~/.ssh/config \
    && echo "Finished setting up SSH" \
    && echo "Now building askappy stuff " \
    && . /usr/bin/setup-env.sh \
    && mkdir -p ${INSTALL_DIR} ${BUILD_DIR} \
    && git clone ssh://git@bitbucket.csiro.au:7999/askapsdp/askap-dev.git ${BUILD_DIR}/askap-dev \
    && cd ${BUILD_DIR}/askap-dev/deploy \
    && git checkout develop \
    # build the repositories 
    && gitclonetos="git clone ssh://git@bitbucket.csiro.au:7999/tos" \
    && ${gitclonetos}/python-askap.git ${BUILD_DIR}/python-askap \
    && pip3 install ${BUILD_DIR}/python-askap \
    && ${gitclonetos}/python-parset ${BUILD_DIR}/python-parset \
    && pip3 install ${BUILD_DIR}/python-parset \
    && ${gitclonetos}/askap-interfaces ${INSTALL_DIR}/askap-interfaces \
    && ${gitclonetos}/python-askap-interfaces ${BUILD_DIR}/python-askap-interfaces \ 
    && export SLICE_DIR="${INSTALL_DIR}/askap-interfaces" \
    && echo "SLICE_DIR=${SLICE_DIR}" \
    && pip3 install ${BUILD_DIR}/python-askap-interfaces \
    && ${gitclonetos}/python-iceutils ${BUILD_DIR}/python-iceutils \
    && pip3 install ${BUILD_DIR}/python-iceutils \
    && ${gitclonetos}/python-askap-cli.git ${BUILD_DIR}/python-askap-cli \
    && pip3 install ${BUILD_DIR}/python-askap-cli \
    # We'll need the ICE connection config 
    && cp ${BUILD_DIR}/askap-dev/config/tos-ice.cfg ${INSTALL_DIR} \
    && echo "Finished askappy"


# # Fetch the requirement file from the repo and install requirements:
# ## Fetch the requirement file from the repo and install requirements:
# ARG REQFILE=requirements.txt
# COPY ${REQFILE} /tmp/requirements.txt
RUN echo "Installing some requirements" \
    # && pip3 install --no-cache-dir -r requirements.txt \
    && pip3 install --no-cache-dir \
      reproject \
      aplpy \
      dask \
      casa-formats-io \
      patsy \
      python-casacore \
      mpi4py \
    && echo "Finished install requirements"

RUN cp ${BUILD_DIR}/askap-dev/config/tos-ice.cfg ${INSTALL_DIR} 
ENV ICE_CONFIG=${INSTALL_DIR}/tos-ice.cfg

# and copy the recipe into the docker recipes directory
COPY buildaskaptos.dockerfile /opt/docker-recipes/

# cp the /usr/bin/setup-env.sh to the singularity startup 
RUN mkdir -p /.singularity.d/env/ && \
    cp -p /usr/bin/setup-env.sh /.singularity.d/env/91-environment.sh
# Singularity: trick to source startup scripts using bash shell
RUN /bin/mv /bin/sh /bin/sh.original && /bin/ln -s /bin/bash /bin/sh


# Set up user space
# Add non-root user
ARG USER_NAME=yanda-user
ARG USER_UID=1000
ARG USER_GID=$USER_UID
RUN groupadd --gid $USER_GID $USER_NAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USER_NAME \
    && echo $USER_NAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USER_NAME \
    && chmod 0440 /etc/sudoers.d/$USER_NAME
USER ${USER_NAME}
ARG HOME=/home/yanda-user/
WORKDIR ${HOME}
RUN    echo "================================================================" > ${HOME}/WELCOME.txt \
    && echo "Welcome to Askapsoft ASKAPPY container!                " >> ${HOME}/WELCOME.txt \
    && echo "In this container your user name is "yanda-user".             " >> ${HOME}/WELCOME.txt \
    && echo "Executables are located in /usr/local/bin.                      " >> ${HOME}/WELCOME.txt \
    && echo "================================================================" >> ${HOME}/WELCOME.txt \
    && sed "s:#!/bin/bash::g" /usr/bin/setup-env.sh >> /home/yanda-user/.bashrc

CMD ["/bin/bash"]

