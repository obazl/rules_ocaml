#!/bin/sh

echo "RUNNING switch.sh"

set -x

opam switch -y create $1 $2

# rc=-1
# while [ $rc -ne 0 ]
# do
#     sleep 1
#     msg=`opam switch set $1 2>&1 >/dev/null`
#     rc=$?
# done

# now wait for compiler install to complete
# rc=-1
# while [ $rc -ne 0 ]
# do
#     sleep 1
#     switch=`opam config var $1:version`
#     rc=$?
# done

# echo "rc: $? switch: $switch"
