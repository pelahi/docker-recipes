# This recipe uses pawsey astrop-deps package 
# to add the ASKAP TOS packages
ARG BASE_IMAGE="pawsey:askap-astrodeps"
FROM ${BASE_IMAGE}

# Record useful metadata: See https://docs.docker.com/config/labels-custom-metadata/
LABEL org.opencontainers.image.created="2023-02"
LABEL org.opencontainers.image.authors="Pascal Jahan Elahi <pascaljelahi@gmail.com>"
LABEL org.opencontainers.image.documentation="https://github.com/"
LABEL org.opencontainers.image.source="https://github.com/pelahi/docker-recipes/spack-base/"
LABEL org.opencontainers.image.vendor="Pawsey Supercomputing Research Centre"
LABEL org.opencontainers.image.licenses="GNU GPL3.0"
LABEL org.opencontainers.image.title="askapsoft"
LABEL org.opencontainers.image.description="The image provides ASKAPSOFT \
needed to process ASKAP data." 
LABEL org.opencontainers.image.base.name="askap/askapsoft"

# Set Cmake parameter 
WORKDIR /askap/config 
RUN echo 'set ( ASKAPSDP_GIT_URL  git@gitlab.com:ASKAPSDP  CACHE  STRING  "git repo location" FORCE )' \
    > askap.gitlab.cmake.in 
# Get test data 
WORKDIR /askap/data 

# silly fix for boost and log4cxx and logfilters where header files from boost are copied
# to /usr/include/
RUN echo "Silly fix" \
    && boostdir=$(find /usr/bin/spack/ -name boost* | head -n 1) \
    && cp -r ${boostdir}/include/boost /usr/include/ \
    && gsldir=$(find /usr/bin/spack/ -name gsl* | grep gsl- | head -n 1) \
    && cp -r ${gsldir}/include/gsl /usr/include/ \
    && echo "Done"

ARG SSH_KEY_PRI
ARG SSH_KEY_PUB
ARG SSH_KNOWNHOSTS 
ARG ASKAPSOFT_VERSION=1.9.1
# ENV DEV_OVERRIDES=/home/askap-askapsoft/dev_overrides.txt 
WORKDIR /home 
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
    && echo "building askapsoft " \
    && . /usr/bin/setup-env.sh \
    # now clone and build yandasoft \
    && git clone ssh://git@bitbucket.csiro.au:7999/askapsdp/askap-askapsoft.git \
    # && dev_overrides.txt /home/askap-askapsoft \
    && cd /home/askap-askapsoft/ \
    && git checkout ${ASKAPSOFT_VERSION} \
    # ***************** Modify askap-askapsoft - this is a hack \
    && sed -i 's|https://bitbucket.*|ssh://git@bitbucket.csiro.au:7999/askapsdp/askap-cmake.git|' CMakeLists.txt \
    && sed -i 's|askap-interfaces askap-sms askap-pipelinetasks|#|' CMakeLists.txt \
    # ***************** 
    && mkdir -p build && cd build \
    && pwd && ls ../ \
    && cmake \
    -DCMAKE_CXX_COMPILER=mpicxx -DCMAKE_CXX_FLAGS="-I/usr/local/include -pthread" \
    -DCMAKE_BUILD_TYPE=Release -DGIT_CLONE_METHOD=SSH -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DENABLE_OPENMP=YES \
    -DBUILD_ANALYSIS=ON -DBUILD_PIPELINE=ON -DBUILD_COMPONENTS=ON -DBUILD_SERVICES=ON -DUSE_SMS=ON \
    .. \
    && make -j8 && make install \
    && cd ../ && rm -rf build \
    && rm -rf /root/.ssh/* \
    && rm -rf /home/askap-askapsoft \
    && echo "Finished ASKAPSOFT ${ASKAPSOFT_VERSION}"     

# Setup executables so that they are bash wrappers that source 
# all necessary scripts and set up all necessary paths
RUN echo "Setting up the commands " \
    && echo '#!/bin/bash \n\
. /usr/bin/setup-env.sh \n\
export LD_LIBRARY_PATH=/usr/local/askapsoft/1.9.1-dirty/lib/:$LD_LIBRARY_PATH \n\
export PATH=/usr/local/askapsoft/1.9.1-dirty/bin/:$PATH \n\
cmd="$(basename $0)" \n\
args="$@" \n\
$cmd $args \n\
' >> /usr/bin/.askapsoft-cmd.sh \
    && chmod a+rx /usr/bin/.askapsoft-cmd.sh \
    && cd /usr/local/askapsoft/1.9.1-dirty/bin/ \
    && listofcmds=`ls | tr '\n' ' '` \
    && cd /usr/bin/ \
    && for cmd in $(echo ${listofcmds} | tr ' ' '\n'); do ln -s .askapsoft-cmd.sh ${cmd}; done \
    && echo "Done setting up"

# and copy the recipe into the docker recipes directory
COPY buildaskapsoft.dockerfile /opt/docker-recipes/

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
    && echo "Welcome to Askapsoft container!                " >> ${HOME}/WELCOME.txt \
    && echo "In this container your user name is "yanda-user".             " >> ${HOME}/WELCOME.txt \
    && echo "Executables are located in /usr/local/bin.                      " >> ${HOME}/WELCOME.txt \
    && echo "================================================================" >> ${HOME}/WELCOME.txt \
    && sed "s:#!/bin/bash::g" /usr/bin/setup-env.sh >> /home/yanda-user/.bashrc  

CMD ["/bin/bash"] 
