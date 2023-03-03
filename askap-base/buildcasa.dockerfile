# This recipe uses ubuntu as a base and 
# adds a variety of packages with spack (and a few with apt-get)
# Useful for building casacore/casarest/askapsoft on top of this
# The labels present here will need to be updated
ARG BASE_IMAGE="pawsey:astro-deps"
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.created="2023-02"
LABEL org.opencontainers.image.authors="Pascal Jahan Elahi <pascaljelahi@gmail.com>"
LABEL org.opencontainers.image.documentation="https://github.com/"
LABEL org.opencontainers.image.source="https://github.com/pelahi/docker-recipes/spack-base/"
LABEL org.opencontainers.image.vendor="Pawsey Supercomputing Research Centre"
LABEL org.opencontainers.image.licenses="GNU GPL3.0"
LABEL org.opencontainers.image.title="Add CASA to ASKAP/astro dependencies"
LABEL org.opencontainers.image.description="Manual compilation of casacore and casarest."
LABEL org.opencontainers.image.base.name="pawsey/casa:ubuntu20.04-mpich-setonix"


ARG CASACORE_VERSION=v3.5.0
ARG CASAREST_VERSION=v1.8.1
USER root

# build casacore and casarest
RUN echo "Building casacore " \
    && . /usr/bin/setup-env.sh \
    && mkdir -p /usr/local/share/casacore/data \
    && cd /usr/local/share/casacore/data \
    && wget ftp://ftp.astron.nl/outgoing/Measures/WSRT_Measures.ztar \
    && mv WSRT_Measures.ztar WSRT_Measures.tar.gz \
    && tar -zxf WSRT_Measures.tar.gz \
    && rm WSRT_Measures.tar.gz \
    && mkdir -p /var/lib/jenkins/workspace \
    # Build casacore \
    && cd /usr/local/share/casacore \
    && git clone https://github.com/casacore/casacore.git \
    && cd casacore \
    && git checkout ${CASACORE_VERSION} \
    # patch casacore as it is missing gsl dep in cmake (this might only work for v3.5.0)
    && echo -e 'diff --git a/CMakeLists.txt b/CMakeLists.txt\n\
index 7e48b3ff2..f49c7f1bb 100644\n\
--- a/CMakeLists.txt\n\
+++ b/CMakeLists.txt\n\
@@ -322,6 +322,7 @@ if (_usefortran)\n\
   endif()\n\
 endif()\n\
\n\
+find_package(GSL REQUIRED)\n\
 find_package (DL)\n\
 if (USE_READLINE)\n\
     find_package (Readline REQUIRED)\n\
@@ -390,6 +391,10 @@ if (HDF5_FOUND)\n\
     include_directories (${HDF5_INCLUDE_DIRS})\n\
     add_definitions(-DHAVE_HDF5)\n\
 endif (HDF5_FOUND)\n\
+if (GSL_FOUND)\n\
+    include_directories (${GSL_INCLUDE_DIR})\n\
+    add_definitions(-DHAVE_GSL)\n\
+endif (GSL_FOUND)\n\
\n\
 include_directories (${FFTW3_INCLUDE_DIRS})\n\
 add_definitions(-DHAVE_FFTW3)\n\
@@ -569,6 +574,7 @@ message (STATUS "DATA directory ........ = ${DATA_DIR}")\n\
 message (STATUS "DL library? ........... = ${DL_LIBRARIES}")\n\
 message (STATUS "Pthreads library? ..... = ${PTHREADS_LIBRARIES}")\n\
 message (STATUS "Readline library? ..... = ${READLINE_LIBRARIES}")\n\
+message (STATUS "GSL library? .......... = ${GSL_LIBRARIES}")\n\
 message (STATUS "BLAS library? ......... = ${BLAS_LIBRARIES}")\n\
 message (STATUS "LAPACK library? ....... = ${LAPACK_LIBRARIES}")\n\
 message (STATUS "WCS library? .......... = ${WCSLIB_LIBRARIES}")\n\
 ' > casacore.cmake.patch \
    && more casacore.cmake.patch \
    && git apply casacore.cmake.patch \
    && mkdir -p build \
    && cd build \
    && cmake -DCMAKE_CXX_COMPILER=mpicxx \
    -DUSE_FFTW3=ON -DDATA_DIR=/usr/local/share/casacore/data \
    -DUSE_OPENMP=ON -DUSE_HDF5=ON \
    -DBUILD_PYTHON=OFF -DBUILD_PYTHON3=ON \
    -DUSE_THREADS=ON -DCMAKE_BUILD_TYPE=Release .. \
    && make -j16 && make install \
    && cd ../ && rm -rf build && cd ../ && rm -rf casacore \
    # Build casarest \
    && cd /usr/local/share/casacore \
    && git clone https://github.com/casacore/casarest.git \
    && cd casarest \
    && git checkout ${CASAREST_VERSION} \
    # patch cmake for gsl (might only work for v1.8.1)
    && echo -e 'diff --git a/CMakeLists.txt b/CMakeLists.txt\n\
index 7e3a9b5..1c8dc40 100644\n\
--- a/CMakeLists.txt\n\
+++ b/CMakeLists.txt\n\
@@ -59,6 +59,7 @@ find_package(CFITSIO 3.030 REQUIRED) # Should pad to three decimal digits\n\
 find_package(WCSLIB 4.7 REQUIRED)    # needed for CASA\n\
 find_package(BLAS REQUIRED)\n\
 find_package(LAPACK REQUIRED)\n\
+find_package(GSL REQUIRED)\n\
 find_package(Boost REQUIRED COMPONENTS thread system)\n\
 find_package(HDF5)\n\
 if(HDF5_FOUND)\n\
@@ -89,6 +90,7 @@ INCLUDE_DIRECTORIES(${CASACORE_INCLUDE_DIR}\n\
     ${CASACORE_INCLUDE_DIR}\n\
     ${CFITSIO_INCLUDE_DIR}\n\
     ${WCSLIB_INCLUDE_DIR}\n\
+    ${GSL_INCLUDE_DIR}\n\
     ${HDF5_INCLUDE_DIRS}\n\
     ${Boost_INCLUDE_DIR}\n\
     ${CMAKE_CURRENT_SOURCE_DIR}\n\
@@ -97,6 +99,7 @@ INCLUDE_DIRECTORIES(${CASACORE_INCLUDE_DIR}\n\
 set(OTHER_LIBRARIES ${CASACORE_LIBRARIES}\n\
     ${WCSLIB_LIBRARIES}\n\
     ${CFITSIO_LIBRARIES}\n\
+    ${GSL_LIBRARIES}\n\
     ${HDF5_LIBRARIES}\n\
     ${Boost_LIBRARIES}\n\
 )\n\
' > casarest.cmake.patch \
    && git apply casarest.cmake.patch \
    && mkdir -p build \
    && cd build \
    && cmake -DCMAKE_CXX_COMPILER=mpicxx -DCMAKE_BUILD_TYPE=Release .. \
    && make -j16 && make install \
    && cd ../ && rm -rf build && cd ../ && rm -rf casarest \
    && pip install python-casacore \ 
    && echo "Finished"

# and copy the recipe into the docker recipes directory
COPY buildcasa.dockerfile /opt/docker-recipes/

# cp the /usr/bin/setup-env.sh to the singularity startup 
RUN mkdir -p /.singularity.d/env/ && \
    cp -p /usr/bin/setup-env.sh /.singularity.d/env/91-environment.sh
# Singularity: trick to source startup scripts using bash shell
RUN /bin/mv /bin/sh /bin/sh.original && /bin/ln -s /bin/bash /bin/sh

