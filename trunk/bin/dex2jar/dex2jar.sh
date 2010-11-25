#!/bin/sh

IN_DIR=`dirname $0`

_classpath="."
for k in $IN_DIR/lib/*.jar
do
 _classpath="${_classpath}:${k}"
done

#DanCo - Added for debugging
echo "Dex2jar classpath: " ${_classpath}

java  -classpath "${_classpath}" "pxb.android.dex2jar.v3.Main" $1 $2 $3 $4 $5 $6
