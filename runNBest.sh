#!/bin/bash

if [ $# -ne 1 ] && [ $# -ne 2 ]; then
   echo "Usage: $0 input_phone_seq_file [nbest=1]"
   echo "ex. $0 example 100"
   echo ""
   echo "Notice the number of output is not exactly nbest."
   echo "The duplicated results are merged."
   exit -1;
fi

BIN=bin
SRC=src
LEX=lexicon

input=$1
output=output/output.txt

timitdic=$LEX/timitdic_v6.txt
rule=$LEX/rule_v3.out

tmpdir=$(mktemp -d)
nbest=1
[ $# -gt 1 ] && nbest=$2

[ $input == "-" ] && input=$tmpdir/input && cat /dev/stdin > $input
[ -f $input ] || exit -1;

# check neccessary files
files="$LEX/phones.60-48-39.map $timitdic $SRC/timit_norm_trans.pl $SRC/make_lexicon_fst.pl $SRC/add_disambig.pl fstaddselfloops"
for f in $files;
do
   [ -f $f ] || exit -1;
done

# make programs
make > /dev/null 2> /dev/null

#generate Lexicon.fst
if [ ! -f $LEX/Lexicon.fst ]; then
   cut -f3 $LEX/phones.60-48-39.map | grep -v "q" | sort | uniq > $LEX/phone_list

   echo "<eps> 0" > $LEX/phones_num
   awk '{ print $0 " " FNR }' $LEX/phone_list >> $LEX/phones_num

   grep -v -E "^;" $timitdic | sed -e 's/\///g' -e 's/[0-9]//g' -e 's/\~[a-zA-Z_\~]* / /g' > $LEX/lexicon.txt
   echo "<s> sil" >> $LEX/lexicon.txt
   echo "</s> sil" >> $LEX/lexicon.txt
   echo "SIL sil" >> $LEX/lexicon.txt
   paste $LEX/phone_list $LEX/phone_list >> $LEX/lexicon.txt

   ./$SRC/timit_norm_trans.pl -ignore -i $LEX/lexicon.txt -m $LEX/phones.60-48-39.map -from 60 -to 39 > $LEX/lexicon.39.txt

   cut -f1 -d ' ' $LEX/lexicon.39.txt | \
      cat - <(echo "#0") | \
      awk '{ print $0 " " FNR }' | \
      cat <(echo "<eps> 0") - > $LEX/words.txt

   # add disambig
   ndisambig=`./$SRC/add_lex_disambig.pl $LEX/lexicon.39.txt $LEX/lexicon_disambig.txt` 
   ndisambig=$[$ndisambig+1];

   ./$SRC/add_disambig.pl --include-zero $LEX/phones_num $ndisambig  > $LEX/phones_disambig.txt 

   phone_disambig_symbol=`grep \#0 $LEX/phones_disambig.txt | awk '{print $2}'`
   word_disambig_symbol=`grep \#0 $LEX/words.txt | awk '{print $2}'`

   ./$SRC/make_lexicon_fst.pl $LEX/lexicon.39.txt 0.5 "sil" \
      | fstcompile --isymbols=$LEX/phones_disambig.txt \
      --osymbols=$LEX/words.txt --keep_isymbols=false --keep_osymbols=false \
      | ./fstaddselfloops  "echo $phone_disambig_symbol |" \
      "echo $word_disambig_symbol |" \
      | fstarcsort --sort_type=olabel > $LEX/Lexicon.fst 
fi

# generate input.fst
#   ./$SRC/timit_norm_trans.pl -i $input -m phones.60-48-39.map -from 60 -to 39 | sed -e 's/\bsil\b/ /g'| sed -e 's/  / /g' > $tmpdir/input.39 
#   
#   # read example
#   j=0; 
#   for phone in $(cat $tmpdir/input.39); 
#   do 
#      echo "$j $((j+1)) $phone $phone 0" >> $tmpdir/input.log
#      # deletion
#      #echo "$j $((j+1)) $phone <eps> 100" >> $tmpdir/input.log
#      ## substitution
#      #for tmp in $(cat phone_list | grep -w -v $phone);
#      #do
#      #   echo "$j $((j+1)) $phone $tmp 100" >> $tmpdir/input.log
#      #done
#      j=$((j+1))
#   done
#   echo "$j 0" >> $tmpdir/input.log

> $output
tempLine=$tmpdir/tempLine.txt

while read line;
do
   if [[ $line =~ ^[0-9]+$ ]]; then
      echo $line >> $output
   else
      # echo $nbest >> $output

      echo $line > $tempLine
      ./$BIN/generate $tempLine $LEX/phones.60-39.map $rule > $tmpdir/input.log
      
      fstcompile --isymbols=$LEX/phones_disambig.txt --osymbols=$LEX/phones_disambig.txt $tmpdir/input.log | \
         fstarcsort --sort_type=olabel > $tmpdir/input.fst

      command="fstcompose $tmpdir/input.fst $LEX/Lexicon.fst | \
         fstshortestpath --nshortest=$nbest | \
         ./fstprintallpath - $LEX/words.txt  "
      command+=" | sed "
      command+=" -e 's/<s>//g' -e 's/<\/s>//g' -e 's/SIL//g' "
      command+=" | sed -e \"s:':COMMA:g\" | sed "
      command+=$(while read phone; do echo " -e 's/\b${phone}\b/ /g'"; done < $LEX/phone_list)
      command+=" | sed -e \"s:COMMA:':g\" "
      command+=" | tr -s ' ' | sed -e 's/^ //g' | sort | uniq"
      command+=" >> $output"

      eval $command
   fi

done < $input

rm -rf $tmpdir

# use the following command to draw the fst.
# fstdraw --isymbols=phones_disambig.txt --osymbols=phones_disambig.txt -portrait input.fst | \
#   dot -Tsvg >ex.svg
exit 0;
