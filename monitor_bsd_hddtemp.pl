#!/usr/local/bin/perl

use strict;
use warnings;

use IO::Socket::INET;
use Sys::Hostname;

my $settings_ref = {
	'influxdb' => {
		'address'	=> '192.168.20.4',
		'port'		=> 8089,
	},
	'smartctl' => {
		'path'	=> '/usr/local/sbin/smartctl',
	},
	'sysctl' => {
		'path'	=> '/sbin/sysctl',
	},
};

main($settings_ref);
exit();

sub main {

	my $settings_ref = shift;

	my $hddinfo_ref = get_hddinfo($settings_ref);
	send_data($settings_ref, $hddinfo_ref);
	return();
}

sub get_hddinfo {

	my $settings_ref = shift;

	my %hdd_info;

	my $output = `$settings_ref->{'sysctl'}->{'path'} -n kern.disks`;
	chomp($output);

	foreach my $disk ( sort split(/ /, $output) ) {

		my $smartinfo_ref = get_smartinfo($settings_ref, $disk);
		$hdd_info{$disk} = $smartinfo_ref;
	}

	return(\%hdd_info);
}

sub get_smartinfo {

	my $settings_ref = shift;
	my $disk = shift;
	my $smartinfo_ref;

	# Sample input
	#   smartctl 6.5 2016-05-07 r4318 [FreeBSD 10.3-STABLE amd64] (local build)
	#   Copyright (C) 2002-16, Bruce Allen, Christian Franke, www.smartmontools.org
	#   
	#   === START OF INFORMATION SECTION ===
	#   Model Family:     Seagate Momentus 7200.4
	#   Device Model:     ST9250410AS
	#   Serial Number:    5VG3GJV3
	#   LU WWN Device Id: 5 000c50 0218d6714
	#   Firmware Version: 0002SDM1
	#   User Capacity:    250,059,350,016 bytes [250 GB]
	#   Sector Size:      512 bytes logical/physical
	#   Rotation Rate:    7200 rpm
	#   Device is:        In smartctl database [for details use: -P show]
	#   ATA Version is:   ATA8-ACS T13/1699-D revision 4
	#   SATA Version is:  SATA 2.6, 3.0 Gb/s
	#   Local Time is:    Mon Sep 19 20:16:46 2016 CEST
	#   SMART support is: Available - device has SMART capability.
	#   SMART support is: Enabled
	open(INPUT, "$settings_ref->{'smartctl'}->{'path'} -i /dev/$disk|") or return(1, [ "unable to open smartctl: $!" ], undef);
	my @output = <INPUT>;
	close(INPUT);

	chomp(@output);

	my $info_regexref = {
		'firmware'	=> 'Firmware Version',
		'type'		=> 'Device Model',
		'serial'	=> 'Serial Number',
		'guid'		=> 'LU WWN Device Id',
	};

	foreach my $line ( @output ) {

		foreach my $object ( keys %{$info_regexref} ) {

			if( $line =~ /$info_regexref->{$object}/ ) {

				my @info = split(/: +/, $line, 2);
				if( $object eq 'guid' ) {
					$info[1] =~ s/ //g;
				}
				if( $object eq 'type' && $info[1] =~ / / ) {
					$info[1] =~ s/.+ //;
				}
				$smartinfo_ref->{$object} = $info[1];
				last;
			}
		}
	}

	# Sample Input
	#   === START OF READ SMART DATA SECTION ===
	#   SMART Attributes Data Structure revision number: 10
	#   Vendor Specific SMART Attributes with Thresholds:
	#   ID# ATTRIBUTE_NAME          FLAG     VALUE WORST THRESH TYPE      UPDATED  WHEN_FAILED RAW_VALUE
	#     1 Raw_Read_Error_Rate     0x000f   108   093   006    Pre-fail  Always       -       58010310
	#     3 Spin_Up_Time            0x0003   100   100   085    Pre-fail  Always       -       0
	#     4 Start_Stop_Count        0x0032   100   100   020    Old_age   Always       -       66
	#     5 Reallocated_Sector_Ct   0x0033   100   100   036    Pre-fail  Always       -       0
	#     7 Seek_Error_Rate         0x000f   082   060   030    Pre-fail  Always       -       201042270
	#     9 Power_On_Hours          0x0032   044   044   000    Old_age   Always       -       49157
	#    10 Spin_Retry_Count        0x0013   100   100   097    Pre-fail  Always       -       0
	#    12 Power_Cycle_Count       0x0032   100   100   020    Old_age   Always       -       66
	#   184 End-to-End_Error        0x0032   100   100   099    Old_age   Always       -       0
	#   187 Reported_Uncorrect      0x0032   001   001   000    Old_age   Always       -       621
	#   188 Command_Timeout         0x0032   100   099   000    Old_age   Always       -       12885098506
	#   189 High_Fly_Writes         0x003a   100   100   000    Old_age   Always       -       0
	#   190 Airflow_Temperature_Cel 0x0022   066   046   045    Old_age   Always       -       34 (Min/Max 23/42)
	#   191 G-Sense_Error_Rate      0x0032   100   100   000    Old_age   Always       -       1
	#   192 Power-Off_Retract_Count 0x0032   100   100   000    Old_age   Always       -       3
	#   193 Load_Cycle_Count        0x0032   001   001   000    Old_age   Always       -       5431785
	#   194 Temperature_Celsius     0x0022   034   054   000    Old_age   Always       -       34 (0 21 0 0 0)
	#   195 Hardware_ECC_Recovered  0x001a   031   019   000    Old_age   Always       -       58010310
	#   197 Current_Pending_Sector  0x0012   100   100   000    Old_age   Always       -       0
	#   198 Offline_Uncorrectable   0x0010   100   100   000    Old_age   Offline      -       0
	#   199 UDMA_CRC_Error_Count    0x003e   200   200   000    Old_age   Always       -       0
	#   240 Head_Flying_Hours       0x0000   100   253   000    Old_age   Offline      -       29047 (13 133 0)
	#   241 Total_LBAs_Written      0x0000   100   253   000    Old_age   Offline      -       699970078
	#   242 Total_LBAs_Read         0x0000   100   253   000    Old_age   Offline      -       1397743562
	#   254 Free_Fall_Sensor        0x0032   100   100   000    Old_age   Always       -       0
	open(INPUT, "$settings_ref->{'smartctl'}->{'path'} -A /dev/$disk|") or return(1, [ "unable to open smartctl: $!" ], undef);
	@output = <INPUT>;
	close(INPUT);

	chomp(@output);

	foreach my $line ( @output ) {

		if( $line =~ /Temperature_Celsius/ ) {

			my @info = split(/ +/, $line);
			$smartinfo_ref->{'value'} = $info[9]
		}
	}

	# Sample output
	#   smartctl 6.5 2016-05-07 r4318 [FreeBSD 10.3-STABLE amd64] (local build)
	#   Copyright (C) 2002-16, Bruce Allen, Christian Franke, www.smartmontools.org
	#   
	#   === START OF READ SMART DATA SECTION ===
	#   SMART overall-health self-assessment test result: PASSED
	open(INPUT, "$settings_ref->{'smartctl'}->{'path'} -H /dev/$disk|") or return(1, [ "unable to open smartctl: $!" ], undef);
	@output = <INPUT>;
	close(INPUT);

	chomp(@output);

	foreach my $line ( @output ) {

		if( $line =~ /SMART overall-health/ ) {

			my @info = split(/: +/, $line);
			$smartinfo_ref->{'smart_status'} = $info[1]
		}
	}

	return($smartinfo_ref);
}

sub create_lineprotocol {

	my $data_ref = shift;

	my $hostname = hostname();

	my $line_protocol;
	my $timestamp = (int( time /10 ) * 10 ) * 1000000000;

	foreach my $disk ( sort keys %{$data_ref} ) {

		my @tags;
		push(@tags, "hdd_temp");
		push(@tags, "disk=$disk");
		push(@tags, "host_name=$hostname");

		foreach my $tag ( sort keys %{$data_ref->{$disk}} ) {

			next if( $tag eq "value" );
			push(@tags, "$tag=$data_ref->{$disk}->{$tag}");
		}

		my @data;
		push(@data, join(',', @tags));
		push(@data, "value=$data_ref->{$disk}->{'value'}");
		push(@data, $timestamp);

		$line_protocol .= sprintf("%s %s %d\n", @data);
	}

	return($line_protocol);
}

sub send_data {

	my $settings_ref = shift;
	my $data_ref = shift;

	my $socket = new IO::Socket::INET (
		PeerAddr	=> $settings_ref->{'influxdb'}->{'address'},
		PeerPort	=> $settings_ref->{'influxdb'}->{'port'},
		Proto		=> 'udp',
	) or return(1, [ "cannot create socket: $@" ]);

	my $lineprotocol = create_lineprotocol($data_ref);

	$socket->send($lineprotocol);
	$socket->close;

	return(0, []);
}

__END__

=head1 NAME

monitor_bsd_hddtemp.pl - Monitor HDD temperatures on FreeBSD systems

=head1 VERSION

Version 1.0 (September 2016)

=head1 SYNOPSYS

	monitor_bsd_hddtemp.pl

=head1 DESCRIPTION

This script gathers HDD temperature information and sends it via UDP to an
Influx time-series database. The data in the InfluxDB can be visualized in
different ways like Grafana and Influx' own Chronograf.

The data is formatted specifically for the IndluxDB in the line protocol format.
The line protocol supports tags to add information to the values. The hostname,
the model, the serial number, the firmware version, GUID (or WWN if available)
and the S.M.A.R.T. status are added as tags

The address and port of the InfluxDB server is configured in the hash for the
settings at the top of the script. The influxDB database should be configured to
accept data over UDP. See the InfluxDB documentation on how to do this.

=head1 NOTES

This software has been tested on FreeNAS 9.10. It should work with other FreeBSD
versions and maybe even on other BSD versions supporting smartctl and temperature
monitoring.

=head1 AUTHOR

Jurriaan Saathof <jurriaan@xenophobia.nl>

=head1 COPYRIGHT

Copyright 2016 Jurriaan Saathof

=head1 SEE ALSO

IO::Socket::INET(3pm), Sys::Hostname{3pm}
https://www.influxdata.com/time-series-platform/
http://grafana.org
http://www.freenas.org

=cut
