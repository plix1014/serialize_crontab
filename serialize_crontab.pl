#!/usr/bin/perl
############################################################
#
# expands all cron entries and displays in sorted order
# 
# e.g.:
#   crontab -l | serialize_crontab.pl
#   crontab -l | serialize_crontab.pl -a
#   serialize_crontab.pl -a < /etc/crontab
#
# 2019-01-01: plix1014
# 
############################################################
#
use strict;
use warnings;

use Getopt::Std;

#-----------------------------------------------------------
# current crontab line.
my $line;
# split cronentry into its fields
my @cronline;
# store cronentry by hour token as key
my %crondata;
# expand hour field into numbers
my @hours;

# save commandline options
my %options=();
getopts("ash", \%options);

# format definitions
my ($f_str, $f_hh, $f_mi, $f_dd, $f_mm, $f_wd, $f_data);

format FORMAT_CRON_LINES =
@    @>:@<<<<  @<<<<<<<<  @<<<<<<<<  @<<<<<<<<  @*
$f_str, $f_hh, $f_mi, $f_dd, $f_mm,  $f_wd,     $f_data
.

#-----------------------------------------------------------
#
#
# --------- only for dev, not used for normal operation
# very verbose debug infos
use constant DEBUG => 0;
# some infos
use constant VERBOSE => 0;
# show input lines bevorhand
use constant SHOWINPUT => 0;

use Data::Dumper;
# --------- only for dev, not used for normal operation
#

# --------- set by commandline option: '-a'
#
# controls if all cron lines should be displayed
# or just the ones which would be run today
# could also be set on commandline by '-a' switch
#
# SHOW_ALL = 0 .... only print the lines which would run today
# SHOW_ALL = 1 .... show all lines
#
my $SHOW_ALL = 0;

# --------- set by commandline option: '-s'
#
# SHOW_SECTION = 0 .... only print the crontab lines
# SHOW_SECTION = 1 .... show also a section line for past and future events
#
my $SHOW_SECTION   = 0;
# help variables
my $PAST_SHOWED    = 1;
my $NOW_SHOWED     = 1;
my $FUTURE_SHOWED  = 1;



############################################################
#
# expand comma seperated items into list of numbers
#
# e.g.: 4,6,9,11
#
# Input:
#        $c_str - cron field item
#    
# Output:
#        @c_arr - numbers converted into list
#
############################################################
sub mk_range_from_comma {
    my $c_str   = shift;

    # split string
    my @c_arr = split(',',$c_str);

    return @c_arr;
}


############################################################
#
# expand a symbolic range into list of numbers
#
# e.g.: 8-17
#
# Input:
#        $c_str - cron field item
#    
# Output:
#        @c_arr - numbers converted into list
#
############################################################
sub mk_range_from_dash {
    my $c_str   = shift;

    # split string
    my @c_range = split('-',$c_str);

    if ($c_range[0] > $c_range[1]) {
       # need ascending order
       my $c_tmp = $c_range[0];
       $c_range[0] = $c_range[1];
       $c_range[1] = $c_tmp;
    }

    # sort array
    my @c_arr = map { 1 * $_ } $c_range[0] .. $c_range[1];

    return @c_arr;
}


############################################################
#
# expand symbolic star into list of numbers
#
# e.g.: *
#
# Input:
#        $c_str   - cron field item
#        $c_end_n - type of field (hh,mi,dd,mm,wd)
#    
# Output:
#        @c_arr - numbers converted into list
#
############################################################
sub mk_range_from_star {
    my ($c_str, $c_end_n) = @_;
    my $c_start;
    my $c_end;
    my @c_arr   = ();

    # set limits for minutes
    if ( $c_end_n eq 'mi' ) {
	$c_start = 0  unless defined($c_start);
	$c_end   = 59 unless defined($c_end);
    }
    # set limits for hours
    elsif ( $c_end_n eq 'hh' ) {
	$c_start = 0  unless defined($c_start);
	$c_end   = 23 unless defined($c_end);
    }
    # set limits for months
    elsif ( $c_end_n eq 'mm' ) {
	$c_start = 1 unless defined($c_start);
	$c_end   = 12 unless defined($c_end);
    }
    # set limits for days
    elsif ( $c_end_n eq 'dd' ) {
	# quick and dirty 
	$c_start = 1 unless defined($c_start);
	$c_end   = 30 unless defined($c_end);
    }
    # set limits for weekdays
    elsif ( $c_end_n eq 'wd' ) {
	# quick and dirty 
	$c_start = 0 unless defined($c_start);
	$c_end   = 6 unless defined($c_end);
    }
    else {
	$c_end = $c_end_n;
    }

    # build array items
    if ( $c_str =~ /\*/ ) {
	my $n = 0;
	for (my $i = $c_start; $i <= $c_end; $i++ ) {
		$c_arr[$n] = $i;
		$n++;
	    }
    } 

    return @c_arr;
}


############################################################
#
# expand symbolic slash syntax into list of numbers
#
# e.g.: */2, 8-16/4
#
# Input:
#        $c_str   - cron field item
#        $c_end_n - type of field (hh,mi,dd,mm,wd)
#        $c_start - range begin, if specified (optional)
#        $c_end   - range end, if specified (optional)
#    
# Output:
#        @c_arr - numbers converted into list
#
############################################################
sub mk_range_from_slash {
    my ($c_str, $c_end_n, $c_start, $c_end) = @_;

    my @c_arr   = ();


    # set limits for minutes
    if ( $c_end_n eq 'mi' ) {
	$c_start = 0  unless defined($c_start);
	$c_end   = 59 unless defined($c_end);
    }
    # set limits for hours
    elsif ( $c_end_n eq 'hh' ) {
	$c_start = 0  unless defined($c_start);
	$c_end   = 23 unless defined($c_end);
    }
    # set limits for hours
    elsif ( $c_end_n eq 'mm' ) {
	$c_start = 1 unless defined($c_start);
	$c_end   = 12 unless defined($c_end);
    }
    # set limits for hours
    elsif ( $c_end_n eq 'dd' ) {
	# quick and dirty 
	$c_start = 1 unless defined($c_start);
	$c_end   = 30 unless defined($c_end);
    }
    # set limits for hours
    elsif ( $c_end_n eq 'wd' ) {
	# quick and dirty 
	$c_start = 0 unless defined($c_start);
	$c_end   = 6 unless defined($c_end);
    }
    else {
	$c_end = $c_end_n;
    }

    # get range interval
    my @c_range = split('/',$c_str);

    # build array items
    if ( $c_range[0] =~ /\*/ ) {
	my $n = 0;
	for (my $i = $c_start; $i <= $c_end; $i += $c_range[1]) {
		$c_arr[$n] = $i;
		$n++;
	    }
    } 

    return @c_arr;
}

#------------------------------------------------------------------

############################################################
#
# expands a field element into corresponding numbers
#
# e.g.: 0-4,8-12,16-23/2
#
# Input:
#        $field_str  - cron field item
#        $field_type - type of field (hh,mi,dd,mm,wd)
#    
# Output:
#        @field - expanded numbers,ranges and intervals converted into list
#
############################################################
sub serialize_range {
    my $field_str  = shift;
    my $field_type = shift;
    my @field      = ();
    my @field2     = ();
    my @field3     = ();
    my @field_tmp  = ();

    print "#-------------------------------------------\n" if VERBOSE;
    print "# $field_type   : $field_str\n" if VERBOSE;

    # replace symbolic weekday names into numbers
    if ($field_type eq 'wd' ) {
	$field_str =~ s/Mon/01/;
	$field_str =~ s/Tue/02/;
	$field_str =~ s/Wed/03/;
	$field_str =~ s/Thu/04/;
	$field_str =~ s/Fri/05/;
	$field_str =~ s/Sat/06/;
	$field_str =~ s/Sun/07/;
    }

    # replace symbolic month names into numbers
    if ($field_type eq 'mm' ) {
	$field_str =~ s/Jan/01/;
	$field_str =~ s/Feb/02/;
	$field_str =~ s/Mar/03/;
	$field_str =~ s/Apr/04/;
	$field_str =~ s/May/05/;
	$field_str =~ s/Jun/06/;

	$field_str =~ s/Jul/07/;
	$field_str =~ s/Aug/08/;
	$field_str =~ s/Sep/09/;
	$field_str =~ s/Oct/10/;
	$field_str =~ s/Nov/11/;
	$field_str =~ s/Dec/12/;
    }


    # 1. level: 
    # split field at comma
    if ( $field_str =~ /,/ ) {
	@field_tmp = &mk_range_from_comma($field_str);
    } else {
	$field_tmp[0] = $field_str;
    } 


    # 2. level:
    # in case of multi elements, check for more ranges
    foreach my $field_str2 (@field_tmp) {

	# case 1: interval given
	# split into range of field
	if ( $field_str2 =~ /\// ) {
	    print "# found '/': $field_str2\n" if VERBOSE;
	    my @c_range = split('/',$field_str2);

	    # if we also have a range, extract start and end number
	    # e.g.: 0-23/2
	    if ( $c_range[0] =~ /-/ ) {
		print "# found '-': $field_str2\n" if VERBOSE;
		my @i_range = split('-',$c_range[0]);

	        my $field_str3 = "*/$c_range[1]";
		@field3 = (@field3,&mk_range_from_slash($field_str3,$field_type,$i_range[0],$i_range[1]));
	    } else {

		@field3 = (@field3,&mk_range_from_slash($field_str2,$field_type));
	    }

	} 
	# case 2: range given
	# split into range of field
	elsif ( $field_str2 =~ /-/ ) {
	    print "# found '-': $field_str2\n" if VERBOSE;
	    @field2 = (@field2,&mk_range_from_dash($field_str2));
	}
	# case 3: full range
	elsif ( $field_str2 =~ /\*/ ) {
	    print "# found '*': $field_str2\n" if VERBOSE;
	    @field2 = (@field2,&mk_range_from_star($field_str2,$field_type));

	# just a number
	} else {
	    print "# found 'n': $field_str2\n" if VERBOSE;
	    push(@field3,$field_str2);
	}
    }

    # normalize all numbers into two digits
    foreach my $item (@field2,@field3) {
	push(@field,sprintf("%02d", $item));
    }

    return @field;
}



############################################################
#
# prints a section line if needed
#
# Input:
#        $hh - hour of the cronjob
#        $mi - minute of the cronjob
#    
# Output:
#        -
#
############################################################
sub print_section {
    my $hh = shift;
    my $mi = shift;

    my $dashes = "----------------------------------------------------------------------------------";
    

    # get current time
    my $time = time();
    my ($t_ss, $t_mi, $t_hh) = (localtime($time))[0,1,2];

    my $t_now  = $t_hh * 60 + $t_mi;
    my $t_cron = $hh * 60 + $mi;

    if ($PAST_SHOWED == 0) {
	if ($t_cron < $t_now) {
	    print "#----------------- PAST -$dashes\n";
	    $PAST_SHOWED = 1;
	    return;
	}
    }

    if ($NOW_SHOWED == 0) {
	if ($t_cron == $t_now) {
	    print "#----------------  NOW  -$dashes\n";
	    printf("#                %02d:%02d:%02d\n",$t_hh,$t_mi,$t_ss);
	    print "#----------------  NOW  -$dashes\n";
	    $NOW_SHOWED = 1;
	    return;
	}
	elsif ($t_cron > $t_now) {
	    print "#----------------  NOW  -$dashes\n";
	    printf("#                %02d:%02d:%02d\n",$t_hh,$t_mi,$t_ss);
	    $NOW_SHOWED = 1;
	}
    }

    if ($FUTURE_SHOWED == 0) {
	if ($t_cron > $t_now) {
	    print "#---------------- FUTURE $dashes\n";
	    $FUTURE_SHOWED = 1;
	    return;
	}
    }


}

############################################################
#
# checks if a day, month or weekday matches todays date
#
# Input:
#        $token    - cron field item
#        $to_check - type of field (hh,mi,dd,mm,wd)
#    
# Output:
#        $ret      - flag if found or not found
#
############################################################
sub is_today {
    my $token = shift;
    my $to_check = shift;
    my $day_part;
    my $ret = 1;

    # get current date
    my $time = time();
    my ($t_mday, $t_mon, $t_year, $t_wd) = (localtime($time))[3,4,5,6];
	    

    # serialize field
    my @nlist = &serialize_range($token,$to_check);
    # convert into hash
    my %params = map { $_ => 1 } @nlist;


    # return 1 if current hour, minute, day, month or weekday found
    if ( $to_check eq 'mi' ) {
	return $ret;
    }
    elsif ( $to_check eq 'hh' ) {
	return $ret;
    }
    elsif ( $to_check eq 'mm' ) {
	$day_part = $t_mon + 1;
    }
    elsif ( $to_check eq 'dd' ) {
	$day_part = $t_mday;
    }
    elsif ( $to_check eq 'wd' ) {
	$day_part = $t_wd;
    }
    else {
	return $ret;
    }

    # nomalize to two digit number
    $day_part = sprintf("%02d", $day_part);

    # unset if not found
    if(exists($params{$day_part})) { 
	# ok, found
    } else {
	if ($t_wd == 0) {
	    for my $wd (sort keys %params) {
		if ($wd eq '00') {
		    $ret = 1;
		    last;
		} 
		elsif ($wd eq '07') {
		    $ret = 1;
		    last;
		} else {
		    $ret = 0;
		}
	    }

	} else {
	    $ret = 0;
	}
    }

    return $ret;
}


############################################################
#
# set/unset flag, if field matches today
#
# Input:
#        $token    - cron field item
#        	     reference to variable
#        $to_check - type of field (hh,mi,dd,mm,wd)
#    
# Output:
#        $show     - flag if found or not found
#
############################################################
sub set_view_crit {
    my $token = shift;
    my $typ   = shift;
    my $show  = 1;
     
    # no need to check tokens if we want to print all lines
    if ($SHOW_ALL == 1) {
	return $show;
    }

    # if '*' matches every day,month, hour, minute
    if ( $$token =~ /\*/ ) {
	return $show;
    }

    # set flag
    $show = &is_today($$token, $typ);

    return $show;
}


############################################################
#
# print symbolic field as serialized range of number
#
# Input:
#        $fields - list of numbers, could by any field type
#                  reference to an array
#    
# Output:
#       STDOUT symbolic item expanded into numbers
#
############################################################
sub print_range {
    my $fields = shift;

    print "# h-range: ";
    # loop through dereferenced array
    foreach my $field (sort { $a <=> $b } @$fields) {
	print sprintf("%02d ", $field);
    }
    print "\n";
}


############################################################
#
# output sorted cron lines
#
# Input:
#        global %crondata hash
#    
# Output:
#        STDOUT show sorted cron lines based on criteria
#
############################################################
sub print_cron {
    my $is_day_today   = 1;
    my $is_month_today = 1;
    my $is_wd_today    = 1;


    if (DEBUG) {
	print "#===== full crondata ==============================\n";
	print Dumper(\%crondata) . "\n";
	print "#===== full crondata ==============================\n";
    }

    if ($SHOW_ALL == 1) {
	print "\n# all cronjobs: \n";
    } else {
	print "\n# todays cronjobs: \n";
    }

    #   
    $f_str  = '#';
    $f_hh   = 'HH';
    $f_mi   = 'MI';
    $f_dd   = 'Day';
    $f_mm   = 'Month';
    $f_wd   = 'Weekday';
    $f_data = 'Command';
    $~      = 'FORMAT_CRON_LINES';
    write;

   # loop through all hours
   foreach my $key ( sort keys %crondata ) {

       # loop through list of array of arrays
       foreach my $field (sort { $a <=> $b } $crondata{$key}) {

	   # dereferencing array of arrays and sorting by hour and minute
	   my @a_tmp = sort { ($a->[0] <=> $b->[0]) or 
			      ($a->[1] <=> $b->[1]) 
                            } @$field;

	   for (my $x = 0; $x < @a_tmp; $x++) {
		   
	       # check, if cron entry would be activated today
	       # commandline option '-a'
	       $is_day_today   = &set_view_crit(\${a_tmp[$x][2]},'dd');
	       $is_month_today = &set_view_crit(\${a_tmp[$x][3]},'mm');
	       $is_wd_today    = &set_view_crit(\${a_tmp[$x][4]},'wd');

	       # show section line
	       # commandline option '-s'
               if ($SHOW_SECTION == 1) {
		   print_section(${a_tmp[$x][0]},${a_tmp[$x][1]});
	       }

	       # print line if criterias fit
	       if (($is_day_today == 1) and ($is_month_today == 1) and ($is_wd_today == 1)) {
		   printf("#    %02d:%02d  %4s  %9s  %11s\t%s\n",${a_tmp[$x][0]}, ${a_tmp[$x][1]}, ${a_tmp[$x][2]}, ${a_tmp[$x][3]}, ${a_tmp[$x][4]}, ${a_tmp[$x][5]});

		   #$f_hh   = ${a_tmp[$x][0]};
		   #$f_mi   = ${a_tmp[$x][1]};
		   #$f_dd   = ${a_tmp[$x][2]};
		   #$f_mm   = ${a_tmp[$x][3]};
		   #$f_wd   = ${a_tmp[$x][4]};
		   #$f_data = ${a_tmp[$x][5]};
		   #$~      = 'FORMAT_CRON_LINES';
		   #write;
	       }

	   }

       }
   }
}


############################################################
#
# build hash based on hour element
#
# Input:
#        $href - reference to hash crondata
#        $key  - hour is our hash key
#        $cref - reference to splitted cronline
#    
# Output:
#        
#
############################################################
sub add2hour {
    my $href = shift;
    my $key  = shift;
    my $cref = shift;
    my @minutes;

    # split minutes
    @minutes = &serialize_range($$cref[0],'mi');

    foreach my $minute (@minutes) {
	# build new anon array
	my $ref_line = [ $key, $minute, $$cref[2], $$cref[3], $$cref[4], $$cref[5] ];

	print(" working  HH: $key => MM: $minute\n") if DEBUG;

	# if hour already exist, add reference to array of arrays
	if ( defined($$href{$key}) ) {
	    print("   add    $key => $minute\n") if DEBUG;

	    # get current array
	    my $aref = $$href{$key};

	    # add cronline to anon array
	    push(@$aref, $ref_line);


	    # update key value
	    $$href{$key} = $aref;


	# if hour does not exist, add to hash and add reference to array of arrays
	} else {
	    print("   creat  $key => $minute\n") if DEBUG;

	    my $aref;
	    # create anon array
	    push(@$aref, $ref_line);

	    # set key value
	    $$href{$key}= $aref;

	}
    }

    if (DEBUG) {
	print "#---- add hour $key ----------------------\n";
	print "-4a-" . Dumper($href) . "\n";
	print "#---- add hour $key ----------------------\n";
    }
}

############################################################
#
# print program usage
#
# Input:
#        $c_str - cron field item
#    
# Output:
#        @c_arr - numbers converted into list
#
############################################################
sub show_help {
    print "usage: $0 <-a|-s|-h>\n";
    print "\t program uses <STDIN> to process cron infos\n";
    print "\t if no option is specified, only the lines relevant\n";
    print "\t for today are printed\n";

    print "\t -a ... print all cron lines\n";
    print "\t -s ... section lines for past and future jobs\n";
    print "\t -h ... print this usage info\n";
    print "e.g.:\n";
    print "\t crontab -l | $0\n";
    print "\t crontab -l | $0 -a\n";
    print "\t crontab -l | $0 -s\n";
    print "\n";
}



#-----------------------------------------------------------------------------
my $i = 1;

if ($options{h}) {
    show_help();
    exit;
}

if ($options{a}) {
    $SHOW_ALL = 1;
}

if ($options{s}) {
    $SHOW_SECTION  = 1;
    $PAST_SHOWED   = 0;
    $NOW_SHOWED    = 0;
    $FUTURE_SHOWED = 0;
}

foreach $line (<STDIN>) {
    chomp ($line);

    if (( $line !~ m/^#/m ) and ( $line !~ m/^[A-Z|]|^$/m )) {

	my $num = sprintf("%02d", $i);
	print "line $num: $line\n" if SHOWINPUT;

	@cronline = split(' ',$line,6);

	# serialize hours
	@hours = &serialize_range($cronline[1],'hh');
	print_range(\@hours) if SHOWINPUT;

	foreach my $hour (@hours) {
	    $hour = sprintf("%02d ", $hour);
	    &add2hour(\%crondata,$hour,\@cronline);
	}

    }
    $i++;


}

&print_cron();

#-----------------------------------------------------------------------------

=head1 NAME

serialize_crontab.pl

=head1 SYNOPSIS

   crontab -l | serialize_crontab.pl
   crontab -l | serialize_crontab.pl -a
   crontab -l | serialize_crontab.pl -s
   serialize_crontab.pl -a < /etc/crontab

=head1 DESCRIPTION

expands all cron entries and displays in sorted order.

Serialisation could lead to a long list of cronjobs.
To reduce the output you can pipe it to a grep call.

crontab -l | serialize_crontab.pl -a -s | egrep -v "icinga|barfoo"


=head2 B<Input>

=begin text

    22 17 * * 1-5 csh -c '~/scripts/barfoo/barfoo.sh'
    30 11,13 * * 1-5 ksh -c '~/scripts/foofoo/foofoo.sh'
    55 05 * Nov 2-6 csh -c '~/scripts/barbar/barbar.sh'
    15 17 * * Mon-Thu csh -c '~/scripts/foobar/foobar.sh'
    15 17 1 6,12 * csh -c '~/scripts/barfoobar/barfoobar.sh'

=end text

.

=head2 B<Output : today>

=begin text

    $
    $ serialize_crontab.pl < foobar.cron
    # todays cronjobs:
    #    HH:MI     Day        Month      Weekday    Command
    #    11:30     *          *          1-5        ksh -c '~/scripts/foofoo/foofoo.sh'
    #    13:30     *          *          1-5        ksh -c '~/scripts/foofoo/foofoo.sh'
    #    17:15     *          *      Mon-Thu        csh -c '~/scripts/foobar/foobar.sh'
    #    17:22     *          *          1-5        csh -c '~/scripts/barfoo/barfoo.sh'

=end text

.

=head2 B<Output : all>

=begin text

    $
    $ serialize_crontab.pl -a < foobar.cron
    # all cronjobs:
    #    HH:MI     Day        Month      Weekday    Command
    #    05:55     *        Nov          2-6        csh -c '~/scripts/barbar/barbar.sh'
    #    11:30     *          *          1-5        ksh -c '~/scripts/foofoo/foofoo.sh'
    #    13:30     *          *          1-5        ksh -c '~/scripts/foofoo/foofoo.sh'
    #    17:15     1       6,12            *        csh -c '~/scripts/barfoobar/barfoobar.sh'
    #    17:16     *          *      Mon-Thu        csh -c '~/scripts/foobar/foobar.sh'
    #    17:22     *          *          1-5        csh -c '~/scripts/barfoo/barfoo.sh'

=end text

.

=head2 Methods

=over 25

=item C<mk_range_from_comma>

expand comma seperated items into list of numbers

=item C<mk_range_from_dash>

expand a symbolic range into list of numbers

=item C<mk_range_from_star>

expand symbolic star into list of numbers

=item C<mk_range_from_slash>

expand symbolic slash syntax into list of numbers

=item C<serialize_range>

expands a field element into corresponding numbers

=item C<print_section>

prints a section line if needed

=item C<is_today>

checks if a day, month or weekday matches todays date

=item C<print_range>

print symbolic field as serialized range of number

=item C<set_view_crit>

set/unset flag, if field matches today

=item C<print_cron>

output sorted cron lines

=item C<add2hour>

build hash based on hour element

=item C<show_help>

print program usage

=back

=head1 LICENSE

This is released under the CC BY-NC-SA
License. Creative Commons Attribution-NonComercial-ShareAlike
See L<http://creativecommons.org/licenses/by-nc-sa/4.0/>.

=head1 AUTHOR

plix1014

=head1 SEE ALSO

L<man 5 crontab>

=cut

