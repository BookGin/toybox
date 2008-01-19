#!/bin/bash

# Grab default values for $CFLAGS and such.

source ./configure

echo "Extract configuration information from toys/*.c files."
scripts/genconfig.sh

# Only recreate generated/help.h if python is installed
if [ ! -z "$(which python)" ] && [ ! -z "$(grep 'CONFIG_HELP=y' .config)" ]
then
  echo "Extract help text from Config.in."
  scripts/config2help.py Config.in > generated/help.h || exit 1
fi

echo "Make generated/config.h from .config."

# This long and roundabout sed invocation is to make old versions of sed happy.
# New ones have '\n' so can replace one line with two without all the branches
# and tedious mucking about with hold space.

sed -n -e 's/^# CONFIG_\(.*\) is not set.*/\1/' \
  -e 't notset' -e 'b tryisset' -e ':notset' \
  -e 'h' -e 's/.*/#define CFG_& 0/p' \
  -e 'g' -e 's/.*/#define USE_&(...)/p' -e 'd' -e ':tryisset' \
  -e 's/^CONFIG_\(.*\)=y.*/\1/' -e 't isset' -e 'd' -e ':isset' \
  -e 'h' -e 's/.*/#define CFG_& 1/p' \
  -e 'g' -e 's/.*/#define USE_&(...) __VA_ARGS__/p' .config > \
  generated/config.h || exit 1

#for i in $(echo toys/*.c | sort)
#do
  # Grab the function command names
  # NAME=$(echo $i | sed -e 's@toys/@@' -e 's@\.c@@')
  #sed -n '/struct '$NAME'_command {/,/};/p' $i \
  #	>> generated/globals_big.h
  #  echo "struct ${NAME}_command;" >> generated/globals.h
#done

# Extract a list of toys/*.c files to compile from the data in ".config" with
# sed, sort, and tr:

# 1) Grab the XXX part of all CONFIG_XXX entries, removing everything after the
# second underline
# 2) Sort the list, keeping only one of each entry.
# 3) Convert to lower case.
# 4) Remove toybox itself from the list (as that indicates global symbols).
# 5) Add "toys/" prefix and ".c" suffix.

TOYFILES=$(cat .config | sed -nre 's/^CONFIG_(.*)=y/\1/;t skip;b;:skip;s/_.*//;p' | sort -u | tr A-Z a-z | grep -v '^toybox$' | sed 's@\(.*\)@toys/\1.c@' )

echo "Compile toybox..."

$DEBUG $CC $CFLAGS -I . -o toybox_unstripped $OPTIMIZE main.c lib/*.c $TOYFILES
$DEBUG $STRIP toybox_unstripped -o toybox
