#!/bin/bash

pushd /nas1/UsersData/${USER%-*}/MR/Projects 2>&1 > /dev/null

tar -cjSvf /server/Linux/${USER%-*}/scripts.tar.bz2 --exclude "*.pyc" Resources/configs Resources/examples Scripts/Perl-scripts Scripts/Python-scripts Scripts/Python-modules Scripts/Perl-modules Scripts/Bash-Scripts/*.sh Scripts/Bash-Scripts/viewers -C /nas1/UsersData/${USER%-*}/MR/Tools AlgoMarker_python_API AutoValidation
popd 2>&1 > /dev/null

echo "The files are in: /server/Linux/${USER%-*}/scripts.tar.bz2"