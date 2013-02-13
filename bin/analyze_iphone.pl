#!/usr/bin/env perl

# (C) Copyright 2010 - 2013 Denim Group, Ltd.

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


my $program_name = 'analyze_iphone';
my $platform_name ='iPhone';
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
    print "usage $0 <app_file_or_dir>\n";
    exit(1);
}

print "$program_name for $platform_name v$version\n";
print "Brought to you by Denim Group http://www.denimgroup.com/\n";

print "APP to analyze is: $target_app\n";
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

# We need to unpack .ipa files but copy .app directories

my $app_filename;
my $app_directory;
my $app_extension;


($app_filename, $app_directory, $app_extension) = fileparse($target_app, qr/\.[^.]*/);

if($app_extension eq ".ipa") {
    print "Found a packaged .ipa file.  Extracting.\n";
    print "Unpacking IPA file to $original_dir\n";
    my $unzip_cmd = "unzip \"$target_app\" -d \"$original_dir\"";
    run_command($unzip_cmd);
} elsif($app_extension eq ".app") {
    print "Found an expanded application.  Copying.\n";
    mkdir("$original_dir/Payload");
    my $copy_cmd = "cp -R \"$target_app\" \"$original_dir/Payload/\"";
    run_command($copy_cmd);
} else {
    print "Unknown file extension of $extension. Aborting.\n";
    exit(2);
}

# Find all of the strings in the app binary.  Ghetto, but strangely effective
# From this we'll look for URLs, hostnames, URL parts and function names

print "App filename: $app_filename\n";

print "Decoding PLIST files\n";
$find_plist_cmd = "find $original_dir -name \"*.plist\" |";
print "find_plist_cmd = $find_plist_cmd\n";

open(PLISTFILES, "$find_plist_cmd");
while(<PLISTFILES>)
{
    chop;
    my $source_plist_file = $_;
    # print "Found a source PLIST file: $source_plist_file\n";
    my $target_plist_file = $source_plist_file;
    $target_plist_file =~ s/$original_dir/$unpack_dir/;
    my $decode_plist_file_cmd = "plutil -convert xml1 -o $target_plist_file $source_plist_file";
    create_path_tree($target_plist_file);
    run_command($decode_plist_file_cmd);
}
close(PLISTFILES);

$find_plist_cmd = "find $original_dir -name \"*.strings\" |";
print "find_plist_cmd = $find_plist_cmd\n";

open(PLISTFILES, "$find_plist_cmd");
while(<PLISTFILES>)
{
    chop;
    my $source_plist_file = $_;
    # print "Found a source PLIST file: $source_plist_file\n";
    my $target_plist_file = $source_plist_file;
    $target_plist_file =~ s/$original_dir/$unpack_dir/;
    my $decode_plist_file_cmd = "plutil -convert xml1 -o $target_plist_file $source_plist_file";
    create_path_tree($target_plist_file);
    run_command($decode_plist_file_cmd);
}
close(PLISTFILES);



# Let's check to see if Info.plist tells us that the application has any URL Schemes defined

my $xp = XML::XPath->new(filename => "$unpack_dir/Payload/$app_filename.app/Info.plist");
    
my $nodeset = $xp->find("/plist/dict/array/dict[key='CFBundleURLSchemes']/array/string");

open(URL_SCHEMES, ">$output_dir/url_schemes.txt");
    
foreach my $node ($nodeset->get_nodelist) {
    print "Found URL scheme for " . $node->string_value() . "\n";
    print(URL_SCHEMES $node->string_value() . "\n");
}

close(URL_SCHEMES);


my $strings_cmd = "strings \"$original_dir/Payload/$app_filename.app/$app_filename\" > $output_dir/strings.txt";
run_command($strings_cmd);

open(URLS, ">$output_dir/urls.txt");
open(HOSTNAMES, ">$output_dir/hostnames.txt");
open(WEB_PATHS, ">$output_dir/web_paths.txt");

open(STRINGS, "$output_dir/strings.txt");

while(<STRINGS>) {

    chomp;

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

close(STRINGS);

close(URLS);
close(HOSTNAMES);
close(WEB_PATHS);

