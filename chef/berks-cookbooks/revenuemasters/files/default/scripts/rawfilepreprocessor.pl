#!/usr/bin/env perl

# usage: scriptname filename segment dataelement componentsubelement
my $header_search_string = "ISA";
my $segment_search_string = "CAS";

if ($#ARGV != 0) {
    die "Error: Wrong number of parameters.\nusage: scriptname filename segment dataelement componentsubelement\n";
}

open(my $fhinput, $ARGV[0]) || die "Error: $!\n";
@lines = <$fhinput>;
close($fhinput);

if (substr($lines[0], 0, 3) eq $header_search_string) {
    my $data_element_separator = substr($lines[0], 3, 1);
    my $temp_header = $lines[0];
    $temp_header =~ s/\r|\n//g;
    $segment_separator = substr $temp_header, -1;
    # we use the same filename as output because the cron sciprt already
    # copied the files to the orig directory before calling this script
    my $filenameout = $ARGV[0];
    open(my $fhoutput, '>', $filenameout) or die "Could not open file '$filenameout' for output $!";

    for $l (0..$#lines) {
        $lines[$l] =~ s/\r|\n//g;
        my @segments = split("\\$segment_separator",$lines[$l]);
        for $i (0..$#segments) {
            my $regex_string = '^' . $segment_search_string . '\\' . $data_element_separator . '([^\\' . $data_element_separator  .']*)' . '\\' . $data_element_separator;
            if ($segments[$i] =~ qr/$regex_string/) {
                $code = $1;
                @pieces = split("\\$data_element_separator",$segments[$i]);
                for $j (0..$#pieces) {
                    if (($j < $#pieces) && ($j-1) % 3 == 0) {
                        $pieces[$j] = $code;
                    }
                }
                $segments[$i] = join($data_element_separator , @pieces);
            }
        }
        $lines[$l] = join($segment_separator, @segments) . $segment_separator;
    }
    foreach (@lines) {
        print $fhoutput "$_\n";
    }
    close ($fhoutput);
}
