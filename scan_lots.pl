#!/usr/bin/perl
use strict;
use warnings;
use 5.26.0;
no autovivification;
binmode STDOUT, ":utf8";
use utf8;
use Data::Printer;
use Data::Dumper;
use File::Path qw(make_path);
use Text::CSV qw( csv );
use Math::Round qw(nearest);
use Date::DayOfWeek;
use Date::WeekNumber qw/ iso_week_number /;
use Encode;
use Encode::Unicode;
use JSON;
use FindBin;
use Scalar::Util qw(looks_like_number);

my %countries = ();

# Load countries from CSV
my $countries_rows = csv(
    in      => 'data/countries_iso2.csv',
    headers => 'auto',
);

for my $row (@$countries_rows) {
    my $name       = $row->{name}       // next;
    my $iso_code_2 = $row->{iso_code_2} // next;

    # Make codes lowercase to match lc() usage elsewhere
    $iso_code_2 = lc $iso_code_2;

    $countries{$iso_code_2} = $name;
}

my $json;
open my $in, '<', 'data/vaers_reports.json';
while (<$in>) {
    $json .= $_;
}
close $in;
$json = decode_json($json);
my @reports = @$json;

my %israeli_lots             = ();
my %countries_with_same_lots = ();

for my $report_data (@reports) {
    my $spllt_type = %$report_data{'spllt_type'} // die;
    $spllt_type = lc $spllt_type;
    if ($spllt_type) {
        my $iso_code_2 = substr($spllt_type, 0, 2);
        my @products_listed = @{%$report_data{'products_listed'}};
        if ($iso_code_2 eq 'hn') {
            for my $product_data (@products_listed) {
                my $vaccine_name = %$product_data{'vaccine_name'} // die;
                $vaccine_name    = lc $vaccine_name;
                if ($vaccine_name =~ /pfizer/ && $vaccine_name =~ /covid/) {
                    my $vaccine_lot = %$product_data{'vaccine_lot'} // die;
                    next unless length $vaccine_lot > 1;
                    $vaccine_lot = lc $vaccine_lot;
                    next if $vaccine_lot eq 'unknown';
                    $israeli_lots{$vaccine_lot}++;
                }
            }
        } else {
            for my $product_data (@products_listed) {
                my $vaccine_name = %$product_data{'vaccine_name'} // die;
                $vaccine_name    = lc $vaccine_name;
                if ($vaccine_name =~ /pfizer/ && $vaccine_name =~ /covid/) {
                    my $vaccine_lot = %$product_data{'vaccine_lot'} // die;
                    next unless length $vaccine_lot > 1;
                    $vaccine_lot = lc $vaccine_lot;
                    next if $vaccine_lot eq 'unknown';
                    $countries_with_same_lots{$vaccine_lot}->{$iso_code_2}++;
                }
            }
        }
    }
}

for my $report_data (@reports) {
    my $spllt_type = %$report_data{'spllt_type'} // die;
    $spllt_type = lc $spllt_type;
    if ($spllt_type) {
        my $iso_code_2 = substr($spllt_type, 0, 2);
        next if $iso_code_2 eq 'hn';
    }
}

my %israeli_lots_by_frequ = ();

for my $vaccine_lot (sort keys %israeli_lots) {
    my $total_aes = $israeli_lots{$vaccine_lot} // die;
    $israeli_lots_by_frequ{$total_aes}->{$vaccine_lot} = 1;
}

open my $out, '>', 'top_10_aes_lots_Hungary.csv';
say $out "Lot (Pfizer);AEs in Hungary;Other Countries;";
my $total_lots = 0;
for my $total_aes (sort{$b <=> $a} keys %israeli_lots_by_frequ) {
    for my $vaccine_lot (sort keys %{$israeli_lots_by_frequ{$total_aes}}) {
        my %by_fraq = ();

        for my $iso_code_2 (sort keys %{$countries_with_same_lots{$vaccine_lot}}) {
            my $total_aes = $countries_with_same_lots{$vaccine_lot}->{$iso_code_2};
            $by_fraq{$total_aes}->{$iso_code_2} = 1;
        }

        my $countries = '';
        my $countries_added = 0;
        for my $tot_aes (sort{$b <=> $a} keys %by_fraq) {
            for my $iso_code_2 (sort keys %{$by_fraq{$tot_aes}}) {
                my $country = $countries{$iso_code_2} // next;
                $countries .= ", $country ($tot_aes aes)" if $countries;
                $countries = "$country ($tot_aes aes)" unless $countries;
                $countries_added++;
                last if $countries_added >= 4;
            }
            last if $countries_added >= 4;
        }
        say $out "$vaccine_lot;$total_aes;$countries;";

        say "$vaccine_lot - $total_aes AEs in Hungary | $countries";

        $total_lots++;
        last if $total_lots >= 10;
    }
    last if $total_lots >= 10;
}
close $out;