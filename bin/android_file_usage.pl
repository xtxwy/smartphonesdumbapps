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



# This script should be run on a directory that contains a set of disassembled DEX files (.ddx)
# It runs through all of the files in the directory and its subdirectories and looks for calls
# to android.content.Context.openFileOutput() and then traces back the arguments passed to
# that method in order to determine the filename and access permissions.  For each item it find
# it will write (to STDOUT):
#     -Filename (on Android device)
#     -Int value passed in for file access (hopefully 0, 1, 2, or 3)
#     -Text description of what the int value means:
#         -NONE - Standard permissions - only readable/writable by the app itself
#         -WORLD_READ - Any app can read this file
#         -WORLD_WRITE - Any app can write to this file
#         -WORLD_READWRITE - Any app can read or write to this file
#         -UNKNOWN - This is probably an error in the script where it couldn't properly trace
#                    the source of the data, but might also indicate a programmer error.  The
#                    value passed to this method is a constant, but not an enum so in theory
#                    a bad programmer might screw that up
# 
# At the current time this isn't sophisticated data flow analysis - it is pretty crudimentary
# directed grepping.  But it has worked for me more often than it hasn't so it apparently fits
# the most common programmer coding idioms and compiler/decompiler behaviors.



my $original_dir = $ARGV[0];

# print "Dir to check is $original_dir\n";

$find_dex_cmd = "find $original_dir -name \"*.ddx\" |";
# print "find_dex_cmd = $find_dex_cmd\n";

open(DEXFILES, "$find_dex_cmd");
while(<DEXFILES>)
{
    chop;
    my $dex_file = $_;

    # print "About to look at $dex_file\n";

    analyze_file($dex_file);
}
close(DEXFILES);


sub analyze_file
{
    my $target_file = $_[0];

    my @file_contents = read_file_to_array($target_file);;
    # print "Got file contents\n";

    my $index = 0;

    foreach(@file_contents) {
        # print "Looking at line $index: '$_'\n";
        my @parts = split(' ', $_);
        # print "@parts\n";

        if(@parts[0] eq 'invoke-virtual') {
	    # print "Line $index: '$_'\n";
            # print "Found a method call\n";

            my $divider_index = index(@parts[1], '}');
            my $args = substr(@parts[1], 1, $divider_index - 1);
            my $method = substr(@parts[1], $divider_index + 2);

            if($method eq 'android/content/Context/openFileOutput') {
                # print "Found a call to open a file at line $index. Searching for params\n";
                # print "Args: $args\n";

                my @args = split(',', $args);
                my $file_arg = @args[1];
                my $permissions_arg = @args[2];

                # print "Filename will be in arg $file_arg and permissions will be in arg $permissions_arg\n";

                my $filename = find_filename_arg($file_arg, $index, @file_contents);
                # print "Filename is: $filename\n";

                my $permissions = find_permissions_arg($permissions_arg, $index, @file_contents);
                # print "Permissions are: $permissions\n";

                my $permissions_text = translate_permissions($permissions);

                print "$filename,$permissions,$permissions_text,$target_file\n";
            }
        }

        $index++;
    }
}

sub translate_permissions
{
    my $perms = $_[0];
    my $ret_val = "UNKNOWN";

    if($perms == 0) {
        $ret_val = "NONE";
    } elsif($perms == 1) {
        $ret_val = "WORLD_READ";
    } elsif($perms == 2) {
        $ret_val = "WORLD_WRITE";
    } elsif($perms == 3) {
        $ret_val = "WORLD_READWRITE";
    }

    return($ret_val);
}

sub find_arg
{
    my ($arg_name, $instruction_to_match, $index, @file_contents) = @_;
    # my @file_contents = $_[0];
    # my $index = $_[1];
    # my $arg_name = $_[2];

    my $ret_val = "not_finished";

    # print "Looking for filename starting at index $index stored in arg $arg_name\n";
    # print "Size of file_contents is " . scalar(@file_contents) . "\n";

    for($i = $index - 1; $i >= 0; $i--) {
        # print "Checking line $i\n";
        my @parts = split(' ', @file_contents[$i]);
        if(@parts[0] eq $instruction_to_match) {
            # print "Found a $instruction_to_match in text @parts\n";
            my @const_assignment = split(',', @parts[1]);
            # print "Arg name is @const_assignment[0] and arg value is @const_assignment[1]\n";
            if(@const_assignment[0] eq $arg_name) {
                # print "Found our match for $arg_name\n";
                $ret_val = @const_assignment[1];
                last;
            }
        }
    }

    return $ret_val;
}

sub find_filename_arg
{
    my ($arg_name, $index, @file_contents) = @_;

    my $ret_val;

    $ret_val = find_arg($arg_name, 'const-string', $index, @file_contents);

    # String constants are surrounded by quotes so we need to strip those out
    $ret_val = substr($ret_val, 1, length($ret_val) - 2);

    return($ret_val);
}

sub find_permissions_arg
{
    my ($arg_name, $index, @file_contents) = @_;
    
    my $ret_val;

    $ret_val = find_arg($arg_name, 'const/4', $index, @file_contents);

    return($ret_val);

}

sub read_file_to_array
{
    my $target_file = $_[0];
    my @ret_val = ();

    open(MYFILE, $target_file) || die "Can't open file $target_file";

    while(<MYFILE>) {
        chop;
        # print "$_\n";
        push(@ret_val, $_);
    }
    close(MYFILE);

    return @ret_val;
}
