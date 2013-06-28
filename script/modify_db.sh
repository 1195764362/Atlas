#!/bin/sh

#1. �������
if [ $# -lt 4 ] || [ "-h" = "$1" ] || [ "--help" = "$1" ]
then
	echo "�÷�: $0 add|remove rw|ro IP:PORT HOST"
	exit 0
fi

#2. �����û�����Ŀ¼
instance=ilike
svn="https://ipt.src.corp.qihoo.net/svn/atlas/trunk"
ssh_user=sync360
SSH="sudo -u $ssh_user ssh -c blowfish"
SCP="sudo -u $ssh_user scp -c blowfish"
DIR="/home/q/system/mysql-proxy"
BIN="$DIR/bin"
CNF="$DIR/conf"
LOG="$DIR/log"
OLDCNF="$instance.cnf"
NEWCNF="$instance.cnf.new"
BAKCNF="$instance.cnf.bak"
declare -i op=0
type=""

function check_param()
{
	if [ "$1" == "add" ] || [ "$1" == "ADD" ]; then
		#����DB
		op=1
	elif [ "$1" == "remove" ] || [ "$1" == "REMOVE" ]; then
		#����DB
		op=2
	else
		echo "����δ֪����"
		exit 1
	fi

	if [ "$2" == "rw" ] || [ "$2" == "RW" ]; then
		type="proxy-backend-addresses"
	elif [ "$2" == "ro" ] || [ "$2" == "RO" ]; then
		type="proxy-read-only-backend-addresses"
	else
		echo "����δ֪DB����"
		exit 2
	fi

	echo $3 | egrep "^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+$" > /dev/null
	if [ "$?" != "0" ]; then
		echo "���󣺷Ƿ���IP�Ͷ˿�"
		exit 3
	fi
}

function get_cnf()
{
	rm -f $instance.cnf
	$SCP $host:$CNF/$OLDCNF . > /dev/null
	sudo chown `whoami`:`whoami` $OLDCNF
}

function set_cnf()
{
	grep $type $OLDCNF | grep -v \# > /dev/null
	if [ "$?" == "0" ]; then	#�ҵ���Ӧ��ǩ
			num=`grep -n $type $OLDCNF | grep -v \# | cut -d':' -f1`
			dbs=`grep -n $type $OLDCNF | grep -v \# | cut -d':' -f2`
			rm -f $NEWCNF
			declare -i no=1
			while read line
			do
				if [ $no -ne $num ]; then	#ԭ������
					echo $line >> $NEWCNF
				elif [ $op -eq 1 ]; then	#����DB
					echo $line | grep "= *$" > /dev/null
					if [ "$?" != "0" ]; then
						echo "$line, $1" >> $NEWCNF
					else
						echo "$line $1" >> $NEWCNF
					fi
				else						#����DB
					echo $line | grep $1 > /dev/null
					if [ "$?" != "0" ]; then
						echo "����$OLDCNF��û��ָ����DB"
						exit 4
					fi

					echo $line | grep "= *$1" > /dev/null
					if [ "$?" == "0" ]; then	#��һ̨DB
						newline=`echo $line | sed "s/$1 *,\?//"`
					else
						newline=`echo $line | sed "s/, *$1//"`
					fi

					echo $newline | grep "= *$" > /dev/null
					if [ "$?" != "0" ]; then
						echo $newline >> $NEWCNF
					fi
				fi
				no=no+1
			done < $OLDCNF
	else						#δ�ҵ���Ӧ��ǩ
		if [ $op -eq 1 ]; then	#����DB
			while read line
			do
				echo $line >> $NEWCNF
			done < $OLDCNF
			echo "$type = $1" >> $NEWCNF 
		else					#����DB
			echo "����$OLDCNF��û��ָ����DB"
			exit 4
		fi
	fi
}

function send_cnf()
{
	$SSH $host cp $CNF/$OLDCNF $CNF/$BAKCNF			#����ԭ�����ļ�
	$SCP $NEWCNF $host:$CNF/$OLDCNF	> /dev/null		#�ϴ��������ļ�
}

function set_proxy()
{
	if $SSH $host "test -s $LOG/$instance.pid"; then
		$SSH $host $BIN/mysql-proxyd $instance stop >/dev/null 2>&1
	fi
	sleep 3s
	$SSH $host $BIN/mysql-proxyd $instance start >/dev/null 2>&1 &
}

function clean()
{
	sleep 1s
	PID=`ps aux|grep "ssh -c blowfish $host $BIN/mysql-proxyd $instance start"|grep -v grep|awk '{print $2}'`
	sudo kill $PID 2>/dev/null
	rm -f $OLDCNF $NEWCNF
}

check_param $*
chmod 777 `pwd`

hosts=$*
declare -i index=1
for host in ${hosts}
do
	if [ $index -lt 4 ]; then
		index=index+1
		continue
	fi

	get_cnf
	set_cnf $3
	send_cnf
	set_proxy
	clean

	echo -e "=== $host �޸�DB�ɹ� ===\n"
done

chmod 755 `pwd`
echo -e "\n=== ���л����޸�DB��� ===\n"
exit 0
