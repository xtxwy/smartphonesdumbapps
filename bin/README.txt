Smart Phones Dumb Apps v 0.1
(C) Copyright 2010 - 2013 Denim Group, Ltd
http://www.denimgroup.com/
http://www.smartphonesdumbapps.com/

Please email questions/comments/patches to dan _at_ denimgroup.com


This is a set of scripts and tools that can help analysts looking into the security of mobile applications.  These are not "point and click" tools that will look at an app and spit out a pretty list of vulnerabilities.  Rather they help to autmate some of the process of taking apart packaged mobile applications and pointing analysts toward things that might be interesting or warrant further review.  Right now as far as I know these scripts only run on my Mac OS X laptop because I have just tried to consolidate bits and pieces of stuff that me and other folks around the office have been doing.  Hopefully the tools will 


Contents:

analyze_android.pl
==================
-Unpacks an Android APK file
-Decodes the included XML files (including AndroidManifest.xml)
-Dumps permissions required by the app
-Dumps screens in the app
-Disassembles the DEX code
-Looks for URLs, hostnames and portions of web paths.
-Analyzes disassembled DEX code to find instances of file access and the associated permissions

Notes:
-Using axml2xml (http://code.google.com/p/android-random/source/browse/trunk/axml2xml/axml2xml.pl) to unpack the binary AndroidManifext.xml file
    -Had to install Unicode::String via "perl -MCPAN -e shell"
    -Also make sure that perl used to install the Unicode::String package is the same that axml2xml
-Using Dedexer (http://dedexer.sourceforge.net/) to decompile the DEX code back to Dalvik opcodes


android_file_usage.pl
=====================
-Runs analysis of disassembled DEX code to find situations where an app opens files
-Determines the associated filenames and file permissions

Notes:
-This is pretty crudimentary analysis and doesn't have a lot of error handling


analyze_iphone.pl
=================
-Unpacks an iPhone IPA file or decrypted XYZ.app/ directory
-Decodes .plist files to XML for review
-Looks through .plist XMLs in order to find URL Schemes the application has defined.
-Looks for URLs, hostnames and portions of web paths


run_fortify_android.pl
======================
Helper script to set up a successful scan of Android apps with Fortify SCA.  Mostly tries to find the environment JARs and include the auto-generated R.java file.



Please email questions/comments/patches to dan _at_ denimgroup.com
