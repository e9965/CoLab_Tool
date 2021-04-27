#!/bin/bash
OLD_IFS=$IFS
IFS=$(echo -en "\n\b")
export Drive_basePath='/content/drive/MyDrive'
export Baidu_Cookie='/content/cookie'
export SUB_PASSWD_FILE='/content/sub_passwd'
export Unzip_option=${1}
    #Unzip_option=0 [解压] Unzip_option=1 [不解压]
export Unzip_thread=5
export Temp_Path='/conetnt/Temp' && [[ ! -d ${Temp_Path} ]] && mkdir -p ${Temp_Path}
#==================================================
SHOW_ERROR(){
    echo "[\033[41;37m ERROR \033[0m]:${1}" && exit 1
}
GET_NEW_VERSION(){
    export Baidu_Version=$(wget -qO - https://api.github.com/repos/qjfoidnh/BaiduPCS-Go/releases/latest|grep "tag_name"|cut -d"\"" -f4)
    [[ ${Baidu_Version} == "" ]] && SHOW_ERROR "获取BaiduPCS-Go最新版本错误"
    [[ ${Baidu_Version} == "v3.7.9" ]] && return 0 || return 1
}
DOWNLOAD_NEW_VERSION(){
    if [[ $1 == 1 ]]
    then
        wget -q https://github.com/qjfoidnh/BaiduPCS-Go/releases/download/${Baidu_Version}/BaiduPCS-Go-${Baidu_Version}-linux-amd64.zip
        if [[ -f ${Baidu_Version} ]]
        then
            unzip BaiduPCS-Go-${Baidu_Version}-linux-amd64.zip && mv BaiduPCS-Go-v3.7.9-linux-amd64/BaiduPCS-Go /bin/bd && chmod +rwx /bin/bd
            rm -rf BaiduPCS-Go-v3.7.9-linux-amd64*
        else
            SHOW_ERROR "获取BaiduPCS-Go错误"
        fi
    else
        cp -rf ${Drive_basePath}/ToolBox/bd /bin/bd && chmod +rwx /bin/bd
    fi
}
DOWN_BAIDU_PCS_GO(){
    GET_NEW_VERSION
    DOWNLOAD_NEW_VERSION $?
    #RETURN 1:Required Update
    #RETURN 0:Does not require
}
RUN_BD_CODE(){
    if [[ $(${1} | grep -oE "错误") == "" ]]
    then
        return 0
    else
        return 1
    fi
    #0：成功 1：错误
}
LOGIN_BAIDU_PCS_GO(){
    [[ ! -f ${Baidu_Cookie} ]] && SHOW_ERROR "找不到Cookie文件。"
    while true
    do
        RUN_BD_CODE "bd login --cookies=\"$(cat ${Baidu_Cookie})\""
        if [[ $? == 1 ]] 
        then
            echo -ne "百度云登录失败，请临时输入新Cookies:"
            read TEMP_COOKIES
            echo ${TEMP_COOKIES} > ${Baidu_Cookie}
        else
            break
        fi
    done
}
CONFIG_BAIDU_PCS_GO(){
    #BEGIN CHECK_COOKIE
    [[ -f ${Baidu_Cookie} ]] && SHOW_ERROR "找不到百度CookieFile"
    #END CHECK_COOKIE
    LOGIN_BAIDU_PCS_GO
    bd config set --max_parallel 20
    bd config set --max_download_load 2
    bd config set --cache_size 256KB
    bd config set --savedir="${Temp_Path}"
    bd mkdir /COLAB
    while true
    do
        RUN_BD_CODE "bd cd /COLAB"
        if [[ $? == 1 ]]
        then
            echo "百度云更换目录失败。5秒后重试"
            sleep 5s
        else
            break
        fi
    done
}
INITIAL_BAIDU_PCS_GO(){
    if [[ ! -f /bin/bd ]]
    then
        DOWN_BAIDU_PCS_GO
        CONFIG_BAIDU_PCS_GO
    fi
}
PARALLEL(){
    #并行解压
    Thread=${1}  # 定义最大线程数
    tmp_fifofile="/tmp/$$.fifo"
    mkfifo $tmp_fifofile   # 新建一个FIFO类型的文件
    exec 4<>$tmp_fifofile  # 将FD6指向FIFO类型
    rm $tmp_fifofile  #删也可以，
    for ((i=0;i<${Thread};i++));do
        echo
    done >&4
    #在fd4中放置了$thread_num个回车符
}
GET_UNZIP_PASSWD_FILE(){
    wget -qO /content/passwd https://raw.githubusercontent.com/e9965/CoLab_Tool/main/passwd.conf || SHOW_ERROR "无法获取Password文件"
    [[ -f ${SUB_PASSWD_FILE} ]] && export PASSWD=($(cat ${PASSWD_FILE}) $(cat ${SUB_PASSWD_FILE})) || export PASSWD=($(cat ${PASSWD_FILE}))
}
TRANSFER_FILE(){
    for i in $(cat /content/share_link)
    do
        bd transfer --fix ${i}
    done
}
GET_BAIDU_FILE_LIST(){
    export filetxt=/content/Baidu_File.tmp
    while true
    do
        bd match /COLAB/* > ${filetxt}
        if [[ $(grep -oE "错误" ${filetxt} ) == "" ]]
        then
            break
        else
            echo "读取文件列表错误，正在重新读取"
            sleep 5s
        fi
    done
}
DOWN_BAIDU_FILE(){
    fileno=$(wc -l ${filetxt}) && fileno=${fileno%%\ *}
    while [[ ${fileno} > 0 ]]
    do
        dummy=`expr ${fileno} - 1 `
        file[${dummy}]=$(tail -${fileno} ${filetxt}|head -1)
        echo -e "${green}${file[${dummy}]}${plain}"
        fileno=`expr ${fileno} - 1 `
    done
    fileno=${file[@]}
    echo -e -n "即將下載以上文件 | 按下 <Enter> 進行確認:"
    read -n 1
    rm -f ${filetxt}
    PARALLEL 10
    for i in ${file[*]}
    do
        read -u4
        {
            bd download --ow --status --retry 10 --nocheck ${i}
            echo >&4
        }&
    done
    wait && exec 4>&-
    bd rm /COLAB && wait
}
DOWNLOAD_FILE(){
    TRANSFER_FILE
    DOWN_BAIDU_FILE
}
RSYNC_MOVE(){
    rsync -r --info=progress2 -a --remove-source-files ${Temp_Path} ${Drive_basePath}
}
UNZIP_INI(){
    [[ ! -d ${TEMP_UNZIP_PATH} ]] && mkdir -p ${TEMP_UNZIP_PATH}
    wait && >& ${TEMP_FILE_LIST}
    FIND_UNZIP_FILE
}
FIND_UNZIP_FILE(){
    PARALLEL 256
    for i in $(find ${INPUT_DIR} -type f -name "*" )
    do
        read -u4
        {
            CHECK_ARC $i
            [[ $? == 1 ]] && echo "$i" >> ${TEMP_FILE_LIST}
            echo >&4
        }&
    done
    wait && exec 4>&-
}
ARC_ARRAY(){
    FILE_NUM=0
    DUMMY="."
    for i in $(cat ${TEMP_FILE_LIST}| sort -n)
    do
        if [[ ${DUMMY%%.*} != ${i%%.*} ]]
        then
            FILE_LIST[${FILE_NUM}]=${i}
            DUMMY=${i}
            let "FILE_NUM++"
        fi
    done
    export UNZIP_ARRAY=(${FILE_LIST[@]})
}
TRY_PASS_UNZIP(){
    PARALLEL ${Unzip_thread} && wait
    for i in ${UNZIP_ARRAY[@]}
    do
        read -u4
        {
            while true
            do
                for TRY_PASS in ${PASSWD[@]}
                do
                    7z x -y -r -bsp1 -bso0 -bse0 -aot -p${TRY_PASS} -o${TEMP_UNZIP_PATH}$(echo -ne ${i//${TEMP_UNZIP_PATH}/} | grep -oE "[^\.]+"|head -1)_Dir ${i}
                    if [[ ! $? == 2 ]] ; then break ; fi
                done
            done
            rm -rf ${i%%\.*}.*
            echo >&4
        }&
    done
    wait && exec 4>&-
}
PROCESS_UNZIP(){
    if [[ ${Unzip_option} == 0 ]]
    then
        clear && echo "准备开始解压"
        export INPUT_DIR=${Temp_Path}
        export TEMP_UNZIP_PATH=${Temp_Path}
        export TEMP_FILE_LIST="${Temp_Path}/$$"
        while true
        do
            UNZIP_INI
            ARC_ARRAY
            [[ ${#UNZIP_ARRAY[@]} > 0 ]] && TRY_PASS_UNZIP || break
            unset UNZIP_ARRAY
        done
    fi
}
CHECK_ARC(){
	FILE_NAME=${1}
	checkarc=$(file -b ${FILE_NAME}) && checkarc=${checkarc%%\ *}
	case ${checkarc} in
		RAR|rar|Rar|7-zip|7-Zip|7-Z|7-z|7z|7Z|7-ZIP|Zip|ZIP)
		return 1
			;;
		*)
		if [[ ( ${FILE_NAME##*.} == "7z" ) || ( ${FILE_NAME##*.} == "zip" ) || ( ${FILE_NAME##*.} == "rar" ) ]]
		then
			return 1
		else
			return 0
		fi
			;;
	esac
}
#===================================================
main(){
    clear && echo "正在初始化Baidu-PCS-Go"
    INITIAL_BAIDU_PCS_GO
    clear && echo "正在初始化密码文档"
    GET_UNZIP_PASSWD_FILE
    clear && echo "准备下载文档"
    DOWNLOAD_FILE
    PROCESS_UNZIP
    clear && echo "准备开始传回Google Drive"
    RSYNC_MOVE
    exit 0
}
#===================================================
main
IFS=$OLD_IFS