#!/opt/local/bin/perl

# (C) Copyright 2010 - 2011 Denim Group, Ltd.

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

sub create_path_tree
{
    my $volume, $directories, $file;

    ($volume, $directories, $file) = File::Spec->splitpath($_[0]);
    File::Path->make_path($directories);
}

# Hostname RegEx borrowed from http://stackoverflow.com/questions/1418423/the-hostname-regex
sub is_hostname
{
    my $str = $_[0];
    my $ret_val = false;

    $_ = $str;
    # if(/^(?=.{1,255}$)[0-9A-Za-z](?:(?:[0-9A-Za-z]|\b-){0,61}[0-9A-Za-z])?(?:\.[0-9A-Za-z](?:(?:[0-9A-Za-z]|\b-){0,61}[0-9A-Za-z])?)*\.?$/)
    if(/^(?#Subdomains)(?:(?:[-\w]+\.)+(?#TopLevel Domains)(?:com|org|net|gov|mil|biz|info|mobi|name|aero|jobs|museum|travel|[a-z]{2}))$/)
    {
        $ret_val = true;
    }

    return $ret_val;
}

# IP Address RegEx borrowed from http://stackoverflow.com/questions/106179/regular-expression-to-match-hostname-or-ip-address
sub is_ip
{
    my $str = $_[0];
    my $ret_val = false;

    $_ = $str;
    if(/^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$/)
    {
        $ret_val = true;
    }

    return $ret_val;
}


# URL RegEx borrowed from http://flanders.co.nz/2009/11/08/a-good-url-regular-expression-repost/
sub is_url
{
    my $str = $_[0];
    my $ret_val = false;

    $_ = $str;
    if(/^(?#Protocol)(?:(?:ht|f)tp(?:s?)\:\/\/|~\/|\/)?(?#Username:Password)(?:\w+:\w+@)?(?#Subdomains)(?:(?:[-\w]+\.)+(?#TopLevel Domains)(?:com|org|net|gov|mil|biz|info|mobi|name|aero|jobs|museum|travel|[a-z]{2}))(?#Port)(?::[\d]{1,5})?(?#Directories)(?:(?:(?:\/(?:[-\w~!$+|.,=]|%[a-f\d]{2})+)+|\/)+|\?|#)?(?#Query)(?:(?:\?(?:[-\w~!$+|.,*:]|%[a-f\d{2}])+=?(?:[-\w~!$+|.,*:=]|%[a-f\d]{2})*)(?:&(?:[-\w~!$+|.,*:]|%[a-f\d{2}])+=?(?:[-\w~!$+|.,*:=]|%[a-f\d]{2})*)*)*(?#Anchor)(?:#(?:[-\w~!$+|.,*:=]|%[a-f\d]{2})*)?$/)
    {
        $ret_val = true;
    }

    # print "About to return $ret_val for input $str\n";

    return $ret_val;
}

sub is_web_part
{
    my $str = $_[0];
    my $ret_val = false;

    $_ = $str;
    if(/\//)
    {
        $ret_val = true;
    }

    return $ret_val;
}

sub make_output_directory
{
    my $volume, $directories, $file;
    my $ret_val;

    ($volume, $directories, $file) = File::Spec->splitpath($_[0]);
    $ret_val = $file;
    
    $ret_val =~ s/\./\_/g;

    return $ret_val;
}

# This is nasty and can be done way better - DanCo
sub parse_string_constant
{
    my $line = $_[0];
    my $ret_val;
    my $i;
    my $str_len = length($line);

    # print "Parsing string constant from: $line with length $str_len\n";

    for($i = $str_len - 2; $i >= 0; $i--)
    {
        my $current_char = substr($line, $i-1, 1);
        if($current_char eq "\"")
        {
             # print "Found a match with $current_char at index $i\n";
            last;
        }
    }
    
    # print "Going to grab index $i from $line\n";
    $ret_val = substr($line, $i);
    chop($ret_val);

    return($ret_val);
}

sub run_command
{
    my $cmd_line = $_[0];
    print "Command to execute: $cmd_line\n";
    system($cmd_line);
}

return (true);
