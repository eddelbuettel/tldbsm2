#!/bin/bash

test -d build && cd build

## cmake -DTILEDBSOMA_ENABLE_PYTHON=ON -DSUPERBUILD=OFF -DFORCE_BUILD_TILEDB=OFF -DDOWNLOAD_TILEDB_PREBUILT=OFF -DOVERRIDE_INSTALL_PREFIX=OFF -DCMAKE_INSTALL_PREFIX=/usr/local ..
##   simpler:
cmake -DTILEDBSOMA_BUILD_CLI=OFF -DTILEDBSOMA_ENABLE_TESTING=OFF -DOVERRIDE_INSTALL_PREFIX=OFF -DCMAKE_INSTALL_PREFIX=/usr/local ..
#cmake -DTILEDBSOMA_BUILD_CLI=OFF -DTILEDBSOMA_ENABLE_TESTING=ON -DOVERRIDE_INSTALL_PREFIX=OFF -DCMAKE_INSTALL_PREFIX=/usr/local ..

## then
make -j 8
make install-libtiledbsoma