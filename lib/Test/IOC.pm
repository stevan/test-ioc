#!/usr/bin/perl

package Test::IOC;
use base qw/Exporter/;

use Test::Builder;

use IOC::Registry;
use Test::More;

our @EXPORT = qw(
    locate_service search_service
    locate_container search_container
    service_isa service_is service_can
    registry
);
our @EXPORT_OK

my $t = Test::Builder->new;

my $r = IOC::Registry->instance;

sub registry () { $r }

sub import {
    my($self) = shift;
    my $pack = caller;

    $Test->exported_to($pack);
    $Test->plan(@_);

    $self->export_to_level(1, $self, @EXPORT);
}

# utility subs

sub locate_service ($) {
    my $path = shift;
    registry->locateService($path);
}

sub search_for_service ($) {
    my $name = shift;
    registry->locateService($name);
}

sub locate_container ($) {
    my $path = shift;
    registry->locateContainer($path);
}

sub search_for_container ($) {
    my $name = shift;
    registry->locateContainer($name);
}

# basic tests

sub service_exists ($;$) {
    my ( $path, $desc ) = @_;
    $t->ok( defined(locate_service($path)), $desc || "The service '$path' exists in the registry" );
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

# test + utility sub combination

my %tests = (
    is  => \&is,
    isa => \&isa_ok,
    can => \&can_ok,
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

=pod

=head1 NAME

Test::IOC - 

=head1 SYNOPSIS

	use Test::IOC;

=head1 DESCRIPTION

=cut


