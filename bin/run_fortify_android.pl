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


# If there are problems with the Perl module Config::Properties that can't be resolved
# then the $sdk_dir variable can just be set manually below.  This used to set up the 
# Java classpath

use Config::Properties;

if(@ARGV <= 0)
{
    print "usage: $0 <build_tag>\n";
    exit(1);
}

my $properties_file = "local.properties";
print "Reading in local properties file: $properties_file\n";

open PROPS, "< $properties_file" or die "Unable to read properties file: $properties_file\n";
my $properties = new Config::Properties();
$properties->load(*PROPS);
my $sdk_dir = $properties->getProperty("sdk.dir");
print "Android SDK found at: $sdk_dir\n";

my $build_tag = $ARGV[0];
print "Build tag is $build_tag\n";

my $build_cmd = "ant debug";
print "Build command is: $build_cmd\n";
system($build_cmd);

$clean_cmd = "sourceanalyzer -b $build_tag -clean";
print "Clean command is: $clean_cmd\n";
system($clean_cmd);

$load_cmd = "sourceanalyzer -b $build_tag -cp \"$sdk_dir/platforms/android-3/android.jar:libs/**/*.jar\" \"src/**/*.java\" \"gen/**/*.java\"";
print "Load command is: $load_cmd\n";
system($load_cmd);

$scan_cmd = "sourceanalyzer -b $build_tag -scan -f $build_tag.fpr";
print "Scan command is: $scan_cmd\n";
system($scan_cmd);
