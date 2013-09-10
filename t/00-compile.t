use strict;
use warnings;

# this test was generated with Dist::Zilla::Plugin::Test::Compile 2.027
# XXX temporarily using a modified version to handle recommended deps

use Test::More;

my @module_files = (
    'Prophet.pm',
    'Prophet/App.pm',
    'Prophet/CLI.pm',
    'Prophet/CLI/CollectionCommand.pm',
    'Prophet/CLI/Command.pm',
    'Prophet/CLI/Command/Aliases.pm',
    'Prophet/CLI/Command/Clone.pm',
    'Prophet/CLI/Command/Config.pm',
    'Prophet/CLI/Command/Create.pm',
    'Prophet/CLI/Command/Delete.pm',
    'Prophet/CLI/Command/Export.pm',
    'Prophet/CLI/Command/History.pm',
    'Prophet/CLI/Command/Info.pm',
    'Prophet/CLI/Command/Init.pm',
    'Prophet/CLI/Command/Log.pm',
    'Prophet/CLI/Command/Merge.pm',
    'Prophet/CLI/Command/Mirror.pm',
    'Prophet/CLI/Command/Publish.pm',
    'Prophet/CLI/Command/Pull.pm',
    'Prophet/CLI/Command/Push.pm',
    'Prophet/CLI/Command/Search.pm',
    'Prophet/CLI/Command/Settings.pm',
    'Prophet/CLI/Command/Shell.pm',
    'Prophet/CLI/Command/Show.pm',
    'Prophet/CLI/Command/Update.pm',
    'Prophet/CLI/Dispatcher.pm',
    'Prophet/CLI/Dispatcher/Rule.pm',
    'Prophet/CLI/Dispatcher/Rule/RecordId.pm',
    'Prophet/CLI/MirrorCommand.pm',
    'Prophet/CLI/Parameters.pm',
    'Prophet/CLI/ProgressBar.pm',
    'Prophet/CLI/PublishCommand.pm',
    'Prophet/CLI/RecordCommand.pm',
    'Prophet/CLI/TextEditorCommand.pm',
    'Prophet/CLIContext.pm',
    'Prophet/Change.pm',
    'Prophet/ChangeSet.pm',
    'Prophet/Collection.pm',
    'Prophet/Config.pm',
    'Prophet/Conflict.pm',
    'Prophet/ConflictingChange.pm',
    'Prophet/ConflictingPropChange.pm',
    'Prophet/ContentAddressedStore.pm',
    'Prophet/DatabaseSetting.pm',
    'Prophet/FilesystemReplica.pm',
    'Prophet/ForeignReplica.pm',
    'Prophet/Meta/Types.pm',
    'Prophet/PropChange.pm',
    'Prophet/Record.pm',
    'Prophet/Replica.pm',
    'Prophet/Replica/FS/Backend/File.pm',
    'Prophet/Replica/FS/Backend/LWP.pm',
    'Prophet/Replica/FS/Backend/SSH.pm',
    'Prophet/Replica/file.pm',
    'Prophet/Replica/http.pm',
    'Prophet/Replica/prophet.pm',
    'Prophet/Replica/prophet_cache.pm',
    'Prophet/Replica/sqlite.pm',
    'Prophet/ReplicaExporter.pm',
    'Prophet/ReplicaFeedExporter.pm',
    'Prophet/Resolver.pm',
    'Prophet/Resolver/AlwaysSource.pm',
    'Prophet/Resolver/AlwaysTarget.pm',
    'Prophet/Resolver/Failed.pm',
    'Prophet/Resolver/Fixup/MissingSourceOldValues.pm',
    'Prophet/Resolver/FromResolutionDB.pm',
    'Prophet/Resolver/IdenticalChanges.pm',
    'Prophet/Resolver/Prompt.pm',
    'Prophet/Test.pm',
    'Prophet/Test/Arena.pm',
    'Prophet/Test/Editor.pm',
    'Prophet/Test/Participant.pm',
    'Prophet/UUIDGenerator.pm',
    'Prophet/Util.pm',
    'Prophet/Web/Field.pm',
    'Prophet/Web/FunctionResult.pm',
    'Prophet/Web/Menu.pm',
    'Prophet/Web/Result.pm'
);

eval { require Template::Declare };
if ( !defined $@ ) {
    push @module_files, qw{
      Prophet/Server.pm
      Prophet/Server/Controller.pm
      Prophet/Server/Dispatcher.pm
      Prophet/Server/View.pm
      Prophet/Server/ViewHelpers.pm
      Prophet/Server/ViewHelpers/Function.pm
      Prophet/Server/ViewHelpers/HiddenParam.pm
      Prophet/Server/ViewHelpers/ParamFromFunction.pm
      Prophet/Server/ViewHelpers/Widget.pm
    };
}

eval { require HTTP::Server::Simple::CGI };
if ( !defined $@ ) {
    push @module_files, 'Prophet/CLI/Command/Server.pm';
}

my @scripts = ('bin/prophet');

# no fake home requested

use IPC::Open3;
use IO::Handle;

my @warnings;
for my $lib (@module_files) {

    # see L<perlfaq8/How can I capture STDERR from an external command?>
    my $stdin  = '';                # converted to a gensym by open3
    my $stderr = IO::Handle->new;
    binmode $stderr, ':crlf' if $^O eq 'MSWin32';

    my $pid =
      open3( $stdin, '>&STDERR', $stderr, qq{$^X -Mblib -e"require q[$lib]"} );
    waitpid( $pid, 0 );
    is( $? >> 8, 0, "$lib loaded ok" );

    if ( my @_warnings = <$stderr> ) {
        warn @_warnings;
        push @warnings, @_warnings;
    }
}

use File::Spec;
foreach my $file (@scripts) {
  SKIP: {
        open my $fh, '<', $file or warn("Unable to open $file: $!"), next;
        my $line = <$fh>;
        close $fh and skip( "$file isn't perl", 1 )
          unless $line =~ /^#!.*?\bperl\b\s*(.*)$/;

        my $flags = $1;

        my $stdin  = '';                # converted to a gensym by open3
        my $stderr = IO::Handle->new;
        binmode $stderr, ':crlf' if $^O eq 'MSWin32';

        my $pid =
          open3( $stdin, '>&STDERR', $stderr, qq{$^X -Mblib $flags -c $file} );
        waitpid( $pid, 0 );
        is( $? >> 8, 0, "$file compiled ok" );

        # in older perls, -c output is simply the file portion of the path being tested
        if (
            my @_warnings = grep { !/\bsyntax OK$/ }
            grep { chomp; $_ ne ( File::Spec->splitpath($file) )[2] }
            <$stderr>
          )
        {
            # temporary measure - win32 newline issues?
            warn map { _show_whitespace($_) } @_warnings;
            push @warnings, @_warnings;
        }
    }
}

sub _show_whitespace {
    my $string = shift;
    $string =~ s/\012/[\\012]/g;
    $string =~ s/\015/[\\015]/g;
    $string =~ s/\t/[\\t]/g;
    $string =~ s/ /[\\s]/g;
    return $string;
}

is( scalar(@warnings), 0, 'no warnings found' ) if $ENV{AUTHOR_TESTING};
done_testing;

