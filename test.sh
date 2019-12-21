#!/bin/bash
odin build tests/main.odin && ./main
RES=$?
echo ""
if [ $RES == 0 ] ; then
  echo "Tests succeeded"
  exit
fi

echo "\nTests failed"
