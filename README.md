=Implementation of LZ77 compression algorithm in PERL.

usage: perl lz77.pl -c file (compress file)
       perl lz77.pl -d file new_file (decompress file and save it as new_file)
       perl lz77.pl -s "string" (compress and decompress a string outputting results)

$ perl lz77.pl -s "hellohellohellohello"
compressed: (0,0,h)(0,0,e)(0,0,l)(1,1,o)(5,15,)
decompress: "hellohellohellohello"

