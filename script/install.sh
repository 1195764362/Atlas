#!/bin/sh

if [ $# -lt 1 ] || [ "-h" = "$1" ] || [ "--help" = "$1" ]
then
	echo "�÷�: $0 HOST";
	echo "HOST : ��дҪ���ߵĻ���"
	exit 0;
fi

instance=ilike
svn="https://ipt.src.corp.qihoo.net/svn/atlas/trunk"
ssh_user=sync360
SSH="sudo -u $ssh_user ssh -c blowfish"
SCP="sudo -u $ssh_user scp -c blowfish"
DIR="/home/q/system/mysql-proxy"
BIN="$DIR/bin"
CNF="$DIR/conf"
LIB="$DIR/lib"
LOG="$DIR/log"
LUA="$LIB/mysql-proxy/lua"
PRY="$LUA/proxy"
CON="$PRY/conf"
PLG="$LIB/mysql-proxy/plugins"

#rm -rf trunk
#echo "SVN EXPORT��ʼ..."
#svn export $svn > /dev/null
#echo "SVN EXPORT����"
#cd trunk
#sh bootstrap.sh
#make

hosts=$*
for host in ${hosts}
do
	CNF_FILE="$instance.cnf"
	if test ! -s $CNF_FILE; then
		echo "���� δ�ҵ�$CNF_FILE"
		exit 1
	fi 

	CON_FILE="config_$instance.lua"
	if test ! -s $CON_FILE; then
		echo "���� δ�ҵ�$CON_FILE"
		exit 1
	fi 

	echo "=== ���ڽ�ѹ... ==="
	tar zxf proxy.tar.gz
	echo -e "=== ��ѹ��� ===\n"

	echo -e "=== ����Զ�̻����ϴ���Ŀ¼... ==="
	$SSH $host "mkdir -p $BIN" >/dev/null
	$SSH $host "mkdir -p $CNF" >/dev/null
	$SSH $host "mkdir -p $CON" >/dev/null
	$SSH $host "mkdir -p $PLG" >/dev/null
	$SSH $host "mkdir -p $LOG" >/dev/null
	echo -e "=== ����Ŀ¼��� ===\n"

	echo "=== ���ڸ����ļ�... ==="
	### confĿ¼ ###
	$SCP $CNF_FILE $host:$CNF
	$SSH $host "chmod 600 $CNF/$CNF_FILE"

	### configĿ¼ ###
	$SCP $CON_FILE $host:$CON

	cd trunk

	### binĿ¼ ###
	$SCP mysql-proxyd $host:$BIN

	### libĿ¼ ###
	$SCP *.so.* $host:$LIB
	$SCP liblua.so $host:$LIB
	rm -f liblua.so

	### pluginsĿ¼ ###
	$SCP lib*.so $host:$PLG
	rm -f lib*.so

	### luaĿ¼ ###
	$SCP *.so $host:$LUA
	$SCP admin.lua $host:$LUA
	$SCP rw-splitting.lua $host:$LUA
	rm -f admin.lua rw-splitting.lua

	### proxyĿ¼ ###
	$SCP *.lua $host:$PRY

	if $SSH $host "test -s $LOG/$instance.pid"; then
		$SSH $host $BIN/mysql-proxyd $instance stop >/dev/null 2>&1
	fi

	sleep 3s
	$SCP mysql-proxy $host:$BIN
	echo -e "=== �����ļ���� ===\n"

	$SSH $host $BIN/mysql-proxyd $instance start >/dev/null 2>&1 &
	echo -e "=== $host ���߳ɹ� ===\n"

	sleep 1s
	PID=`ps aux|grep "ssh -c blowfish $host $BIN/mysql-proxyd $instance start"|grep -v grep|awk '{print $2}'`
	sudo kill $PID 2>/dev/null

	cd ..
done

rm -rf trunk
echo -e "\n=== ���л���������� ===\n"
exit 0
