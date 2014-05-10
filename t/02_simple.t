#!/usr/bin/perl

# Base flow tests.

use strict;
use Test::Spec;
use base qw(Test::Spec);
use Test::MockObject;

use Git::ClonesManager;
use File::Temp ();

my $tmp_dir = File::Temp::tempdir( CLEANUP => 1 );
ok( (-d $tmp_dir), 'tmp dir created' );
my $cm_obj;
my $gr_mock;
my $test_project_alias = 'my-gc-test-project-'.$$;

describe "base flow" => sub {

	before each => sub {
		$cm_obj = Git::ClonesManager->new( data_path => $tmp_dir, vl => 1 );
	};

	it "new project call clone" => sub {
		$gr_mock = Test::MockObject->new();
		$gr_mock->fake_new('Git::Repository');
		$gr_mock->set_true('run');
		my $run_args = [];
		$gr_mock->fake_module(
			'Git::Repository',
			run => sub { push @$run_args, [ 'run_sub', @_ ]; }
		);
		$cm_obj->get_repo_obj($test_project_alias, repo_url => 'git.somerepo.url');
		is( $run_args->[0][0], 'run_sub', 'GR->run sub called' );
		is( $run_args->[0][2], 'clone', 'GR->...(clone,...) sub arg provided' );
	};

	it "already created project call fetch" => sub {
		$cm_obj->get_repo_obj($test_project_alias);
		is( $gr_mock->call_pos(1), 'run', 'GR->run method called' );
		is( $gr_mock->call_args_pos(1,2), 'fetch', 'GR->...(fetch, ...) method arg provided' );
	};

};

runtests unless caller;
