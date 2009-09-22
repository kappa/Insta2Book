#! /usr/bin/perl
use Modern::Perl;
use Web::Scraper;
use WWW::Mechanize;
use Getopt::Long;
use Data::Dump;
use Storable qw/retrieve nstore/;
use Encode;
use String::MFN;

my ($username, $password, $dest_dir) = (undef, undef, '.');
GetOptions( "username=s" => \$username,
            "password=s" => \$password,
            "destdir=s"  => \$dest_dir,
);

die "Usage: instabook --username <username> [--password <password> --destdir <dest dir>]\n" unless $username;

my $t_scraper = scraper {
    process '.tableViewCell',
        'links[]' => scraper {
            process '.tableViewCellTitleLink', title => 'TEXT';
            process '.textButton', href => '@href';
        }
};

my $mech = new WWW::Mechanize;
push @{ $mech->requests_redirectable }, 'POST';
$mech->show_progress(1);

$mech->get('http://www.instapaper.com/user/login');
$mech->submit_form(
    fields  => {
        username    => $username,
        password    => $password,
    }
);

$mech->get('/u');

my $t_res = $t_scraper->scrape($mech->content);
my $synced = {};
eval { $synced = retrieve("$dest_dir/synced.sto") };

$SIG{__DIE__} = $SIG{INT} = sub {
    nstore($synced, "$dest_dir/synced.sto");
    exit;
};

foreach my $link (@{$t_res->{links}}) {
    my ($id) = ($link->{href} =~ /(\d+)/);
    next if $synced->{$id};

    $mech->get($link->{href});
    my $content = $mech->content();

    my $title = Encode::encode('utf-8', mfn($link->{title}));

    open my $dest, '>', "$dest_dir/$title.html"
        or die "Cannot write file: $!";
    print $dest $content;
    close $dest;

    $synced->{$id}++;
}

nstore($synced, "$dest_dir/synced.sto");
