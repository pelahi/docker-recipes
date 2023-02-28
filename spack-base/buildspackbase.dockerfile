# This recipe uses ubuntu as a base and 
# adds minimal packages with apt-get
# builds mpich and also some useful mpi packages for testing
# The labels present here will need to be updated

ARG BASE_IMAGE="pawsey:mpi-setonix"
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.created="2023-02"
LABEL org.opencontainers.image.authors="Pascal Jahan Elahi <pascaljelahi@gmail.com>"
LABEL org.opencontainers.image.documentation="https://github.com/"
LABEL org.opencontainers.image.source="https://github.com/pelahi/docker-recipes/spack-base/"
LABEL org.opencontainers.image.vendor="Pawsey Supercomputing Research Centre"
LABEL org.opencontainers.image.licenses="GNU GPL3.0"
LABEL org.opencontainers.image.title="Setonix compatible MPICH base with Spack added"
LABEL org.opencontainers.image.description="Common base image providing mpi compatible with cray-mpich used on Setonix"
LABEL org.opencontainers.image.base.name="pawsey/spack:mpibase:ubuntu20.04-mpich-setonix"


# build packages with spack
ARG SPACK_VERSION=v0.19
WORKDIR /root/spack
RUN echo "Setting up spack and building astro packages" \
    && git clone https://github.com/spack/spack \
    && cd spack \
    && git checkout releases/${SPACK_VERSION} \
    && rm -rf .git \
    # config spack \
    && ./bin/spack external find && ./bin/spack compiler find \
    # and also add python to externals 
    && pyver=$(python3 --version | awk '{print $2}') \
    && pipver=$(pip --version | awk '{print $2}') \
    && numpyver=$(pip freeze | grep numpy | sed "s:==: :g" | awk '{print $2}') \
    && scipyver=$(pip freeze | grep scipy | sed "s:==: :g" | awk '{print $2}') \
    && sixver=$(pip freeze | grep six | sed "s:==: :g" | awk '{print $2}') \
    # set the config 
    && echo "\n  python: \n\
    externals:\n\
    - spec: python@${pyver}\n\
      prefix: /usr\n\
    buildable: false\n\
  py-numpy:\n\
    externals:\n\
    - spec: py-numpy@${numpyver}\n\
      prefix: /usr\n\
    buildable: false\n\
  py-scipy:\n\
    externals:\n\
    - spec: py-scipy@${scipyver}\n\
      prefix: /usr\n\
    buildable: false\n\
  py-pip:\n\
    externals:\n\
    - spec: py-pip@${pipver}\n\
      prefix: /usr\n\
    buildable: false\n\
  py-six:\n\
    externals:\n\
    - spec: py-six@${sixver}\n\
      prefix: /usr\n\
    buildable: false\n\
  mpich:\n\
    externals:\n\
    - spec: mpich@3.4.3\n\
      prefix: /usr\n\
    buildable: false\n\
      " >> ~/.spack/packages.yaml \
    # installation path
    && echo "# project_wide: use appropriate install locations\n\
config:\n\
  install_tree:\n\
    root: /usr/bin/spack/\n\
" >> ~/.spack/config.yaml \
    # run spack to boostrap
    && ./bin/spack spec nano \
    && echo "Finished"

# and copy recipe
COPY add-spack.dockerfile /opt/docker-recipes/

