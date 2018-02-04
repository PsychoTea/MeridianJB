#!/bin/sh
for ((i=0; i<SCRIPT_INPUT_FILE_COUNT;i++))
do
  inputFile=`eval echo '$SCRIPT_INPUT_FILE_'$i`
  echo Running $inputFile...
  `$inputFile`
done
