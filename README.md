# Final-LexiconWFST
A modified version of TA's Lexicon_WFST

## Install openfst
 - Download [OpenFST](http://www.openfst.org/twiki/bin/view/FST/WebHome)
 - untar it!
 - ./configure && make && sudo make install
 
## How to use
 ```./runLine.sh input/example.txt 10```

 or
 
 ```./runNBest.sh input/example_runNBest.txt 10```
 
 and the output will be output/output.txt

 To know the input file format, simply read "example.txt" or "example_runNBest.txt".

 > Important: If timitdict is edited, remove lexicon/Lexicon.fst before running.

## Remarks
 the Makefile is not working now
