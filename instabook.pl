#! /usr/bin/perl
use Modern::Perl;
use Web::Scraper;
use WWW::Mechanize;
use Getopt::Long;
use Data::Dump;
use JSON;
use Encode;
use String::MFN;
use autodie;

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
open my $file, '<', "$dest_dir/synced.json";
my $arrayref = from_json(join "\n", <$file>);
close $file;
$synced->{$_} = 1 for @$arrayref;

$SIG{__DIE__} = $SIG{INT} = sub {
    open my $file, '>', "$dest_dir/synced.json";
    print $file to_json([sort { $a <=> $b } keys %$synced], {pretty => 1});
    exit;
};

#use Data::Dumper;
#print Dumper($t_res);
#print Dumper($synced);

foreach my $link (@{$t_res->{links}}) {
    my ($id) = ($link->{href} =~ /article=(\d+)$/);     # old
    unless ($id) {
        ($id) = ($link->{href} =~ m{/go/(\d+)/text});     # new
    }

    warn "$link->{href}\n" unless defined $id;

    next if $synced->{$id};

    my $title_id = 0xffffffff - $id;

    $mech->get($link->{href});
    my $content = $mech->content();

    $content =~ s{<script.*?</script>}{}gs;

    my $title = Encode::encode('utf-8', mfn($link->{title}));

    open my $dest, '>', "$dest_dir/$title_id-$title.html"
        or die "Cannot write file: $!";
    print $dest Encode::encode('utf-8', $content);
    close $dest;

    $synced->{$id}++;

    say "Pausing for 10 secs";
    sleep 10;
}

open $file, '>', "$dest_dir/synced.json";
print $file to_json([sort { $a <=> $b } keys %$synced], {pretty => 1})
