export Drive_basePath='/content/drive/MyDrive'
export Baidu_Cookie='/content/cookie'
export Unzip_option=0
    #Unzip_option=0 [不解压] Unzip_option=1 [解压]
export Unzip_thread=5
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
#===================================================
DOWN_BAIDU_PCS_GO(){
    GET_NEW_VERSION
    DOWNLOAD_NEW_VERSION $?
    #RETURN 1:Required Update
    #RETURN 0:Does not require
}
CONFIG_BAIDU_PCS_GO(){
    #BEGIN CHECK_COOKIE
    [[ -f ${Baidu_Cookie} ]] && SHOW_ERROR "找不到百度CookieFile"
    #END CHECK_COOKIE
    LOGIN_BAIDU_PCS_GO
}
INITIAL_BAIDU_PCS_GO(){
    DOWN_BAIDU_PCS_GO
    CONFIG_BAIDU_PCS_GO
}
PARALLEL(){
    #并行解压
    Thread=${1}  # 定义最大线程数
    tmp_fifofile="/tmp/$$.fifo"
    mkfifo $tmp_fifofile   # 新建一个FIFO类型的文件
    exec 6<>$tmp_fifofile  # 将FD6指向FIFO类型
    rm $tmp_fifofile  #删也可以，
    for ((i=0;i<${Thread};i++));do
        echo
    done >&6
    #在fd6中放置了$thread_num个回车符
}
GET_UNZIP_PASSWD_FILE(){
    wget -qO /content/passwd 
}
#===================================================
main(){
    INITIAL_BAIDU_PCS_GO
    GET_UNZIP_PASSWD_FILE
    DOWNLOAD_FILE
    UNZIP_FILE
    RSYNC_MOVE
    exit 0
}
#===================================================