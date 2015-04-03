#!/bin/sh

# usage function to display help

usage ()
{
     mycmd=`basename $0`
     echo "$mycmd"
     echo "usage: $mycmd plistfile"
     echo
     echo "Prints the contents of the plistfile to stdout in JSON format"
}


# test if we have an arguments on the command line
if [ $# -lt 1 ]
then
    usage
    exit
fi

# check existence of file, exit if it doesn't exist
ls "$1" 1>/dev/null
rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi

# create temp file for the result
mycmd=$(basename $0)
tmpfile=$(mktemp -t "$mycmd.")
echo "Using the following tempfile for conversion: $tmpfile" >&2

plutil -convert json -o "$tmpfile" "$1" 2>/dev/null

# save result of that command for after we clean up
result=$?

cat "$tmpfile"
rm -f "$tmpfile"

# exit with return value from plutil
exit $result
