#!/bin/sh
set -e
# --------------------------------------------------------------------------------------------------
# システム名    ：
# サブシステム名：
# ファイル名    ：logchecker.sh 
#
# 概要説明      ：
# --------------------------------------------------------------------------------------------------
# 変更履歴：
# 改定                         変更理由                                               担当者
# 番号  変更日     バージョン  案件/問題   変更内容                                   氏名
# --------------------------------------------------------------------------------------------------
# 001   2017-10-13 ver.1.0.0   INS06202    初版                                       橋本 英雄
# --------------------------------------------------------------------------------------------------
# ===================================================
# 環境設定
# ===================================================
TODAY=`date "+%Y%m%d%H%M%S"`
T="+%Y/%m/%d %H:%M:%S"
# ===================================================
# 検出対象ログファイル
# ===================================================
TARGET_LOG_PATH="/opt/ap/IBM/WebSphere/AppServer/profiles/AppSrv01/logs/server1/"
TARGET_LOG_FILE="SystemOut.log"
TARGET_LOG="${TARGET_LOG_PATH}${TARGET_LOG_FILE}"

LOGWATCH_LOG_PATH="$(dirname $0)/"
LOGWATCH_LOG_FILE="${LOGWATCH_LOG_PATH}${TODAY}_$(basename ${0} .sh ).log"
# ===================================================
# JENKINS設定
# ===================================================
JENKINS_HOST=SYSAP001.sthdg.local
JENKINS_PORT=8083
JENKINS_JOBID=logwatch_stwas03
JENKINS_TOKEN=BUILD_TOKEN
# ===================================================
# 検出文字列
# ===================================================
_error_conditions="ハング"
#_error_conditions="Gx0301Action"
#_error_conditions="SRVE0242I"
# --------------------------------------------------------------------------------------------------
# ログ処理
# --------------------------------------------------------------------------------------------------
logger(){
	echo `date "${T}"` $1 | tee -a ${LOGWATCH_LOG_FILE}
}
# --------------------------------------------------------------------------------------------------
# トラップ処理
# --------------------------------------------------------------------------------------------------
trap_action(){
	status=$?
	logger "INFO : TRAP [$status]"
	exit $status
}
# --------------------------------------------------------------------------------------------------
# usage
# --------------------------------------------------------------------------------------------------
usage() {
	cat <<EOF
USAGE
    $(basename ${0}) <command>
      <command>
          run  : ファイル監視を開始します。
          mail : ログ監視して検知したときのメール送信処理だけ実施します（テスト用）
終了はCTRL+C または ps fxl として得られたtailコマンドのプロセスをKILLします
例）
$ ps fxl
F   UID   PID  PPID PRI  NI    VSZ   RSS WCHAN  STAT TTY        TIME COMMAND
5  1002  3360  3358  20   0  98296  1700 poll_s S    ?          0:04 sshd: hashimoto@pts/0
0  1002  3361  3360  20   0  14532  2080 wait   Ss   pts/0      0:00  \_ -bash
0  1002 14929  3361  20   0  12156  1416 wait   S    pts/0      0:00      \_ /bin/sh ./logcheck/logchecker.sh run
0  1002 14951 14929  20   0   7036   620 inotif S    pts/0      0:00      |   \_ tail -n 0 --follow=name --retry /opt/ap/IBM
1  1002 14952 14929  20   0  12156   608 pipe_w S    pts/0      0:00      |   \_ /bin/sh ./logcheck/logchecker.sh run
0  1002 14960  3361  20   0  34204  5932 poll_s S+   pts/0      0:00      \_ vim logcheck/logchecker.sh

$ kill -2 14951
EOF
}
# ===================================================
# 稼動環境の確認
# ===================================================
if [ "$(uname)" == 'Darwin' ]; then
	OS='Mac'
elif [ "$(expr substr $(uname -s) 1 5)" == 'Linux' ]; then
	OS='Linux'
elif [ "$(expr substr $(uname -s) 1 10)" == 'MINGW32_NT' ]; then
	OS='Cygwin'
else
	echo "Your platform ($(uname -a)) is not supported."
	exit 1
fi
# ===================================================
# 2重起動防止
# ===================================================
if [ ${OS} == 'Linux' ]; then
	_process=`basename $0`
	_pcnt=`pgrep -fo ${_process} | wc -l`
	if [ ${_pcnt} -gt 1 ]; then
  		echo "This script has been running now. proc : ${_pcnt}"
  		exit 1
	fi
fi
# --------------------------------------------------------------------------------------------------
# ログファイルを監視する処理
# --------------------------------------------------------------------------------------------------
hit_action() {
	logger "INFO : START [hit_actiona][BASHPID=$BASHPID][PPID=$PPID][PID=$$]"

	while read i
	do
		echo $i | grep -q "${_error_conditions}"
		if [ $? = "0" ];then
			# アクション
			logger "INFO : 検知: ${i}"
			sendmail_action
		fi
	done
	logger "INFO : END   [hit_action][RC=$?]"
}
# --------------------------------------------------------------------------------------------------
# メール送信処理
# --------------------------------------------------------------------------------------------------
# --------------------------------------------------------------------------------------------------
sendmail_action() {
	logger "INFO : START [sendmail_action]"
	JENKINS_HOST=SYSAP001.sthdg.local
	JENKINS_PORT=8083
	JENKINS_JOBID=logwatch_stwas03
	JENKINS_TOKEN=BUILD_TOKEN
	wget -q -O /dev/null --spider http://$JENKINS_HOST:$JENKINS_PORT/job/$JENKINS_JOBID/build?token=$JENKINS_TOKEN
	logger "INFO : END   [sendmail_action][RC=$?]"
}
# --------------------------------------------------------------------------------------------------
# -n 0            : 末尾から表示する行を0行に、標準出力にしないよう
# -f              : ログローテートされた場合 log.log→ローテート→log.log.2000-10-10 を参照する
# -F              :  same as --follow=name --retry
# --follow=name   : 末尾追加のファイルなので、最終部分の文字を読み続ける(-fと同じ）
#                 : name 指定でファイル削除（やリネーム）時の追跡方法がファイルネーム
# --retry         : ファイルがなくなったことを検知したら再オープンを成功するまで繰り返す
# --------------------------------------------------------------------------------------------------
Running() {
	#logger "INFO : ${TARGET_LOG_PATH}"
	#logger "INFO : ${TARGET_LOG_FILE}"
	#logger "INFO : PID      = $$"
	logger "INFO : 監視ログ = ${TARGET_LOG}"
	#logger "INFO : ${LOGWATCH_LOG_PATH}"
	#logger "INFO : ${LOGWATCH_LOG_FILE}"
	logger "INGO : 監視文字 = ${_error_conditions}"

	#トラップ対応
	#trap 'trap_action' {1,2,3,15}
	#ファイル検知
	tail -n 0 --follow=name --retry $TARGET_LOG | hit_action
}

case $1 in
	"")
	usage
	exit 8
	;;
	"run")
	Running
	;;
	"mail")
	sendmail_action
	;;
	*)
	usage
	exit 8
	;;
esac

