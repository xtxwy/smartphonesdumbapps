#!/opt/local/bin/perl

# (C) Copyright 2010 Denim Group, Ltd.

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2, or (at your option)
# any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301, USA.

# Please email questions/comments/patches to dan _at_ denimgroup.com


use Cwd;
use Cwd 'abs_path';
use File::Basename;
use File::Path;
use File::Spec;
use XML::XPath;
use XML::XPath::XMLParser;

my $program_name = 'analyze_android';
my $platform_name ='Android';
my $version = '0.1';

my $target_app = $ARGV[0];

# Remove a trailing '/' character if it exists
# This often happens when looking as XYZ.app/ applications when tab-completion
# is used to find the application to assess.

if($target_app =~ m/\/$/) {
    chop($target_app);
}

my $full_path = abs_path($0);
my $exe_path = dirname($full_path);
print "Executable base is $exe_path\n";

require "$exe_path/common.pl";

if($target_app eq "") {
    print "usage $0 <apk_file>\n";
    exit(1);
}

print "$program_name for $platform_name v$version\n";
print "Brought to you by Denim Group http://www.denimgroup.com/\n";

print "APK to unpack is: $target_app\n";
my $output_dir = make_output_directory($target_app);
print "Output directory will be $output_dir\n";

if(-d $output_dir)
{
    print "Output directory $output_dir exists. Deleting to create new output.\n";
    my $delete_old_output_cmd = "rm -fr $output_dir";
    run_command($delete_old_output_cmd);
}


my $original_dir = "$output_dir/orig";
my $unpack_dir = "$output_dir/unpack";

mkdir($output_dir);
mkdir($original_dir);
mkdir($unpack_dir);

open(HTMLREPORT, ">$output_dir/index.html") || die "Unable to create HTML report";;

print HTMLREPORT "<HTML><BODY>\n";
print "Unpacking original APK to $original_dir\n";

my $unzip_cmd = "unzip \"$target_app\" -d $original_dir";
run_command($unzip_cmd);

my $dex_unpack_dir = "$unpack_dir/classes_dex_unpacked";
mkdir($dex_unpack_dir);

print "Disassembling DEX files to $dex_unpack_dir\n";

my $dex_cmd = "java -jar $exe_path/ddx.jar -d $dex_unpack_dir $original_dir/classes.dex";
run_command($dex_cmd);

print "Analyzing app file usage\n";
my $file_usage_cmd = "$exe_path/android_file_usage.pl $dex_unpack_dir > $output_dir/file_usage.txt";
run_command("$file_usage_cmd");

print "Decoding XML files\n";
$find_xml_cmd = "find $original_dir -name \"*.xml\" |";
print "find_xml_cmd = $find_xml_cmd\n";

open(XMLFILES, "$find_xml_cmd");
while(<XMLFILES>)
{
    chop;
    my $source_xml_file = $_;
    # print "Found a source XML file: $source_xml_file\n";
    my $target_xml_file = $source_xml_file;
    $target_xml_file =~ s/$original_dir/$unpack_dir/;
    my $decode_xml_file_cmd = "$exe_path/axml2xml.pl < $source_xml_file > $target_xml_file";
    create_path_tree($target_xml_file);
    run_command($decode_xml_file_cmd);
}
close(XMLFILES);

# Let's convert the DEX code into Java bytecode in a JAR file

my $dex2jar_cmd = "$exe_path/dex2jar/dex2jar.sh $original_dir/classes.dex";
run_command($dex2jar_cmd);
my $jar_mv_cmd = "mv $original_dir/classes.dex.dex2jar.jar $unpack_dir/classes.dex.dex2jar.jar";
run_command($jar_mv_cmd);

my $findbugs_cmd = "java -jar $exe_path/findbugs/lib/findbugs.jar -textui -effort:max -sortByClass -low -html -output $output_dir/findbugs.html $unpack_dir/classes.dex.dex2jar.jar";
run_command($findbugs_cmd);

print HTMLREPORT "<a href=\"findbugs.html\">FindBugs Results</a>\n";


# Let's pull apart the AndroidManifest.xml files to see:
#   -What permissions the app needs
#   -What screens are in the app

print HTMLREPORT "<a href=\"$unpack_dir/AndroidManifest.xml\">AndroidManifest.xml</a>\n";

my $xp = XML::XPath->new(filename => "$unpack_dir/AndroidManifest.xml");

open(PERMISSIONS, ">$output_dir/permissions.txt");
open(SCREENS, ">$output_dir/screens.txt");
open(LIBRARIES, ">$output_dir/libraries.txt");

my $base_package;
my $nodeset;

# Determine the base package
$nodeset = $xp->find("/manifest");

# Ugly. Really ought to learn Perl and XPath...  ;)
foreach my $node ($nodeset->get_nodelist) {
    print "node: $node\n";
    $base_package = $node->findvalue('@package');
}

print "Base package is: $base_package\n";

$nodeset = $xp->find("/manifest/uses-permission");

foreach my $node ($nodeset->get_nodelist) {
    print "App needs permission " . $node->findvalue('@android:name') . "\n";
    print(PERMISSIONS $node->findvalue('@android:name') . "\n");
}

$nodeset = $xp->find('/manifest/application/activity');

foreach my $node ($nodeset->get_nodelist) {
    print "App has screen $base_package" . $node->findvalue('@android:name') . "\n";
    print(SCREENS $base_package . $node->findvalue('@android:name') . "\n");
}

close(PERMISSIONS);
close(SCREENS);
close(LIBRARIES);


open(URLS, ">$output_dir/urls.txt");
open(HOSTNAMES, ">$output_dir/hostnames.txt");
open(WEB_PATHS, ">$output_dir/web_paths.txt");

my $field_constants_cmd = "grep \".field \" \`find $dex_unpack_dir -name \"*\"\` |";
print "field_constants_cmd = $field_constants_cmd\n";
open(FIELD_CONSTANTS, "$field_constants_cmd");
open(FIELD_CONSTANTS_OUT, ">$output_dir/field_constants.txt");
while(<FIELD_CONSTANTS>)
{
    chomp;

    my $filename;
    my $rest_of_line;
    my @rest_of_line_split;
    my $num_fields;

    # print FIELD_CONSTANTS_OUT "$_\n";
    ($filename, $rest_of_line) = split(/:\.field /, $_, 2);
    $_ = $rest_of_line;
    if(/Ljava\/lang\/String;/)
    {
        # print "File: $filename, Rest of line: $rest_of_line\n";
        # @rest_of_line_split = split(/ /, $rest_of_line);
        # $num_fields = @rest_of_line_split;
        if(substr($rest_of_line,length($rest_of_line)-1,1) eq "\"")
        {
            my $text_string;
            $text_string = parse_string_constant($rest_of_line);
            print FIELD_CONSTANTS_OUT "$filename,$text_string\n";

            $_ = $text_string;

            if(is_url($_) eq true) {
                print "Found a URL: $_\n";
                print(URLS "$_\n");
            } elsif(is_hostname($_) eq true || is_ip($_) eq true) {
                 print "Found a hostname: $_\n";
                 print(HOSTNAMES "$_\n");
            } elsif(is_web_part($_) eq true) {
                 print "Found part of a web path: $_\n";
                 print(WEB_PATHS "$_\n");
            }
        }
    }
}
close(FIELD_CONSTANTS);
close(FIELD_CONSTANTS_OUT);

# print "Scannind DEX code for const-strings\n";
my $const_strings_cmd = "grep \"const-string\" \`find $dex_unpack_dir -name \"*\"\` |";
print "const_strings_cmd = $const_strings_cmd\n";
open(CONST_STRINGS, "$const_strings_cmd");
open(CONST_STRINGS_OUT, ">$output_dir/const_strings.txt");
while(<CONST_STRINGS>)
{
    chomp;
    print "$_\n";

    my $beginning_of_line, $end_of_line;
    my $filename, $constant;

    ($beginning_of_line, $end_of_line) = split(/,/, $_);
    chop($end_of_line);
    $constant = substr($end_of_line, 1);
    
    ($beginning_of_line, $end_of_line) = split(/:/, $_);
    $filename = $beginning_of_line;

    print "File is $filename\n";
    print "Constant is $constant\n";
    
    print CONST_STRINGS_OUT "$filename,$constant\n";

    $_ = $constant;

    if(is_url($_) eq true) {
        print "Found a URL: $_\n";
        print(URLS "$_\n");
    } elsif(is_hostname($_) eq true || is_ip($_) eq true) {
         print "Found a hostname: $_\n";
         print(HOSTNAMES "$_\n");
    } elsif(is_web_part($_) eq true) {
         print "Found part of a web path: $_\n";
         print(WEB_PATHS "$_\n");
    }
}
close(CONST_STRINGS);
close(CONST_STRINGS_OUT);

close(URLS);
close(HOSTNAMES);
close(WEB_PATHS);

print HTMLREPORT "</BODY></HTML>\n";

close(HTMLREPORT);
