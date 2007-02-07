#!/usr/bin/perl

package Test::IOC;
use base qw/Exporter/;

use strict;
use warnings;

use Test::Builder;

use IOC::Registry;
use Test::More;

our @EXPORT = qw(
    locate_service search_service
    locate_container search_container
    service_isa service_is service_can service_is_deeply
    service_exists container_exists
    container_list_is service_list_is
    service_is_literal service_is_prototye service_is_singleton
);

our @EXPORT_OK = qw(
    registry
);

my $t = Test::Builder->new;

my $r = IOC::Registry->instance;

sub registry () { $r }

# utility subs

our $err;

sub try (&) {
    my $s = shift;
    local $@;
    my $r = eval { $s->( @_ ) };
    $err = $@;
    $r;
}

sub locate_service ($) {
    my $path = shift;
    try { registry->locateService($path) };
}

sub search_for_service ($) {
    my $name = shift;
    registry->searchForService($name);
}

sub locate_container ($) {
    my $path = shift;
    try { registry->locateContainer($path) }
}

sub search_for_container ($) {
    my $name = shift;
    registry->searchForContainer($name);
}

# basic tests

sub service_exists ($;$) {
    my ( $path, $desc ) = @_;
    $t->ok( defined(locate_service($path)), $desc || "The service '$path' exists in the registry" ) || diag $err;
}

sub container_exists ($;$) {
    my ( $path, $desc ) = @_;
    $t->ok( defined(locate_container($path)), $desc || "The container '$path' exists in the registry" );
}

sub service_alias_ok ($$;$) {
    my ( $real, $alias, $desc ) = @_;
    $desc ||= "The service at '$real' is aliased to '$alias'";

    return $t->is_eq( $real, registry->{service_aliases}{$alias}, $desc );

    # FIXME test it like this:

    # my $real_s  = locate_service($real);
    # my $alias_s = locate_service($alias);

    # return $t->fail("The service '$real' does not exist in the registry") unless defined $real_s;
    # return $t->fail("The service '$alias' does not exist in the registry") unless defined $alias;
    
    # compare true equality of IOC::Service objects or deep equality of the returned services
}

sub container_list_is ($$;$) {
    my ( $path, $spec, $desc ) = @_;
    local $" = ", ";
    $desc ||= "The containers at '$path' are @$spec";

    my @got;

    if ( $path eq "/" ) {
        @got = registry->getRegisteredContainerList;
    } else {
        my $c = locate_container($path) || return $t->fail("Container '$path' does not exist"); 
        @got = $c->getSubContainerList;
    }

    @_ = ( [ sort @got ], [ sort @$spec ], $desc );
    goto &is_deeply;
}

sub service_list_is ($$;$) {
    my ( $path, $spec, $desc ) = @_;
    local $" = ", ";
    $desc ||= "The services at '$path' are @$spec";

    if ( $path eq "/" ) {
        die "Services cannot be added to the registry";
    } else {
        my $c = locate_container($path) || return $t->fail("Container '$path' does not exist"); 

        @_ = ( [ sort $c->getServiceList ], [ sort @$spec ], $desc );
        goto &is_deeply;
    }
}

sub service_is_literal ($;$) {
    my ( $path, $desc ) = @_;
    $desc ||= "'$path' is a literal service";
    local $@;
    $t->ok( eval { get_service_object($path)->isa("IOC::Service::Literal") }, $desc );
}

sub service_is_prototye ($;$) {
    my ( $path, $desc ) = @_;
    $desc ||= "'$path' is a prototype service";
    local $@;
    $t->ok( eval { get_service_object($path)->isa("IOC::Service::Prototype") }, $desc );
}

sub service_is_singleton ($;$) {
    my ( $path, $desc ) = @_;
    $desc ||= "'$path' is a singleton service";
    local $@;
    my $s = get_service_object($path);
    $t->ok( eval {
        $s->isa("IOC::Service")
            and
        !$s->isa("IOC::Service::Literal")
            and
        !$s->isa("IOC::Service::Prototype")
    }, $desc );
}

sub get_service_object ($) {
    my $path = shift;
    $path =~ s{ / ([^/]+) $ }{}x;
    my $name = $1;
    my $c = locate_container($path) || return;
    $c->{services}{$name}; # FIXME yuck
}

# test + utility sub combination

my %tests = (
    is        => \&is,
    isa       => \&isa_ok,
    can       => \&can_ok,
    is_deeply => \&is_deeply,
);

foreach my $test ( keys %tests ) {
    my $test_sub = $tests{$test};

    no strict 'refs';
    *{ "service_$test" } = sub {
        use strict;
        my ( $path, @spec ) = @_;

        my $service = locate_service($path);

        if ( defined $service ) {
            @_ = ( $service, @spec );
            goto $test_sub;
        } else {
            fail( "The service '$path' does not exist in the registry" );
        }
    }
}

__PACKAGE__;

__END__

