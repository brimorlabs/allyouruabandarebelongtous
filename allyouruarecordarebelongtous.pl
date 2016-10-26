#!c:\Perl\bin\perl.exe
# For Unix use /usr/local/bin/
# This will parse data from UA Record SQLite database(s)
# The colored output is available for ActiveState Perl on Windows systems. 

use if $^O eq "MSWin32", Win32::Console;
use strict;
use IO::All;
use Getopt::Long;
use POSIX;
use DateTime;
use DBI;
use CGI;

# use Data::Plist; #Might need this for UA Record data from iOS devices
# use Data::Plist::BinaryReader; #Might need this for UA Record data from iOS devices
# use Data::Plist::Foundation::NSArray; #Might need this for UA Record data from iOS devices



# EASY TO EDIT SCRIPT INFORMATION
	my $scriptname='allyouruarecordarebelongtous.pl';
	my $scriptversion= '1.0 (Build 20161026)';
	my $authorname='Brian Moran (@brianjmoran)';
	my $emailaddress='(brian@brimorlabs.com)';


#Declarations
my ($OUTFILE, $FILE, $database, $databasetype, $slashes, @contents, $uauserid, $uausername, %uauser_correlation, $usermistake);
my ($CONSOLE, $orgcolor, $red_error, $green_processing); #Declarations for color
my $uarecordhtmlpage= CGI->new;
my $ostype=$^O; #This is where the operating system is determined
if ($ostype eq "MSWin32")
{
	no strict;	
	$CONSOLE= Win32::Console->new(STD_OUTPUT_HANDLE) if $ostype eq "MSWin32";
	$orgcolor=$CONSOLE->Attr() if $ostype eq "MSWin32";
	$red_error="$FG_RED | $BG_BLACK";
	$green_processing="$FG_GREEN | $BG_BLACK";
	use strict;
}
my @options=(
	'directory=s'		=>	"will parse a directory",
	'file=s'		=>	"will parse a file",
	'outputdir=s'		=>	"directory where output is saved",
	'changes'		=>	"	shows script changes",
	'info'			=>	"	shows script information"
);
die &usage if (@ARGV == 0); #A nice die at usage


# Getopt::Long stuff happens here
my @getopt_opts;
for(my $i =0;$i<@options;$i+=2){
	push @getopt_opts,$options[$i];
}
%Getopt::Long::options = ();
$Getopt::Long::autoabbrev=1;
&Getopt::Long::GetOptions( \%Getopt::Long::options,@getopt_opts) or &usage;




my $filename=$Getopt::Long::options{file} if (defined $Getopt::Long::options{file}); #Looks to see if filename is defined
my $directorypath=$Getopt::Long::options{directory} if (defined $Getopt::Long::options{directory}); #Looks to see if folder is defined
my $output=$Getopt::Long::options{outputdir} if (defined $Getopt::Long::options{outputdir}); #Looks to see if output is defined
die &changes if (defined $Getopt::Long::options{changes}); #Dies at changes if changes is defined
die &info if (defined $Getopt::Long::options{info}); #Dies at info if info is defined
#Error dying, with color
if ((not defined $Getopt::Long::options{file}) && (not defined $Getopt::Long::options{directory}))
{
	$CONSOLE->Attr($red_error) if $ostype eq "MSWin32"; #Changing colors to red for errors
	print STDERR "\nERROR!! Please define either:\n\t- a file to parse with the -file flag, or\n\t- a directory to parse with the -directory flag.\n\n";
	$CONSOLE->Attr($orgcolor) if $ostype eq "MSWin32"; #Changing to original color of black and white
	die "\n";

}
#Error dying, with color
if (not defined $Getopt::Long::options{outputdir})
{;
	$CONSOLE->Attr($red_error) if $ostype eq "MSWin32"; #Changing colors to red for errors
	print STDERR "\nERROR!! Please define an output folder with the -outputdir flag.\n\n";
	$CONSOLE->Attr($orgcolor) if $ostype eq "MSWin32"; #Changing to original color of black and white
	die "\n";	
}
my $makedir=mkdir "$Getopt::Long::options{outputdir}" if (defined $Getopt::Long::options{outputdir});


if (defined $Getopt::Long::options{directory} && (-d $Getopt::Long::options{directory})) #Check directory flag & ensuring it is a directory
{
	my $io = io($directorypath);
	@contents= $io->all_files(0); #All the files in the directory
}
elsif (-f $Getopt::Long::options{directory}) #Taking into account you may accidentally label a file as a directory
{
	@contents = io($directorypath); #Fixing the possible user mistake, we only do this once though
	$usermistake="\n\nYou mistakenly labeled a file as a directory. Don't worry, we fixed the mistake!\n\n";
}
elsif (defined $Getopt::Long::options{file} && (-f $Getopt::Long::options{file})) #Check file flag & ensuring it is a file
{
	@contents = io($filename); #A single file
}
elsif (-d $Getopt::Long::options{file}) #Taking into account you may accidentally label a directory as a file
{
	my $io = io($filename);
	@contents= $io->all_files(0); #All the files in the directory
	$usermistake="\n\nYou mistakenly labeled a directory as a file. Don't worry, we fixed the mistake!\n\n";
}
else
{
	$CONSOLE->Attr($red_error) if $ostype eq "MSWin32"; #Changing colors to red for errors
	print "\n\nFatal script error. Something bad happened. Try turning it off and on again\n";
	$CONSOLE->Attr($orgcolor) if $ostype eq "MSWin32"; #Changing to original color of black and white
	die "\n";
}


foreach my $content(@contents) #Enter the file processing loop here
{
	my $filename = $content->filename; #IO All-filename
	my $abspathname=io($content)->absolute->pathname; #IO All Pathname
	print STDERR "\nProcessing $abspathname\n"; #Processing this
	#Reading the entire file into a single variable
	open($FILE, "$abspathname") || die "Cannot open $content $!\n";
	my $data = do {local $/; binmode $FILE; <$FILE>};
	my $sqlitedb = $data;
	close($FILE);

	my $outputcontent=io($output);
	my $outputabspathname=io($outputcontent)->absolute->pathname;

	#Small check for slash direction to handle multiple operating systems
	if ($outputabspathname =~ /\\/)
	{
		$slashes='\\';
	} 
	else
	{
		$slashes='/';
	}


	#A small test to ensure it is a sqlite database
	my $uarecordheader=substr($data,0,15); #Grabbing the first 15 bytes of data. Rather than use magic or something, gonna do this ourselves

	if ($uarecordheader =~ /SQLite format 3/)
	{
		#Defined values
		my ($manifesturl);
		open($OUTFILE, ">tempsqlfile");
		binmode $OUTFILE;
		print $OUTFILE $sqlitedb;
		close($OUTFILE);
		
		#Connecting to the SQLite database
		$database=DBI->connect('dbi:SQLite:tempsqlfile');

		#Now we are going to go through subroutines for each SQLite query

		#The best way to do this is through various subroutines. That way the code is easier to follow if you want to add something new
		#Android specific queries
		my $commonCache=&commonCache; #Running commonCache subroutine
		my $uasdk_workout=&uasdk_workout; #Running uasdk_workout subroutine
		my $mmdk_user=&mmdk_user; #Running mmdk_user subroutine
		
		#iOS specific queries
		# Database parsing TBD
		$database->disconnect or warn "Database disconnect error!\n";
		my $tmpsqlfile = io("tempsqlfile"); # Using IO:All against tmpsqlfile
		my $tmpabspathname=io($tmpsqlfile)->absolute->pathname; #Getting full path to temp file for clean deletion purposes
		unlink "$tmpabspathname" or warn "Cound not unlink $tmpabspathname" if (-e $tmpabspathname); #Deleting the tempsqlfile
		}
		else
		{
			print STDERR "\nMoving on to next UA Record database.\n";
		}
}

#This is where we clean up the HTML & combine UA Record User IDs in the Workout Entity html file and MMDK User file
if (-e "$output$slashes"."uasdk_workout-Workout_Entity.html")
{
	my ($CORRELATEDFILE, $correlatedfilestring);
	open my $WEHTML, "$output$slashes"."uasdk_workout-Workout_Entity.html" || die "Cannot open file $!";
	my $correlatedfilestring = do {local $/; binmode $WEHTML; <$WEHTML>};
	close($WEHTML);
	my @uakeys=keys %uauser_correlation;
	foreach my $key (@uakeys)
	{
		if ($correlatedfilestring =~ /$key/)
		{
			$correlatedfilestring=~s/$key/$uauser_correlation{$key}/g;
		}
	}
	open($CORRELATEDFILE, ">$output$slashes"."uasdk_workout-Workout_Entity.html"); #Opening our output file
	binmode $CORRELATEDFILE; #I am all about that binmode
	print $CORRELATEDFILE $correlatedfilestring;
	close ($CORRELATEDFILE);	
}

my $end = time(); #When the script ended
my $runtime = ($end - $^T); #$^T is when the script started. Who knew?




printf STDERR ("\nThe script took %02d:%02d:%02d to complete\n$usermistake", int ($runtime/3600), int ( ($runtime % 3600) / 60), int ($runtime % 60) ); #Mathiness to compute total run time
exit (-1); #A nice clean exit


#commonCache subroutine
sub commonCache ()
{
	my $mfp_in_commonCache=&mfp_in_commonCache;
	my $datapoint_in_commonCache=&datapoint_in_commonCache;
}

#mmdk_workout subroutine
sub mmdk_user ()
{
	my $users_in_mmdk_user=&users_in_mmdk_user;
}

#uasdk_workout subroutine
sub uasdk_workout ()
{
	my $we_in_uasdk_workout=&we_in_uasdk_workout;
}

#MFP in commonCache subroutine	
sub mfp_in_commonCache ()
{
	#Defined values go here
	my ($commonCachemfptableresults, $COMMONCACHEMFPDEHTML);
	#SQLite query to check if the table name exists
	my $commonCachemfptablecheck=$database->prepare( "SELECT name FROM sqlite_master WHERE type='table' AND name='MfpDailyEnergy'");
	$commonCachemfptablecheck->execute();
	while (my @commonCachemfptablequery=$commonCachemfptablecheck->fetchrow_array())
	{
		$commonCachemfptableresults=$commonCachemfptablequery[0];
	}

	if ($commonCachemfptableresults =~ /MfpDailyEnergy/) #The SQLite query above should return this value. If not, we exit nicely and move along
	{
		my @commonCachemfpfields=('Date', 'Calories Consumed', 'Calories Burned From Exercise', 'Goal', 'Remaining'); #This is the name of the fields we will be parsing
		my $commonCachemfpfilecreation="$output$slashes". "commonCache-MyFitnessPal-Tracker.html"; #Building the name of the output file
		open($COMMONCACHEMFPDEHTML, ">$commonCachemfpfilecreation"); #Opening our output file
		binmode $COMMONCACHEMFPDEHTML; #I am all about that binmode
		print $COMMONCACHEMFPDEHTML $uarecordhtmlpage->start_html(-title => 'UA Record/My Fitness Pal Tracker', -encoding=>"utf-8"); #Formatting
		print $COMMONCACHEMFPDEHTML $uarecordhtmlpage->p({-align=>'center',-valign=>'middle',style=>'font-size: x-large; font-weight: bold; text-decoration: underline'}, "UA Record/My Fitness Pal Tracker from database file \"commonCache.db\""); #Formatting
		print $COMMONCACHEMFPDEHTML $uarecordhtmlpage->start_table({-border=>2, -cellspacing=>3, -cellpadding=>3}); #Formatting
		print $COMMONCACHEMFPDEHTML $uarecordhtmlpage->Tr({-align=>'center',-valign=>'middle',style=>'font-size: x-large; font-weight: bold; text-decoration: underline'},[$uarecordhtmlpage->th(\@commonCachemfpfields)]); #Formatting
		$CONSOLE->Attr($green_processing) if $ostype eq "MSWin32"; #Changing colors to green for processing
		print STDERR "\nGood news everyone!!\nThe table \"MfpDailyEnergy\" exists in this database.\nBeginning to parse data now.\n";
		my $commoncache_mfp_parsing=$database->prepare( "SELECT date, consumed, burnedFromExercise, goal, remaining FROM MfpDailyEnergy ORDER BY date ASC"); #Our SQLite query
		$commoncache_mfp_parsing->execute(); #Run query run!
		while (my @commonCachesactivityquery=$commoncache_mfp_parsing->fetchrow_array())
		{
			print $COMMONCACHEMFPDEHTML $uarecordhtmlpage->Tr({-align=>'left',-valign=>'middle',style=>'font-size: medium; font-weight: ligther'},[$uarecordhtmlpage->th(\@commonCachesactivityquery)]); #This looks complex, but this is actually taking our output and printing it right to html
			
		}
		$commoncache_mfp_parsing->finish(); #Whew, I am tired
		print $COMMONCACHEMFPDEHTML $uarecordhtmlpage->end_table; #The end of the table
		print $COMMONCACHEMFPDEHTML $uarecordhtmlpage->end_html; #The end of the html
		close($COMMONCACHEMFPDEHTML); #Closing time
		print STDERR "The parsing of the table \"MfpDailyEnergy\" has completed.\nMoving on to next table now.\n";
		$CONSOLE->Attr($orgcolor) if $ostype eq "MSWin32"; #Changing to original color of black and white

	}
	else
	{
		print "Moving on to next database now.\nExiting \"mfp_in_commonCache\" subroutine.\n\n";
	}
}

#Datapoint in commonCache subroutine
sub datapoint_in_commonCache ()
{
	#Defined values go here
	my ($commonCachedptableresults, $COMMONCACHEDPHTML);
	#SQLite query to check if the table name exists
	my $commonCachedptablecheck=$database->prepare( "SELECT name FROM sqlite_master WHERE type='table' AND name='DataPoint'");
	$commonCachedptablecheck->execute();
	while (my @commonCachedptablequery=$commonCachedptablecheck->fetchrow_array())
	{
		$commonCachedptableresults=$commonCachedptablequery[0];
	}

	if ($commonCachedptableresults =~ /DataPoint/) #The SQLite query above should return this value. If not, we exit nicely and move along
	{
		my @commonCachemfpfields=('Date/Time', 'Nutriton Rating', 'Nutrition Rating Notes', 'Self Assessment Rating', 'Self Assessment Rating Notes', 'Start Date/Time'); #This is the name of the fields we will be parsing
		my $commonCachedpfilecreation="$output$slashes". "commonCache-DataPoints.html"; #Building the name of the output file
		open($COMMONCACHEDPHTML, ">$commonCachedpfilecreation"); #Opening our output file
		binmode $COMMONCACHEDPHTML; #I am all about that binmode
		print $COMMONCACHEDPHTML $uarecordhtmlpage->start_html(-title => 'UA Record/Data Point Tracker', -encoding=>"utf-8"); #Formatting
		print $COMMONCACHEDPHTML $uarecordhtmlpage->p({-align=>'center',-valign=>'middle',style=>'font-size: x-large; font-weight: bold; text-decoration: underline'}, "UA Record/Data Point Tracker from database file \"commonCache.db\""); #Formatting
		print $COMMONCACHEDPHTML $uarecordhtmlpage->start_table({-border=>2, -cellspacing=>3, -cellpadding=>3}); #Formatting
		print $COMMONCACHEDPHTML $uarecordhtmlpage->Tr({-align=>'center',-valign=>'middle',style=>'font-size: x-large; font-weight: bold; text-decoration: underline'},[$uarecordhtmlpage->th(\@commonCachemfpfields)]); #Formatting
		$CONSOLE->Attr($green_processing) if $ostype eq "MSWin32"; #Changing colors to green for processing
		print STDERR "\nGood news everyone!!\nThe table \"DataPoint\" exists in this database.\nBeginning to parse data now.\n";
		my $commoncache_dp_parsing=$database->prepare( "SELECT datetime((dateTime/1000), 'unixepoch'), nutritionRating, nutritionRatingNotes, selfAssessmentRating, selfAssessmentRatingNotes, datetime((startDatetime/1000), 'unixepoch') FROM DataPoint ORDER BY dateTime ASC"); #Our SQLite query
		$commoncache_dp_parsing->execute(); #Run query run!
		while (my @commonCachesactivityquery=$commoncache_dp_parsing->fetchrow_array())
		{
			#Small bit of cleanup for line breaks
			if ($commonCachesactivityquery[2] =~ /\x0A/)
			{
				$commonCachesactivityquery[2]=~s/\x0A/<br>/g;
			}
			if ($commonCachesactivityquery[4] =~ /\x0A/)
			{
				$commonCachesactivityquery[4]=~s/\x0A/<br>/g;
			}
			print $COMMONCACHEDPHTML $uarecordhtmlpage->Tr({-display=>'block',-align=>'left',-valign=>'middle',style=>'font-size: medium; font-weight: ligther'},[$uarecordhtmlpage->th(\@commonCachesactivityquery)]); #This looks complex, but this is actually taking our output and printing it right to html
			
		}
		$commoncache_dp_parsing->finish(); #Whew, I am tired
		print $COMMONCACHEDPHTML $uarecordhtmlpage->end_table; #The end of the table
		print $COMMONCACHEDPHTML $uarecordhtmlpage->end_html; #The end of the html
		close($COMMONCACHEDPHTML); #Closing time
		print STDERR "The parsing of the table \"DataPoint\" has completed.\nMoving on to next table now.\n\n";
		$CONSOLE->Attr($orgcolor) if $ostype eq "MSWin32"; #Changing to original color of black and white
	}
	else
	{
		print "Moving on to next database now.\nExiting \"commonCaches\" subroutine.\n";
	}
}

#usdk workout subroutine
sub we_in_uasdk_workout ()
{
	#Defined values go here
	my ($usadk_workout_wetableresults, $UASDK_WORKOUT_ME_HTML);
	#SQLite query to check if the table name exists
	my $usadk_workout_wetablecheck=$database->prepare( "SELECT name FROM sqlite_master WHERE type='table' AND name='workout_entity'");
	$usadk_workout_wetablecheck->execute();
	while (my @usadk_workout_wetablequery=$usadk_workout_wetablecheck->fetchrow_array())
	{
		$usadk_workout_wetableresults=$usadk_workout_wetablequery[0];
	}

	if ($usadk_workout_wetableresults =~ /workout_entity/) #The SQLite query above should return this value. If not, we exit nicely and move along
	{
		my @usadk_workout_wefields=('UA Record User ID (Display Name)', 'Name', 'Date/Time Workout Started (UTC)', 'Workout Account Timezone', 'Date/Time Workout Created (UTC)', 'Date/Time Workout Last Updated (UTC)', 'Source', 'Notes', 'Total Distance in Miles (Rounded)', 'Calories', 'Active Time', 'Total Workout Time', 'Total Steps', 'Average Speed (Miles per Hour)',  'Facebook', 'Twitter'); #This is the name of the fields we will be parsing
		#SQLite table notes: timestamps/1000, distance_total is in meters, metabolic_energy_total is in Joules, speed is meters per second
		
		my $usadk_workout_wefilecreation="$output$slashes". "uasdk_workout-Workout_Entity.html"; #Building the name of the output file
		open($UASDK_WORKOUT_ME_HTML, ">$usadk_workout_wefilecreation"); #Opening our output file
		binmode $UASDK_WORKOUT_ME_HTML; #I am all about that binmode
		print $UASDK_WORKOUT_ME_HTML $uarecordhtmlpage->start_html(-title => 'UA Record/Workout Entity', -encoding=>"utf-8"); #Formatting
		print $UASDK_WORKOUT_ME_HTML $uarecordhtmlpage->p({-align=>'center',-valign=>'middle',style=>'font-size: x-large; font-weight: bold; text-decoration: underline'}, "UA Record/Workout Entity data from database file \"uasdk_workout.db\""); #Formatting
		print $UASDK_WORKOUT_ME_HTML $uarecordhtmlpage->start_table({-border=>2, -cellspacing=>3, -cellpadding=>3}); #Formatting
		print $UASDK_WORKOUT_ME_HTML $uarecordhtmlpage->Tr({-align=>'center',-valign=>'middle',style=>'font-size: x-large; font-weight: bold; text-decoration: underline'},[$uarecordhtmlpage->th(\@usadk_workout_wefields)]); #Formatting
		$CONSOLE->Attr($green_processing) if $ostype eq "MSWin32"; #Changing colors to green for processing
		print STDERR "\nGood news everyone!!\nThe table \"workout_entity\" exists in this database.\nBeginning to parse data now.\n";
		my $uasdk_workout_we_parsing=$database->prepare( "SELECT workout_links.link_id, name, datetime((start_datetime/1000), 'unixepoch'), start_locale_timezone, datetime((created_datetime/1000), 'unixepoch'), datetime((updated_datetime/1000), 'unixepoch'), source, cast(notes as text), ROUND((distance_total * 0.00062137),2), metabolic_energy_total / 4184, time(active_time_total, 'unixepoch'), time(elapsed_time_total, 'unixepoch'), steps_total, ROUND((speed_avg * 2.236936),1), facebook, twitter FROM workout_links, workout_entity WHERE workout_links.entity_id=workout_entity._id and workout_links.link_key LIKE 'user' ORDER BY workout_entity._id ASC"); #Our SQLite query
		$uasdk_workout_we_parsing->execute(); #Run query run!
		while (my @uasdk_workoutsactivityquery=$uasdk_workout_we_parsing->fetchrow_array())
		{
			#Small bit of cleanup for line breaks
			if ($uasdk_workoutsactivityquery[7] =~ /\x0A/)
			{
				$uasdk_workoutsactivityquery[7]=~s/\x0A/<br>/g;
			}
			print $UASDK_WORKOUT_ME_HTML $uarecordhtmlpage->Tr({-display=>'block',-align=>'left',-valign=>'middle',style=>'font-size: medium; font-weight: ligther'},[$uarecordhtmlpage->th(\@uasdk_workoutsactivityquery)]); #This looks complex, but this is actually taking our output and printing it right to html			
		}
		$uasdk_workout_we_parsing->finish(); #Whew, I am tired
		print $UASDK_WORKOUT_ME_HTML $uarecordhtmlpage->end_table; #The end of the table
		print $UASDK_WORKOUT_ME_HTML $uarecordhtmlpage->end_html; #The end of the html
		close($UASDK_WORKOUT_ME_HTML); #Closing time
		print STDERR "The parsing of the table \"workout_entity\" has completed.\nMoving on to next table now.\n\n";
		$CONSOLE->Attr($orgcolor) if $ostype eq "MSWin32"; #Changing to original color of black and white
	}
	else
	{
		print "Moving on to next database now.\nExiting \"we_in_uasdk_workout\" subroutine.\n";
	}
}

#mmdk user subroutine
sub users_in_mmdk_user ()
{
	#Defined values go here
	my ($mmdk_usertableresults, $MMDK_USERS_HTML);
	#SQLite query to check if the table name exists
	my $mmdk_usertablecheck=$database->prepare( "SELECT name FROM sqlite_master WHERE type='table' AND name='user_entity'");
	$mmdk_usertablecheck->execute();
	while (my @mmdk_usertablequery=$mmdk_usertablecheck->fetchrow_array())
	{
		$mmdk_usertableresults=$mmdk_usertablequery[0];
	}

	if ($mmdk_usertableresults =~ /user_entity/) #The SQLite query above should return this value. If not, we exit nicely and move along
	{
		my @mmdk_userfields=('UA Record User ID', 'UA Record UserName', 'Email Address', 'First Name', 'Last Name', 'Display Name', 'Introduction', 'Hobbies', 'Goals', 'Profile Statement', 'Birthday', 'Gender', 'Height (Inches)',  'Weight (lbs)', 'User Time Zone', 'Date Joined UA Record', 'Last Login UA Record', 'Address', 'City', 'Region', 'County', 'Profile Image URL'); #This is the name of the fields we will be parsing
		#SQLite table notes: timestamps/1000, height is in meters
		
		my $mmdk_userfilecreation="$output$slashes". "mmdk_user-User-Information.html"; #Building the name of the output file
		open($MMDK_USERS_HTML, ">$mmdk_userfilecreation"); #Opening our output file
		binmode $MMDK_USERS_HTML; #I am all about that binmode
		print $MMDK_USERS_HTML $uarecordhtmlpage->start_html(-title => 'UA Record/User Information', -encoding=>"utf-8"); #Formatting
		print $MMDK_USERS_HTML $uarecordhtmlpage->p({-align=>'center',-valign=>'middle',style=>'font-size: x-large; font-weight: bold; text-decoration: underline'}, "UA Record/User Information data from database file \"mmdk_user.db\""); #Formatting
		print $MMDK_USERS_HTML $uarecordhtmlpage->start_table({-border=>2, -cellspacing=>3, -cellpadding=>3}); #Formatting
		print $MMDK_USERS_HTML $uarecordhtmlpage->Tr({-align=>'center',-valign=>'middle',style=>'font-size: x-large; font-weight: bold; text-decoration: underline'},[$uarecordhtmlpage->th(\@mmdk_userfields)]); #Formatting
		$CONSOLE->Attr($green_processing) if $ostype eq "MSWin32"; #Changing colors to green for processing
		print STDERR "\nGood news everyone!!\nThe table \"user_entity\" exists in this database.\nBeginning to parse data now.\n";
		my $mmdk_user_parsing=$database->prepare( "SELECT id, username, email, first_name, last_name, display_name, introduction, hobbies, goal_statement, profile_statement, birthdate, gender, ROUND(height * 39.370) as height, ROUND((weight * 2.20462),1), timezone, date_joined, last_login, location_address, location_locality, location_region, location_country, profile_image_large FROM user_entity "); #Our SQLite query
		#ROUND(height * 39.370)
		$mmdk_user_parsing->execute(); #Run query run!
		while (my @uasdk_workoutsactivityquery=$mmdk_user_parsing->fetchrow_array())
		{
			#Small bit of cleanup for line breaks
			if ($uasdk_workoutsactivityquery[7] =~ /\x0A/)
			{
				$uasdk_workoutsactivityquery[7]=~s/\x0A/<br>/g;
			}
			$uauser_correlation{$uasdk_workoutsactivityquery[0]} = "$uasdk_workoutsactivityquery[0]"."<br>($uasdk_workoutsactivityquery[5])"; #This is User ID and Display Name
			#$uauser_correlation{$uasdk_workoutsactivityquery[0]} = $uasdk_workoutsactivityquery[1]; #This is just username
			print $MMDK_USERS_HTML $uarecordhtmlpage->Tr({-display=>'block',-align=>'left',-valign=>'middle',style=>'font-size: medium; font-weight: ligther'},[$uarecordhtmlpage->th(\@uasdk_workoutsactivityquery)]); #This looks complex, but this is actually taking our output and printing it right to html
			
		}
		$mmdk_user_parsing->finish(); #Whew, I am tired
		print $MMDK_USERS_HTML $uarecordhtmlpage->end_table; #The end of the table
		print $MMDK_USERS_HTML $uarecordhtmlpage->end_html; #The end of the html
		close($MMDK_USERS_HTML); #Closing time
		print STDERR "The parsing of the table \"mmdk_user\" has completed.\nMoving on to next table now.\n\n";
		$CONSOLE->Attr($orgcolor) if $ostype eq "MSWin32"; #Changing to original color of black and white
	}
	else
	{
		print "Moving on to next database now.\nExiting \"mmdk_user\" subroutine.\n";
	}
}

sub usage() #This is where the usage statement goes. Hooray usage!
{
	my %defs=(
		s => "string",
	);
	print "\n";
	print "This script parses data from the database(s) associated with a\nUnder Armour Band fitness tracker.\n\n";
	print "As of October 26, 2016, only Android databases are supported.\n";
	print "\nUsage example:\n\n";
	print "allyouruarecordarebelongtous.pl -file \"commonCache\.db\" -outputdir \"ParsedData\"\n";
	print "                                   <OR>\n";
	print "allyouruarecordarebelongtous.pl -directory \"UA-Record\" -outputdir \"ParsedData\"\n\n";	
	print "\nOptions\n";
	for(my $c=0;$c<@options;$c+=2){
		my $arg="";
		my $exp=$options[$c+1];
		if($options[$c]=~s/([=:])([siof])$//){
			$arg="<".$defs{$2}.">" if $1 eq "=";
			$arg="[".$defs{$2}."]" if $1 eq ":";
			}
		$arg="(flag)" unless $arg;
		printf "	-%-15s $arg",$options[$c];
		print "\t",$exp if defined $exp;
		print "\n";
		}
		print "\n";
		exit (-1);
}

sub changes ()
{
	print "\n\n";
	printf "%-15s==========CHANGES/REVISIONS==========\n";
	printf "%-17sVersion $scriptversion\n";
	printf "%-17sScript creation and subsequent revisions\n";
	printf "%-17sTested & written for Perl 5.22\n";
	print &info;
}
	



sub info ()
{
	print "\n\n";
	printf "%-15s==========SCRIPT INFORMATION==========\n";
	printf "%-17sScript Information: $scriptname\n";
	printf "%-17sVersion: $scriptversion\n";
	printf "%-17sAuthor: $authorname\n";
	printf "%-17sEmail: $emailaddress\n";
	printf "\n----------------- END OF LINE -----------------\n\n";
	exit (-1);
}
