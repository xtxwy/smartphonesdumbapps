#!/usr/bin/env bash

# This solves the 'Can't locate Unicode/String.pm' error on axml2xml.pl
sudo perl -MCPAN -e 'install Unicode::String'
