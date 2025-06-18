#!/bin/bash
# note the path to python hard coded here might not be available on your machine!
# if so you can pass the path as a command line argument
echo $#
echo $0
if [ "$#" -eq 0 ]; then
  if [ -f "/usr/bin/python3.12" ]; then
    echo "Assuming we should use /usr/bin/python3.12 as the python version, if you'd prefer another version pass as the first argument"
    PYTHONBIN="/usr/bin/python3.12"
  else
    echo "The default python 3.12 was not found at /usr/bin/python3.12; you must specify a version to use as the first command line argument"
  fi
else
  PYTHONBIN=$1
fi

$PYTHONBIN -m venv .venv 
. .venv/bin/activate
pip install -r requirements.txt
pip install --upgrade pip
