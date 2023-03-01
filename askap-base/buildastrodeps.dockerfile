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
ARG SPACK_CPPFLAGS="-O0"
ARG SPACK_CFLAGS="-O0"
ARG SPACK_FFLAGS="-O0"
ARG SPACK_TARGET="x86_64"

RUN echo "Building astro packages with spack" \
    && export compilerspec="%gcc target=${SPACK_TARGET} cppflags='${SPACK_CPPFLAGS}' cflags='${SPACK_CFLAGS}' fflags='${SPACK_FFLAGS}' " \
    # install packages 
    && /root/spack/spack/bin/spack install -j16 \
        openblas@0.3.15 threads=openmp ${compilerspec}\
        fftw@3.3.9 +openmp precision=float,double,long_double ${compilerspec} \
        gsl@2.6 ${compilerspec} \
        hdf5@1.10.8 +hl api=v110 ${compilerspec} \
        boost@1.80.0 +mpi +numpy +python +pic +system +thread +program_options +filesystem +signals +regex +chrono cxxstd=98 ${compilerspec} \
        cfitsio ${compilerspec} \
        wcslib +cfitsio ${compilerspec} \
        cppzmq ${compilerspec} \
        libzmq ${compilerspec} \
        apr ${compilerspec} \
        apr-util ${compilerspec} \
        cppunit ${compilerspec} \
        log4cxx cxxstd=11 ^boost@1.80.0 +mpi +numpy +python +pic +system +thread +program_options +filesystem +signals +regex +chrono cxxstd=98 ${compilerspec} \
        mcpp ${compilerspec} \
        xerces-c ${compilerspec} \
    && /root/spack/spack/bin/spack install -j16 \
        imagemagick ${compilerspec}\
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
        imagemagick \
        cmake \
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
    && pip install pandas astroquery
    && echo "Finished"

# and copy the recipe into the docker recipes directory
COPY buildastrodeps.dockerfile /opt/docker-recipes/

# cp the /usr/bin/setup-env.sh to the singularity startup 
RUN mkdir -p /.singularity.d/env/ && \
    cp -p /usr/bin/setup-env.sh /.singularity.d/env/91-environment.sh
# Singularity: trick to source startup scripts using bash shell
RUN /bin/mv /bin/sh /bin/sh.original && /bin/ln -s /bin/bash /bin/sh
