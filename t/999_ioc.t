#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';

use ok 'Test::IOC';

use IOC;

{
    package FileLogger;
    sub new { 
        my ($class, $log_file) = @_;
        ($log_file eq 'logfile.log') || die "Got wrong log file";
        bless { log_file => $log_file } => $class; 
    }
    sub log_file { (shift)->{log_file} }
    
    package Application;
    sub new { 
        my $class = shift;
        bless { logger => undef } => $class 
    }
    sub logger { 
        my ($self, $logger) = @_;
        (UNIVERSAL::isa($logger, 'FileLogger')) || die "Got wrong logger type";
        $self->{logger} = $logger;
    }
    sub run {}
}

my $container = IOC::Container->new('moose');
$container->register(IOC::Service::Literal->new('log_file' => "logfile.log"));
$container->register(IOC::Service->new('logger' => sub { 
    my $c = shift; 
    return FileLogger->new($c->get('log_file'));
}));
$container->register(IOC::Service->new('application' => sub {
    my $c = shift;
    my $app = Application->new();
    $app->logger($c->get('logger'));
    return $app;
}));

my $reg = IOC::Registry->new();
$reg->registerContainer($container);

isa_ok(Test::IOC::registry(), 'IOC::Registry');
is(Test::IOC::registry(), $reg, "... our registry is the same");

container_exists("/moose");
container_list_is("/", [ "moose" ], "... these are the containers in the reg");

service_list_is("/moose", [qw/application log_file logger/]);

service_exists("/moose/application");
service_isa("/moose/application", "Application");
service_is_deeply("/moose/application", $container->get("application"), "app is same as in container");
service_can("/moose/application", "logger");
service_can("/moose/application", "run");

service_exists("/moose/log_file");
service_is("/moose/log_file", $container->get("log_file"), "log file is same as in container");

service_exists("/moose/logger");
service_isa("/moose/logger", "FileLogger");
service_is_deeply("/moose/logger", $container->get("logger"), "logger service returned OK");
service_can("/moose/logger", "log_file");

# lifecycle stuff
# feel free to change these function names
# these will require you to fetch the service yourself, 
# probably the easiest way is to make your own visitor
# of sorts, you decide, but this tests the service wrapper
# not the item within it
service_is_literal("/moose/log_file");
service_is_prototype("/moose/??");
service_is_singleton("/moose/application");

# hmm... nothing else that comes to mind right now

service_does("/moose/application", sub { ... something random ... }); # ???




