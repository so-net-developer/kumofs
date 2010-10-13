#!/usr/bin/perl

use strict;
use warnings;
use Net::FTP;
use Cache::Memcached::Fast;

########################
# ローカルに取得したtchファイルを削除する
my $DEL_LOCAL = 1; #( 1: 削除 0: 残す)
# サーバのバックアップファイルを削除する
my $DEL_REMOTE = 1; #( 1: 削除 0: 残す)
# バックアップファイル作成待ち時間(秒)
my $SLEEP = 300;
# kumofs FTPユーザID
my $USERNAME = 'user';
# kumofs FTPパスワード
my $PASSWORD = 'password';
# kumofs データストアディレクトリ
my $REMOTE_DIR ="/var/kumofs";
# ローカルバックアップファイル
my $BACKUP_FILE;
########################

my $REMOTE_FILE;


if ( @ARGV < 2 ){
	print "使い方: kumo-backup.pl kumofs-manager-hostname backupfilename\n";
	exit;
}

$BACKUP_FILE = $ARGV[1];

if ( -e $BACKUP_FILE ) {
	print "すでに$BACKUP_FILEが存在します。\n";
	exit;
}


my $MANAGER = $ARGV[0];

my $kumo_sts = `LD_LIBRARY_PATH=/usr/local/lib kumoctl $MANAGER status`;

my @lines = split("\n",$kumo_sts);

my @HOSTS;

foreach( @lines ){
	if (/fault/){
		print "fault状態のサーバがあります。\n";
		exit;
	}
	if (/active/){
		my @sts = split(':', $_);
		$sts[0] =~ s/^\s*(.*?)\s*$/$1/;
		unshift @HOSTS, $sts[0];
	}
} 

print "======== バックアップ開始 ========\n";
$kumo_sts = system("LD_LIBRARY_PATH=/usr/local/lib kumoctl $MANAGER backup bak");

# バックアップファイル作成待ちスリープ
sleep($SLEEP);

print "======== バックアップ終了 ========\n";

my $LOCAL_FILE;

print "======== FTP開始 ========\n";
my $host;
my $file;

foreach $host (@HOSTS) {
	$LOCAL_FILE = "database.$host.tch";
	print "$host 接続\n";
	my $ftp = Net::FTP->new( $host, Passive => 1) or warn("Connected Error!:$host");
	$ftp->login($USERNAME, $PASSWORD) or die $ftp->message;
	my @files = $ftp->ls($REMOTE_DIR);
	foreach $file (@files) {
		if ( $file =~ /-bak/ ){
			$REMOTE_FILE = $file;
			last;
		}
	}
	print "$REMOTE_FILE ";
	$ftp->binary;
	$ftp->get($REMOTE_FILE, $LOCAL_FILE) or warn $ftp->message;
	if ( $DEL_REMOTE ) {
		$ftp->delete($REMOTE_FILE) or warn $ftp->message;
	} 
	$ftp->quit;
	my $size = -s $LOCAL_FILE;
	1 while $size =~ s/(.*\d)(\d\d\d)/$1,$2/;
	print "... $size bytes取得\n";
}
print "======== FTP終了 ========\n";

my $merge_cmd = "LD_LIBRARY_PATH=/usr/local/lib kumomergedb $BACKUP_FILE";

foreach (@HOSTS) {
	$LOCAL_FILE = "database.$_.tch";
	$merge_cmd = $merge_cmd . " " . $LOCAL_FILE;
}

print "======== マージ開始 ========\n";
print "$merge_cmd\n";
$kumo_sts= system($merge_cmd);
print "======== マージ終了 ========\n";


if ( $DEL_LOCAL ){
	foreach $host (@HOSTS) {
		$LOCAL_FILE = "database.$host.tch";
		unlink( $LOCAL_FILE ) or warn("削除エラー:$LOCAL_FILE\n");
	}
}

print "バックアップファイル:$BACKUP_FILEを作成しました。\n"
