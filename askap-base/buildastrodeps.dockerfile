# This recipe uses ubuntu as a base and 
# adds a variety of packages with spack (and a few with apt-get)
# Useful for building casacore/casarest/askapsoft on top of this
# The labels present here will need to be updated
ARG BASE_IMAGE="pawsey:spack"
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.created="2023-02"
LABEL org.opencontainers.image.authors="Pascal Jahan Elahi <pascaljelahi@gmail.com>"
LABEL org.opencontainers.image.documentation="https://github.com/"
LABEL org.opencontainers.image.source="https://github.com/pelahi/docker-recipes/spack-base/"
LABEL org.opencontainers.image.vendor="Pawsey Supercomputing Research Centre"
LABEL org.opencontainers.image.licenses="GNU GPL3.0"
LABEL org.opencontainers.image.title="ASKAP/astro dependencies"
LABEL org.opencontainers.image.description="Uses apt-get (a bit) and spack to install askap/astro packages."
LABEL org.opencontainers.image.base.name="pawsey/askap-astrodeps:ubuntu20.04-mpich-setonix"

# syntax=docker/dockerfile:1 
# install a few specific packages with apt-get
ENV DEBIAN_FRONTEND="noninteractive"
RUN echo "Starting apt-get installs" \
    && apt-get update -qq \
    && apt-get -y --no-install-recommends install \
        zeroc-ice-all-dev \
        zeroc-ice-all-runtime \
    && apt-get clean all \
    && rm -r /var/lib/apt/lists/* \
    && echo "Finished apt-get installs"

# build packages with spack
# first set configuration for compilers
# note that to build optimized archiecture specific
# builds try something like 
# docker build --build-arg SPACK_CPPFLAGS="-O3" --build-arg SPACK_CFLAGS="-O3" --build-arg SPACK_FFLAGS="-O3" --build-arg SPACK_TARGET="zen3"
# default values are little optimisation and for all x86_64 targets
ARG SPACK_CPPFLAGS="-O2 -fPIC"
ARG SPACK_CFLAGS="-O2 -fPIC"
ARG SPACK_FFLAGS="-O2 -fPIC"
ARG SPACK_TARGET="x86_64"
ARG spack_compilerspec="target=${SPACK_TARGET} cppflags=='${SPACK_CPPFLAGS}' cflags=='${SPACK_CFLAGS}' fflags=='${SPACK_FFLAGS}' " 
# store the build flags in the metadata 
LABEL org.opencontainers.image.buildflags="${spack_compilerspec}"

ARG spack_install="/root/spack/spack/bin/spack install -j16 --reuse "
RUN echo "Building packages with spack" \
    # run spack find given new sets of packages installed
    && /root/spack/spack/bin/spack external find \
    # install packages. For layering try splitting 
    # build into math and then astro packages 
    && ${spack_install} \
        readline ${spack_compilerspec} \
        bzip2 ${spack_compilerspec} \
        openssl ${spack_compilerspec} \
    && ${spack_install} \
        openblas@0.3.15 threads=openmp ${spack_compilerspec}\
    && ${spack_install} \
        fftw@3.3.9 +openmp precision=float,double,long_double ${spack_compilerspec} \
    && ${spack_install} \
        gsl@2.6 ${spack_compilerspec} \
    && ${spack_install} \
        hdf5@1.10.8 +hl api=v110 ${spack_compilerspec} \
    && echo "Finished"
RUN /root/spack/spack/bin/spack find -lvdf
RUN echo " Building astro packages " \
    && ${spack_install} \
        boost@1.80.0 +mpi +numpy +python +pic +system +thread +program_options +filesystem +signals +regex +chrono cxxstd=98 ${spack_compilerspec} \
    && ${spack_install} \
        cfitsio ${spack_compilerspec} \
    && ${spack_install} \
        wcslib +cfitsio ${spack_compilerspec} \
    && ${spack_install} \
        libzmq ${spack_compilerspec} \
    && ${spack_install} \
        cppzmq ${spack_compilerspec} \
    && ${spack_install} \
        apr ${spack_compilerspec} \
    && ${spack_install} \
        apr-util ${spack_compilerspec} \
    && ${spack_install} \
        cppunit ${spack_compilerspec} \
    && ${spack_install} \
        log4cxx cxxstd=11 ^boost@1.80.0 +mpi +numpy +python +pic +system +thread +program_options +filesystem +signals +regex +chrono cxxstd=98 ${spack_compilerspec} \
    && ${spack_install} \
        mcpp ${spack_compilerspec} \
    && ${spack_install} \
        xerces-c ${spack_compilerspec} \
    && echo "Finished"
RUN echo " Building plotting packages " \
    && ${spack_install} \
        imagemagick ${spack_compilerspec} \
    && echo "Finished"
RUN echo "Update setup-env script to load packages installed by spack" \
    # generate script that will setup paths
    && echo "#!/bin/bash" > /usr/bin/setup-env.sh \
    && /root/spack/spack/bin/spack load --only package --sh \
        fftw \
        gsl \
        hdf5 \
        openblas \
        boost \
        cfitsio \
        wcslib \
        cppzmq \
        libzmq \
        apr \
        apr-util \
        cppunit \
        log4cxx \
        mcpp \
        xerces-c \
        cmake \
        >> /usr/bin/setup-env.sh \ 
    # for imagemagick and other plotting also load dependencies
    # to do this, first load previous environment to spack will auto add
    # it to the script 
    && . /usr/bin/setup-env.sh \
    # now create new script with imagemagick loaded along with all deps
    && echo "#!/bin/bash" > /usr/bin/setup-env.sh \
    && /root/spack/spack/bin/spack load --sh \
        imagemagick \
        >> /usr/bin/setup-env.sh \ 
    # clean up all spack related builds
    && /root/spack/spack/bin/spack clean -a \
    # remove spack if desired, keeps container smaller 
    # setup the environment to load the appropriate paths 
    && chmod a+rx /usr/bin/setup-env.sh \
    && more /usr/bin/setup-env.sh | grep "export PATH" | \
    sed "s:/usr/bin/spack/:/foo/:g" | sed "s:/bin:/lib:g" | sed "s:/foo/:/usr/bin/spack/:g" | \
    sed "s:export PATH:export LD_LIBRARY_PATH:g" > /root/ld_update.sh \ 
    && cat /root/ld_update.sh >> /usr/bin/setup-env.sh \ 
    && rm /root/ld_update.sh \
    && echo "Finished"

# install some python packages 
RUN echo "Install some packages via pip" \
    && pip install pandas astroquery \
    && echo "Finished"

# and copy the recipe into the docker recipes directory
COPY buildastrodeps.dockerfile /opt/docker-recipes/

# cp the /usr/bin/setup-env.sh to the singularity startup 
RUN mkdir -p /.singularity.d/env/ && \
    cp -p /usr/bin/setup-env.sh /.singularity.d/env/91-environment.sh
# Singularity: trick to source startup scripts using bash shell
RUN /bin/mv /bin/sh /bin/sh.original && /bin/ln -s /bin/bash /bin/sh
