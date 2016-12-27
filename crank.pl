#!/usr/bin/perl -w

use strict;
use warnings;

eval 'use Carp::Always'; # Not everyone has it

use Getopt::Long;
use File::Slurp;
use Encode qw(decode encode);
use Text::Markdown ();
use Template ();
use Template::Constants qw( :debug :chomp );

my $sourcepath = 's';
my $buildpath  = 'build';

GetOptions(
    'sourcepath:s' => \$sourcepath,
    'buildpath:s'  => \$buildpath,
) or exit;

-d $buildpath && -w $buildpath or die;

my $home  = 'Home';
my $about = 'About';

my $pages = [
    index        => $home,
    about        => $about,
    asp          => 'ASP',
    coldfusion   => 'ColdFusion',
    csharp       => 'C#',
    delphi       => 'Delphi',
    dotnet       => '.NET',
    go           => 'Go',
    java         => 'Java',
    perl         => 'Perl',
    php          => 'PHP',
    plsql        => 'PL/SQL',
    postgresql   => 'PostgreSQL',
    python       => 'Python',
    ruby         => 'Ruby',
    scheme       => 'Scheme',
];

MAIN: {
    my $m = Text::Markdown->new;

    my @sidelinks;

    my %tt_defaults = (
        INCLUDE_PATH => [ qw( tt ) ],
        OUTPUT_PATH  => $buildpath,
        DEBUG        => DEBUG_UNDEF,
        TRIM         => CHOMP_ALL,
        PRE_CHOMP    => 1,
        POST_CHOMP   => 1,
        ENCODING     => 'utf8',
    );

    my $tt = Template->new( \%tt_defaults );
    my $tt_first_pass = Template->new( { ENCODING => 'utf8' } );

    my @pages = @{$pages};
    while ( @pages ) {
        my ($section,$desc) = splice( @pages, 0, 2 );
        my $path = ($section eq 'index') ? './' : "./$section.html";
        push( @sidelinks, {
            path => $path,
            text => $desc,
        } );
    }

    my $vars = {
        sidelinks => \@sidelinks,
    };
    $vars->{rel_static} = ( 'C' eq $ENV{LANG} ) ? q(./) : q(../); # path prefix to static assets
    $vars->{rfc_1766_lang} = ( 'C' eq $ENV{LANG} ) ? 'en' : [map {tr/_/-/;$_} $ENV{LANG}]->[0];

    @pages = @{$pages};
    while ( @pages ) {
        my ($section,$desc) = splice( @pages, 0, 2 );

        my $source = read_file( "$sourcepath/$section.md" );
        my $first_pass;
        $tt_first_pass->process( \$source, undef, \$first_pass )
            || die sprintf("file: %s\nerror: %s\n", "$sourcepath/$section.md.tt2", $tt->error);

        my $html = $m->markdown($first_pass);
        $html =~ s{<code>\n}{<code>}smxg;
        $vars->{body} = $html;
        $vars->{section} = ($section eq 'index') ? '.' : "$section.html";
        $vars->{currlang} = ( ($desc eq $home) || ($desc eq $about) ) ? '' : $desc;
        $tt->process( 'page.tt', $vars, "$section.html", { binmode => ':encoding(UTF-8)' } )
            || die sprintf("file: %s\nerror: %s\n", "$section.html", $tt->error);
    }
}
