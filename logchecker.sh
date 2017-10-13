#!/bin/sh
# 検出対象ログファイル
#TARGET_LOG="/var/log/messages"
#TARGET_LOG="SystemOut_17.09.26_07.33.24.log"
TARGET_LOG="SystemOut.log"

TODAY=`date "+%Y%m%d%H%M%S"`
T="+%Y/%m/%d %H:%M:%S"

# 検出文字列
_error_conditions="ハング"

# 稼動環境の確認
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

if [ OS == 'Linux' ]; then
	_process=`basename $0`
	_pcnt=`pgrep -fo ${_process} | wc -l`
	if [ ${_pcnt} -gt 1 ]; then
  		echo "This script has been running now. proc : ${_pcnt}"
  		exit 1
	fi
fi

# ログファイルを監視する関数
hit_action() {
	while read i
	do
		echo $i | grep -q "${_error_conditions}"
		if [ $? = "0" ];then
			# アクション
			#touch /tmp/hogedetayo
			logger "アクション:"
			sendmail_action
		fi
	done
}

#
sendmail_action() {
	logger "START:sendmail_action"
	logger "  MAIL TO:{}"
	logger "END  :sendmail_action"
}
logger(){
	echo `date "${T}"` $1
}
# main
if [ ! -f ${TARGET_LOG} ]; then
    touch ${TARGET_LOG}
fi
# -n 0            : 末尾から表示する行を0行に、標準出力にしないよう
# -f              : ログローテートされた場合 log.log→ローテート→log.log.2000-10-10 を参照する
# -F              :  same as --follow=name --retry
# --follow=name   : 末尾追加のファイルなので、最終部分の文字を読み続ける(-fと同じ）
#                 : name 指定でファイル削除（やリネーム）時の追跡方法がファイルネーム
# --retry         : ファイルがなくなったことを検知したら再オープンを成功するまで繰り返す
tail -n 0 --follow=name --retry $TARGET_LOG | hit_action
