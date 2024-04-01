#!/bin/bash

python3 -m pip install -v -e .

## OLD below
#python3 setup.py build_ext --inplace
#echo "Done -- now running 'sudo python3 setup.py install'"
#echo "Consider running 'sudo pip3 uninstall tiledb' first"
#sudo python3 setup.py install
## also see https://docs.python.org/3/install/

## also per https://stackoverflow.com/questions/38913502/
#pip install --install-option="--prefix=/usr/local/bin"
