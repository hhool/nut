#!/usr/bin/env perl
#   Current Version : 1.4
#   Copyright (C) 2008 - 2012 dloic (loic.dardant AT gmail DOT com)
#   Copyright (C) 2008 - 2015 Arnaud Quette <arnaud.quette@free.fr>
#   Copyright (C) 2013 - 2014 Charles Lepple <clepple+nut@gmail.com>
#   Copyright (C) 2014 - 2022 Jim Klimov <jimklimov+nut@gmail.com>
#
#   Based on the usbdevice.pl script, made for the Ubuntu Media Center
#   for the final use of the LIRC project.
#   Syntax dumbed down a notch to support old perl interpreters.
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA

# TODO list:
# - rewrite using glob, as in other helper scripts
# - manage deps in Makefile.am

use File::Find;
use strict;


my $TOP_SRCDIR = "..";
if (defined $ENV{'TOP_SRCDIR'}) {
    $TOP_SRCDIR = $ENV{'TOP_SRCDIR'};
}

my $TOP_BUILDDIR = "..";
if (defined $ENV{'TOP_BUILDDIR'}) {
    $TOP_BUILDDIR = $ENV{'TOP_BUILDDIR'};
}

# path to scan for USB_DEVICE pattern
my $scanPath="$TOP_SRCDIR/drivers";

# Hotplug output file
my $outputHotplug="$TOP_BUILDDIR/scripts/hotplug/libhid.usermap";

# udev output file
my $outputUdev="$TOP_BUILDDIR/scripts/udev/nut-usbups.rules.in";

# BSD devd output file
my $output_devd="$TOP_BUILDDIR/scripts/devd/nut-usb.conf.in";

# UPower output file
my $outputUPower="$TOP_BUILDDIR/scripts/upower/95-upower-hid.hwdb";

# NUT device scanner - C header
my $outputDevScanner = "$TOP_BUILDDIR/tools/nut-scanner/nutscan-usb.h";

my $GPL_header = "\
 *  Copyright (C) 2011 - Arnaud Quette <arnaud.quette\@free.fr>\
 *\
 *  This program is free software; you can redistribute it and/or modify\
 *  it under the terms of the GNU General Public License as published by\
 *  the Free Software Foundation; either version 2 of the License, or\
 *  (at your option) any later version.\
 *\
 *  This program is distributed in the hope that it will be useful,\
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of\
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the\
 *  GNU General Public License for more details.\
 *\
 *  You should have received a copy of the GNU General Public License\
 *  along with this program; if not, write to the Free Software\
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA";

# array of products indexed by vendorID
my %vendor;

# contain for each vendor, its name (and...)
my %vendorName;

################# MAIN #################

find({wanted=>\&find_usbdevs, preprocess=>sub{sort @_}}, $scanPath);
&gen_usb_files;

################# SUB METHOD #################
sub gen_usb_files
{
	# Hotplug file header
	my $outHotplug = do {local *OUT_HOTPLUG};
	open $outHotplug, ">$outputHotplug" || die "error $outputHotplug : $!";
	print $outHotplug '# This file is generated and installed by the Network UPS Tools package.'."\n";
	print $outHotplug "#\n";
	print $outHotplug '# Sample entry (replace 0xVVVV and 0xPPPP with vendor ID and product ID respectively) :'."\n";
	print $outHotplug '# libhidups      0x0003      0xVVVV   0xPPPP    0x0000       0x0000       0x00         0x00';
	print $outHotplug '            0x00            0x00            0x00               0x00               0x00000000'."\n";
	print $outHotplug "#\n";
	print $outHotplug '# usb module   match_flags idVendor idProduct bcdDevice_lo bcdDevice_hi';
	print $outHotplug ' bDeviceClass bDeviceSubClass bDeviceProtocol bInterfaceClass bInterfaceSubClass';
	print $outHotplug ' bInterfaceProtocol driver_info'."\n";

	# Udev file header
	my $outUdev = do {local *OUT_UDEV};
	open $outUdev, ">$outputUdev" || die "error $outputUdev : $!";
	print $outUdev '# This file is generated and installed by the Network UPS Tools package.'."\n\n";
	print $outUdev 'ACTION=="remove", GOTO="nut-usbups_rules_end"'."\n";
	print $outUdev 'SUBSYSTEM=="usb_device", GOTO="nut-usbups_rules_real"'."\n";
	print $outUdev 'SUBSYSTEM=="usb", GOTO="nut-usbups_rules_real"'."\n";
	print $outUdev 'GOTO="nut-usbups_rules_end"'."\n\n";
	print $outUdev 'LABEL="nut-usbups_rules_real"'."\n";

	my $out_devd = do {local *OUT_DEVD};
	open $out_devd, ">$output_devd" || die "error $output_devd : $!";
	print $out_devd '# This file is generated and installed by the Network UPS Tools package.'."\n";
	print $out_devd "# Homepage: https://www.networkupstools.org/\n\n";

	# UPower file header
	my $outUPower = do {local *OUT_UPOWER};
	open $outUPower, ">$outputUPower" || die "error $outputUPower : $!";
	print $outUPower '##############################################################################################################'."\n";
	print $outUPower '# Uninterruptible Power Supplies with USB HID interfaces'."\n#\n";
	print $outUPower '# This file was automatically generated by NUT:'."\n";
	print $outUPower '# https://github.com/networkupstools/nut/'."\n#\n";
	print $outUPower '# To keep up to date, monitor upstream NUT'."\n";
	print $outUPower '# https://github.com/networkupstools/nut/commits/master/scripts/upower/95-upower-hid.hwdb'."\n";
	print $outUPower "# or checkout the NUT repository and call 'tools/nut-usbinfo.pl'\n";

	# Device scanner header
	my $outDevScanner = do {local *OUT_DEV_SCANNER};
	open $outDevScanner, ">$outputDevScanner" || die "error $outputDevScanner : $!";
	print $outDevScanner '/* nutscan-usb'.$GPL_header."\n */\n\n";
	print $outDevScanner "#ifndef DEVSCAN_USB_H\n#define DEVSCAN_USB_H\n\n";
	print $outDevScanner "#include \"nut_stdint.h\"\t/* for uint16_t etc. */\n\n";
	print $outDevScanner "#include <limits.h>\t/* for PATH_MAX in usb.h etc. */\n\n";
	print $outDevScanner "#include <sys/param.h>\t/* for MAXPATHLEN etc. */\n\n";
	print $outDevScanner "/* libusb header file */\n";
	print $outDevScanner "#if (!WITH_LIBUSB_1_0) && (!WITH_LIBUSB_0_1)\n";
	print $outDevScanner "#error \"configure script error: Neither WITH_LIBUSB_1_0 nor WITH_LIBUSB_0_1 is set\"\n";
	print $outDevScanner "#endif\n\n";
	print $outDevScanner "#if (WITH_LIBUSB_1_0) && (WITH_LIBUSB_0_1)\n";
	print $outDevScanner "#error \"configure script error: Both WITH_LIBUSB_1_0 and WITH_LIBUSB_0_1 are set\"\n";
	print $outDevScanner "#endif\n\n";
	print $outDevScanner "#if WITH_LIBUSB_1_0\n";
	print $outDevScanner "# include <libusb.h>\n";
	print $outDevScanner "#endif\n";
	print $outDevScanner "#if WITH_LIBUSB_0_1\n";
	print $outDevScanner "# ifdef HAVE_USB_H\n";
	print $outDevScanner "#  include <usb.h>\n";
	print $outDevScanner "# else\n";
	print $outDevScanner "#  ifdef HAVE_LUSB0_USB_H\n";
	print $outDevScanner "#   include <lusb0_usb.h>\n";
	print $outDevScanner "#  else\n";
	print $outDevScanner "#   error \"configure script error: Neither HAVE_USB_H nor HAVE_LUSB0_USB_H is set for the WITH_LIBUSB_0_1 build\"\n";
	print $outDevScanner "#  endif\n";
	print $outDevScanner "# endif\n";
	print $outDevScanner " /* simple remap to avoid bloating structures */\n";
	print $outDevScanner " typedef usb_dev_handle libusb_device_handle;\n";
	print $outDevScanner "#endif\n";
	# vid, pid, driver
	print $outDevScanner "typedef struct {\n\tuint16_t\tvendorID;\n\tuint16_t\tproductID;\n\tchar*\tdriver_name;\n} usb_device_id_t;\n\n";
	print $outDevScanner "/* USB IDs device table */\nstatic usb_device_id_t usb_device_table[] = {\n\n";

	# generate the file in alphabetical order (first for VendorID, then for ProductID)
	foreach my $vendorId (sort { lc $a cmp lc $b } keys  %vendorName)
	{
		# Hotplug vendor header
		if ($vendorName{$vendorId}) {
			print $outHotplug "\n# ".$vendorName{$vendorId}."\n";
		}

		# udev vendor header
		if ($vendorName{$vendorId}) {
			print $outUdev "\n# ".$vendorName{$vendorId}."\n";
		}

		# devd vendor header
		if ($vendorName{$vendorId}) {
			print $out_devd "\n# ".$vendorName{$vendorId}."\n";
		}


		# UPower vendor header flag
		my $upowerVendorHasDevices = 0;

		foreach my $productId (sort { lc $a cmp lc $b } keys %{$vendor{$vendorId}})
		{
			# Hotplug device entry
			print $outHotplug "# ".$vendor{$vendorId}{$productId}{"comment"}."\n";
			print $outHotplug "libhidups      0x0003      ".$vendorId."   ".$productId."    0x0000       0x0000       0x00";
			print $outHotplug "         0x00            0x00            0x00            0x00               0x00               0x00000000\n";

			# udev device entry
			print $outUdev "# ".$vendor{$vendorId}{$productId}{"comment"}.' - '.$vendor{$vendorId}{$productId}{"driver"}."\n";
			print $outUdev "ATTR{idVendor}==\"".removeHexPrefix($vendorId);
			print $outUdev "\", ATTR{idProduct}==\"".removeHexPrefix($productId)."\",";
			print $outUdev ' MODE="664", GROUP="@RUN_AS_GROUP@"'."\n";

			# devd device entry
			print $out_devd "# ".$vendor{$vendorId}{$productId}{"comment"}.' - '.$vendor{$vendorId}{$productId}{"driver"}."\n";
			print $out_devd "notify 100 {\n\tmatch \"system\"\t\t\"USB\";\n";
			print $out_devd "\tmatch \"subsystem\"\t\"DEVICE\";\n";
			print $out_devd "\tmatch \"type\"\t\t\"ATTACH\";\n";
			print $out_devd "\tmatch \"vendor\"\t\t\"$vendorId\";\n";
			#
			print $out_devd "\tmatch \"product\"\t\t\"$productId\";\n";
			print $out_devd "\taction \"chgrp \@RUN_AS_GROUP\@ /dev/\$cdev; chmod g+rw /dev/\$cdev\";\n";
			print $out_devd "};\n";

			# UPower device entry (only for USB/HID devices!)
			if ($vendor{$vendorId}{$productId}{"driver"} eq "usbhid-ups")
			{
				if (!$upowerVendorHasDevices) {
					if ($vendorName{$vendorId}) {
						print $outUPower "\n# ".$vendorName{$vendorId}."\n";
					}
					$upowerVendorHasDevices = 1;
				}
				print $outUPower "usb:v".uc(removeHexPrefix($vendorId))."p".uc(removeHexPrefix($productId))."*\n";
			}

			# Device scanner entry
			print $outDevScanner "\t{ ".$vendorId.', '.$productId.", \"".$vendor{$vendorId}{$productId}{"driver"}."\" },\n";
		}

		if ($upowerVendorHasDevices) {
			print $outUPower " UPOWER_BATTERY_TYPE=ups\n";
			if ($vendorName{$vendorId}) {
				print $outUPower " UPOWER_VENDOR=".$vendorName{$vendorId}."\n";
			}
		}

	}
	# Udev footer
	print $outUdev "\n".'LABEL="nut-usbups_rules_end"'."\n";

	# Device scanner footer
	print $outDevScanner "\n\t/* Terminating entry */\n\t{ 0, 0, NULL }\n};\n#endif /* DEVSCAN_USB_H */\n\n";
}

sub find_usbdevs
{
	# maybe there's an option to turn off all .* files, but anyway this is stupid
	return $File::Find::prune = 1 if ($_ eq '.svn') || ($_ =~ /^\.#/) || ($_ =~ /\.orig$/);

	my $nameFile=$_;
	my $lastComment="";

	my $file = do {local *FILE};
	open ($file, $nameFile) or die "error open file $nameFile";
	while(my $line = <$file>)
	{
		# catch comment (should permit comment on the precedent or on the current line of USB_DEVICE declaration)
		if($line =~/\s*\/\*(.+)\*\/\s*$/)
		{
			$lastComment=$1;
		}

		if($line =~/^\s*\{\s*USB_DEVICE\(([^)]+)\,([^)]+)\)\s*/) # for example : { USB_DEVICE(MGE_VENDORID, 0x0001)... }
		{
			my $VendorID=trim($1);
			my $ProductID=trim($2);
			my $VendorName="";

			# special thing for backward declaration using #DEFINE
			# Format:
			# /* vendor name */
			# #define VENDORID 0x????
			my $fh = do {local *FH};
			if(!($VendorID=~/\dx(\d|\w)+/))
			{
				open $fh, $nameFile or die "error open file $nameFile";
				while(my $data = <$fh>)
				{
					# catch Vendor Name
					if($data =~/\s*\/\*(.+)\*\/\s*$/)
					{
						$VendorName=$1;
					}
					# catch VendorID
					if ($data =~ /(#define|#DEFINE)\s+$VendorID\s+(\dx(\d|\w)+)/)
					{
						$VendorID=$2;
						last;
					}
				}

				close $fh;
			}
			# same thing for the productID
			if(!($ProductID=~/\dx(\d|\w)+/))
			{
				my $data = do { open $fh, $nameFile or die "error open file $nameFile"; join '', <$fh> };
				if ($data =~ /(#define|#DEFINE)\s+$ProductID\s+(\dx(\d|\w)+)/)
				{
					$ProductID=$2;
				}
				else
				{
					die "In file $nameFile, for product $ProductID, can't find the declaration of the constant";
				}
			}

			# store data (to be optimized)
			# and don't overwrite actual vendor names with empty values
			if( (!$vendorName{$VendorID}) or (($vendorName{$VendorID} eq "") and ($VendorName ne "")) )
			{
				$vendorName{$VendorID}=trim($VendorName);
			}
			$vendor{$VendorID}{$ProductID}{"comment"}=$lastComment;
			# process the driver name
			my $driver=$nameFile;
			if($nameFile=~/(.+)-hid\.c/) {
				$driver="usbhid-ups";
			}
			# generic matching rule *.c => *
			elsif ($nameFile =~ /(.+)\.c$/) {
				$driver=$1;
			}
			else {
				die "Unknown driver type: $nameFile";
			}
			if ($vendor{$VendorID}{$ProductID}{"driver"} && $ENV{"DEBUG"}) {
				print STDERR "nut-usbinfo.pl: VendorID=$VendorID ProductID=$ProductID " .
					"was already related to driver '" .
					$vendor{$VendorID}{$ProductID}{"driver"} .
					"' and changing to '$driver'\n";
			}
			$vendor{$VendorID}{$ProductID}{"driver"}=$driver;
		}
	}
}

sub removeHexPrefix {
	# make a local copy, not to alter the original entry
	my $string = $_[0];
	$string =~ s/0x//;
	return $string;
}

sub trim {
    my($str) = shift =~ m!^\s*(.+?)\s*$!i;
    defined $str ? return $str : return '';
}
