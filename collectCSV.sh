#!/bin/bash


for i in logs_* ; 
do
  cd $i
  type=$(echo $i | sed 's/logs_//')
  ../logs2csv2.pl > "../$type.csv"
  cd ..
done

awk 'FNR==1 && NR!=1{next}1' ./*.csv > invar.csv

