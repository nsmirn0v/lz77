$w = ""; # sliding window

if (@ARGV < 2 or @ARGV > 3) {
	print "usage: perl lz77.pl -c file (compress file)\n"; 
	print "       perl lz77.pl -d file new_file (decompress file and save it as new_file)\n"; 
	print "       perl lz77.pl -s \"string\" (compress and decompress a string outputting results)\n\n";
}
else {
	my $flag = $ARGV[0];

	if ($flag =~ /^-s$/) {
		my $compressed = compress($ARGV[1]);
		print "compressed: $compressed\n";

		$w = "";

		my $decompressed = decompress($compressed);
		print "decompress: \"$decompressed\"\n\n";
	}
	elsif ($flag =~ /^-c$/) {
		compressFile(@ARGV[1]);
	}
	elsif ($flag =~/^-d$/) {
		if (@ARGV != 3) {
			print "Error: invalid number of arguments (expecting 3)\n\n";
		}
		else {
			decompressFile(@ARGV[1], @ARGV[2]);
		}
	}
	else {
		print "Error: invalid flag: $flag\n\n";
	}
}

# Takes filename as an argument.
# Creates a compressed copy of specified file.
# The new file is called 'file'.compressed.
sub compressFile {
	my $file = shift();

	open(FILE, $file) or die("\nError: cannot open $file: $!");
	open(OUTPUT, ">$file.compressed") or die("Error: cannot open $file: $!");

	while (<FILE>) {
		print OUTPUT compress($_);
	}

	close(FILE) or die("Error: cannot close file: $!");
	close(OUTPUT) or die("\Error: cannot close file: $!");
	print "Compression complete.\n\n";
}

# Takes two arguments: 1st - the name of compressed file,
# 2nd - the name of a new file to be created.
sub decompressFile {
	my $file = shift();
	my $new_file = shift();
	$window = "";

	open(FILE, $file) or die("\Error: cannot open $file: $!");
	open(OUTPUT, ">$new_file") or die("\Error: cannot open $new_file: $!");

	while (<FILE>) {
		print OUTPUT decompress($_);
	}

	close(FILE) or die("\Error: cannot close file: $!");
	close(OUTPUT) or die("\Error: cannot close file: $!");
	print "Decompression complete.\n\n";
}

# Takes one string as an argument and returns
# compressed string.
sub compress {
	my $b = shift;	# buffer
	my $o = 0;			# offset
	my $l = 0;			# length
	my $p = "";			# pattern
	my $r = "";			# result

	while (length($b) > 0) {
		($b, $o, $l, $p) = find_match($b);
		$w .= $p;
		$r .= create_token($o, $l, substr($p, $l, 1));
	}

	return $r;
}

# Takes compressed sting as an argument and
# returns decompressed string.
sub decompress {
	my $line = shift();

	if ($line =~ /^\)?\n/s) {
		$w .= "\n";
		return "\n";
	}
	
	unless ($line =~ /\)$/s) {
		$line .= ")";
	}
	
	unless ($line =~ /^\(/) {
		$line = substr($line, 1, length($line) - 1);
	}
	
	my @tokens = splitLine($line);
	my $result = "";

	for (my $i = 0; $i < @tokens; $i++) {
		my $str = "";
		my @array = parseToken($tokens[$i]);

		my $o = $array[0];
		my $l = $array[1];
		my $char = $array[2];

		if ($o == 0) {
			$str .= $char;
		}
		elsif ($o < $l) {
			my $remainder = $l % $o;
			my $temp = substr($w, length($w) - $o) x ($l / $o);
			$temp .= substr($temp, 0, $remainder);
			$str .= $temp . $char;
		}
		else {
			$str .= substr($w, length($w) - $o, $l) . $char;
		}

		$w .= $str;
		$result .= $str;
	}
	
	if ($line =~ /\n$/s) {
		$w .= "\n";
		$result .= "\n";
	}

	return $result;
}

# Takes compressed string as an argument.
# Splits it into array of tokens and returns.
# Ex: $str = "(0,0,b)(0,0,y)(0,0,e)"
# 		@tokens = ["(0,0,b)", "(0,0,y)", "(0,0,e)"]
sub splitLine {
	my $str = shift();
	my @tokens = ();

	for (my $i = 0; $i < length($str); $i++) {
		my $token = "";
		my $done = 0;		
		
		while (not $done) {
			my $char = substr($str, $i, 1);
			$token .= substr($str, $i, 1);
			
			if (substr($str, $i, 1) eq ")" and substr($str, $i + 1, 1) eq "(" or $i >= length($str) - 1) {
				push(@tokens, $token);
				$done = 1;
			}
			else {
				$i++;
			}
		}
	}
	return @tokens;
}

# Takes a token string in a form of (o,l,c)
# and returns array with first element as offset,
# second - length, and third - next character.
sub parseToken {
	my $token = shift();
	my @result = ();

	if ($token =~ /^\((?<offset>\d*),(?<length>\d*),(?<char>.*)\)/s) {
		push(@result, $+{offset});	
		push(@result, $+{length});	
		push(@result, $+{char});	
		return @result;
	}
	else {
		die "Error parsing token\n";
	}
}

# Takes string (buffer) as an argument and
# returns offset and length of the best match,
# a pattern that was matched, and truncated buffer. 
sub find_match {
	my $b = shift;						# current buffer
	my $o = 0; 								# offset of the match
	my $l = 0;								# length of the match
	my $p = substr($b, 0, 1); # pattern to look for

	my @offsets = find_offsets($p);

	if (@offsets == 0) {
		return (substr($b, 1), $o, $l, substr($b, 0, 1));
	}
	else {
		($b, $o, $l, $p) = find_best_match($b, @offsets);
		
		if (substr($p, 0, 1) eq substr($b, 0, 1) and $o == length($p)) {
			($b, $l, $p) = check_buffer_for_repeating_pattern($p, $b);
		}
		else {
			$p .= substr($b, 0, 1);
			$b = substr($b, 1);
		}		

		return ($b, $o, $l, $p)
	}
}

# Takes one argument, a character to look for in the
# sliding window ($w), and returns array or offsets 
# (from right to left) of all occurances of the character
# in sliding window.
sub find_offsets {
	my $c = shift;			# char to look for
	my $o = length($w); # initial offset
	my @offsets = ();		# array containing offsets of all occurances of 
											# char in the window (from the right side)

	while (($o = rindex($w, $c, $o)) != -1) {
		push(@offsets, length($w) - $o);
		$o -= 1;
	}
	return @offsets;
}

# Takes two arguments, 1st - string (buffer),
# 2nd - array of offsets. Then it loops trow array
# of offsets to find the longest match of buffer in
# sliding window. Then new buffer, offset, length, and 
# the pattern matched are returned.
sub find_best_match {
	my $b = shift;
	my @offsets = @_;
	my $l = 2;
	my $p = substr($b, 0, 1);

	while ($l <= length($b) and $l <= length($w)) {
		$p = substr($b, 0, $l); #	pattern to look for
		my @new_offsets = ();

		foreach my $o (@offsets) {
			my $temp = substr($w, length($w) - $o, $l);
			if ($p eq $temp) {
				push (@new_offsets, $o);
			}
		}
		if (@new_offsets == 0) {
			substr($p, length($p) - 1, 1, "");
			last;
		}
		else {
			@offsets = @new_offsets;
		}
		$l++;
	}
	return (substr($b, $l - 1), $offsets[0], $l - 1, $p);
}

# Takes two arguments, 1st - pattern to look for,
# 2nd - buffer. Then it tries to find if there are
# any occurances of pattern in look ahead buffer.
# Returns new buffer, length of the pattern matched,
# and the pattern that was matched.
sub check_buffer_for_repeating_pattern {
	my $p = shift; # pattern to look for
	my $b = shift; # buffer to search
	my $temp = "";

	if (length($b) > length($p)) {
		while (length($b) > 0) {
			if ($p eq substr($b, 0, length($p))) {
				$temp .= substr($b, 0, length($p), "");
			}
			else {
				last;
			}
		}
	}

	if (substr($p, 0, 1) eq substr($b, 0, 1)) {
		my $l = 2; # length

		while ($l < length($p)) {
			if (substr($p, 0, $l) eq substr($b, 0, $l)) {
				$l++;
			}
			else {
				last;
			}
		}
		$l--;
		my $i = 0;

		while (length($b) > 0) {
			if (substr($p, $i, $l) eq substr($b, 0, $l)) {
				$temp .= substr($b, 0, $l, "");
				$i += $l;
			}
			else {
				last;
			}
		}
	}

	$p .= $temp;
	$l = length($p);
	$p .= substr($b, 0, 1, "");
	return ($b, $l, $p);
}

# Takes three arguments, 1st - offset, 2nd - length,
# 3rd - next character, and return a token string 
# of the form (offset,length,character).
sub create_token {
	my $o = shift;
	my $l = shift;
	my $c = shift;

	return "($o,$l,$c)";
}
