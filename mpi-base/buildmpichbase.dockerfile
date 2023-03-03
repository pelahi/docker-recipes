# This recipe uses ubuntu as a base and 
# adds minimal packages with apt-get
# builds mpich and also some useful mpi packages for testing
# The labels present here will need to be updated

ARG OS_VERSION="20.04"
FROM ubuntu:${OS_VERSION}

LABEL org.opencontainers.image.created="2023-02"
LABEL org.opencontainers.image.authors="Pascal Jahan Elahi <pascaljelahi@gmail.com>"
LABEL org.opencontainers.image.documentation="https://github.com/"
LABEL org.opencontainers.image.source="https://github.com/pelahi/docker-recipes/mpi-base/"
LABEL org.opencontainers.image.vendor="Pawsey Supercomputing Research Centre"
LABEL org.opencontainers.image.licenses="GNU GPL3.0"
LABEL org.opencontainers.image.title="Setonix compatible MPICH base"
LABEL org.opencontainers.image.description="Common base image providing mpi compatible with cray-mpich used on Setonix"
LABEL org.opencontainers.image.base.name="pawsey/mpibase:ubuntu${OS_VERSION}-mpich-setonix"

# syntax=docker/dockerfile:1 
# run apt-get install on a few packages
ENV DEBIAN_FRONTEND="noninteractive"
RUN apt-get update -qq \
    && apt-get -y --no-install-recommends install \
        build-essential \
        ca-certificates \
        gdb \
        gcc g++ gfortran \
        wget \
        git \
        python3-six python3-setuptools \
        patchelf strace ltrace \
        libcrypt-dev \ 
        libcurl4-openssl-dev \
        libpython3-dev \
        libreadline-dev \
        libssl-dev \
        sudo \
        autoconf \
        automake \
        bison \
        curl \
        flex \
        gcovr \
        gdb \
        libtool \
        m4 \
        make \
        openssh-server \
        patch \
        python3-numpy \
        python3-pip \
        python3-scipy \
        subversion \
        tzdata \
        valgrind \
        vim \
        wget \
        xsltproc \
        zlib1g-dev \
    && apt-get clean all \
    && rm -r /var/lib/apt/lists/* \
    && echo "Finished apt-get installs"

# Build MPICH
ARG MPI_VERSION="3.4.3"
ARG MPI_CONFIGURE_OPTIONS="--enable-fast=all,O3 --enable-fortran --enable-romio --prefix=/usr --with-device=ch4:ofi CC=gcc CXX=g++ FC=gfortran"
ARG MPI_MAKE_OPTIONS="-j4"
RUN mkdir -p /tmp/mpich-build \
      && cd /tmp/mpich-build \
      && wget http://www.mpich.org/static/downloads/${MPI_VERSION}/mpich-${MPI_VERSION}.tar.gz \
      && tar xvzf mpich-${MPI_VERSION}.tar.gz \
      && cd mpich-${MPI_VERSION}  \
      && ./configure ${MPI_CONFIGURE_OPTIONS} \
      && make ${MPI_MAKE_OPTIONS} && make install \
      && ldconfig \
      && cp -p /tmp/mpich-build/mpich-${MPI_VERSION}/examples/cpi /usr/bin/ \
      && cd / \
      && rm -rf /tmp/mpich-build

# Build OSU Benchmarks
ARG OSU_VERSION="6.2"
ARG OSU_CONFIGURE_OPTIONS="--prefix=/usr/local CC=mpicc CXX=mpicxx CFLAGS=-O3"
ARG OSU_MAKE_OPTIONS="-j4"
RUN mkdir -p /tmp/osu-benchmark-build \
      && cd /tmp/osu-benchmark-build \
      && wget https://mvapich.cse.ohio-state.edu/download/mvapich/osu-micro-benchmarks-${OSU_VERSION}.tar.gz \
      && tar xzvf osu-micro-benchmarks-${OSU_VERSION}.tar.gz \
      && cd osu-micro-benchmarks-${OSU_VERSION} \
      && ./configure ${OSU_CONFIGURE_OPTIONS} \
      && make ${OSU_MAKE_OPTIONS} \
      && make install \
      && cd / \
      && rm -rf /tmp/osu-benchmark-build
ENV PATH="/usr/local/libexec/osu-micro-benchmarks/mpi/collective:/usr/local/libexec/osu-micro-benchmarks/mpi/one-sided:/usr/local/libexec/osu-micro-benchmarks/mpi/pt2pt:/usr/local/libexec/osu-micro-benchmarks/mpi/startup:$PATH"

# Add a more complex set of tests for MPI as well 
RUN mkdir -p /opt/ \
      && cd /opt/ \
      && git clone https://github.com/pelahi/profile_util \
      && cd profile_util  \
      && sed -i "s:CXX=CC:CXX=g++:g" ./build_cpu.sh \
      && sed -i "s:MPICXX=CC:MPICXX=mpic++:g" ./build_cpu.sh \
      && ./build_cpu.sh \
      && cd examples/mpi/ \
      && make MPICXX=mpic++ \
      && cd ../../examples/openmp \
      && make CXX=g++ bin/openmpvec_cpp

# add mpi4py in the container 
RUN pip install mpi4py

RUN mkdir -p /container-scratch/

# and copy the recipe into the docker recipes directory
RUN mkdir -p /opt/docker-recipes/
COPY buildmpichbase.dockerfile /opt/docker-recipes/
