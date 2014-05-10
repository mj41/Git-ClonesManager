package Git::ClonesManager;

use strict;
use warnings;
use Carp qw(carp croak verbose);

use File::Spec;
use Git::Repository;
use File::HomeDir;

sub new {
	my ( $class, %args ) = @_;
	my $self = {};

	$self->{vl} = $args{vl} // 3;
	unless ( $args{data_path} ) {
		my $data_path_in_home = File::Spec->catdir(
			File::HomeDir->my_home, 'git-bare-repos'
		);
		unless ( -d $data_path_in_home ) {
			croak "Parameter 'data_path' not provided and default directory '$data_path_in_home' doesn't exist.\n";
		}
		$self->{data_path} = $data_path_in_home;
	} else {
		$self->{data_path} = $args{data_path};
	}

	croak "Data directory '$self->{data_path}' not found.\n"
		unless -d $self->{data_path};

	bless $self, $class;
}

sub validate_project_alias {
	my ( $self, $project_alias ) = @_;

	my $allowed = 'a-zA-Z0-9_\\-\\.';
	croak "Project alias '$project_alias' is not valid. Only $allowed allowed.\n"
		unless $project_alias =~ m/^[$allowed]+$/;
}

sub repo_data_path {
	my ( $self ) = @_;
	return File::Spec->catdir( $self->{data_path}, 'repos' );
}

sub project_alias_to_work_tree {
	my ( $self, $project_alias ) = @_;
	$self->validate_project_alias( $project_alias );
	my $work_tree = File::Spec->catdir( $self->repo_data_path, $project_alias );
}

sub create_work_tree {
	my ( $self, $work_tree ) = @_;

	my $repos_data_path = $self->repo_data_path();
	unless ( -d $repos_data_path ) {
		mkdir( $repos_data_path ) || croak "Can't create '$repos_data_path' directory: $!\n";
	}
	mkdir( $work_tree ) || croak "Can't create '$work_tree' directory: $!\n";
	return 1;
}

sub add_project {
	my ( $self, $project_alias, $repo_url ) = @_;

	my $work_tree = $self->project_alias_to_work_tree( $project_alias );
	croak "Project with alias '$project_alias' already exists." if -d $work_tree;

	print "Cloning '$repo_url' to '$work_tree'.\n" if $self->{vl} >= 3;
	$self->create_work_tree( $work_tree ) unless -d $work_tree;

	print "Running 'git clone ...' for '$project_alias'.\n" if $self->{vl} >= 3;
	my $output = Git::Repository->run(
		'clone','--mirror', $repo_url, $work_tree
	);
	print "'git clone ...' output: ".$output."\n" if $self->{vl} >= 7;
	return 1;
}

sub clone_or_update {
	my ( $self, $project_alias, $work_tree, %args ) = @_;
	$work_tree = $self->project_alias_to_work_tree( $project_alias ) unless $work_tree;

	if ( -d $work_tree ) {
		my $repo = Git::Repository->new( git_dir => $work_tree );

		if ( $args{skip_fetch} ) {
			print "Skipping 'git fetch ...' for '$project_alias'.\n" if $self->{vl} >= 4;
		} else {
			print "Running 'git fetch ...' for '$project_alias'.\n" if $self->{vl} >= 4;
			my $output = $repo->run( 'fetch', '--all' );
			print "'git fetch ...' output: ".$output."\n" if $self->{vl} >= 7;
		}

		return $repo;
	}

	$self->add_project( $project_alias, $args{repo_url} );
	return Git::Repository->new( git_dir => $work_tree );
}

# Parameters:
#   repo_url
#   skip_fetch
#
sub get_repo_obj {
	my ( $self, $project_alias, %args ) = @_;

	my $work_tree = $self->project_alias_to_work_tree( $project_alias );

	croak "Project with alias '$project_alias' not found (and no 'repo_url' provided).\n"
		if (not -d $work_tree) && !$args{repo_url};

	return $self->clone_or_update( $project_alias, $work_tree, %args );
}

1;
