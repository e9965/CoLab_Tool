export IFS=$(echo -ne "\n\b")
readonly green="\033[42;37m"
readonly plain="\033[0m"
readonly red="\033[41;37m"
readonly yellow="\033[43;37m"
readonly base="/content/drive/MyDrive/ACGUC"
readonly line="======================================================"
readonly tempDownPath="/content/ACGUC"
#==================================
function check_Cookie(){
    echo -e "${yellow}[INFO]${plain}正在检查Cookie的有效性"
    [[ -f ${base}/.cookies ]] || return 2
    export KEY=$(cat ${base}/.cookies)
    [[ $(curl -s -L --retry 5 --cookie "${KEY}" "https://www.ummoe.com/vip%e4%b8%93%e7%94%a8%e4%ba%a4%e6%b5%81%e7%be%a4/" | grep -oE "erphp-login-must") == "" ]] || return 2
}

function int(){
    check_Cookie || check_State
    create_Temp downList.acg
    set_Temp
    if [[ -d ${tempDownPath} ]]
    then
        rm -rf ${tempDownPath}/*
    else
        mkdir ${tempDownPath}
    fi
}

function set_Temp(){
    create_Temp currentPage.acg
    create_Temp currentData.acg
}

function store_Target(){
    local i
    local j
    local title
    local dataNum
    local tempFileName
    title=$(grep -oE "<title>.+</title>" currentPage.acg | sed -E "s/&#8211\;.+|<title>|<\/title>//g")
    currentDir=${tempDownPath}/${title}
    mkdir ${currentDir}
    grep -oE "inn-singular__post__body__content inn-content-reseter.+inn-singular__post__toolbar" currentPage.acg \
    | grep -oE "https://[^\"]+" | cut -d"=" -f3 | tr -s '\n' |uniq > currentData.acg
    dataNum=$(wc -l currentData.acg)
    i=1
    for j in $(cat currentData.acg)
    do
        mkdir ${tempDownPath}/${title}
        tempFileName=${j##*/}
        tempFileType=${tempFileName##*\.}
        echo -e "${yellow}[INFO]${plain}下载中【${i}/${dataNum}】"
        curl -sL --retry 5 --cookie "${KEY}" "${j}" -o "${currentDir}/${i}.${tempFileType}" 
        let "i++"
    done
    echo -e "${green}[FINISH]${plain}【${title}】已完成下载"
}

function check_State(){
    echo -en "${red}[WARNING]${plain}请查看相关错误信息并解决。按Enter退出软件。" && read && exit
}

function create_Temp(){
    if [[ -f ${1} ]]
    then
        >& ${1}
    else
        touch ${1}
    fi
}

function show_Target(){
    echo -e "${yellow}[INFO]${plain}正在检查相关下载源文件链接"
    [[ ! -f downList.acg ]] && check_State
    [[ $(cat downList.acg) == "" ]] || echo -e "${yellow}[INFO]${plain}没有读取到相关下载链接" && check_State
    echo -e "${yellow}[INFO]${plain}即将下载以下链接："
    local i
    for i in $(cat downList.acg)
    do
        echo 【${i}】
    done
    echo ${line}
    echo -ne "${green}[INPUT]${plain}请按下Enter以继续：" && read && echo ${line}
}

function down_Target(){
    local i
    for i in $(cat downList.acg)
    do
        curl -sL --retry 5 --cookie "${KEY}" "${i}" > currentPage.acg
        store_Target
        set_Temp
    done
}

function exit_Clean(){
    rm -f "*.acg"
}

function trans_Drive(){
    echo -e "${yellow}[INFO]${plain}正在移动文件——传回Google Drive"
    mv ${tempDownPath}/* ${base}/ || check_State
    echo -e "${green}[INFO]${plain}已经完成传输"
}
#==================================
int
show_Target
down_Target
trans_Drive
exit_Clean