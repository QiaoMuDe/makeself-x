#!/bin/sh
#
# Makeself 版本 2.5.x
#  作者：Stephane Peter <megastep@megastep.org>
#
# 用于创建自解压 tar.gz 归档文件的实用工具。
# 生成的归档文件是一个包含 tar.gz 归档的文件，
# 附带一个小型的 Shell 脚本存根，该脚本会将归档文件解压到一个临时目录，
# 然后在该目录中执行指定的脚本。
#
# Makeself 主页：https://makeself.io/ - 版本历史可在 GitHub 上查看
#
# (C) 1998 - 2023 由 Stephane Peter <megastep@megastep.org> 所有
#
# 本软件根据 GNU GPL 版本 2 及更高版本的条款发布
# 请阅读位于 http://www.gnu.org/copyleft/gpl.html 的许可协议
# 使用本脚本创建的自解压归档文件明确不遵循 GPL 条款发布
#

# 定义 Makeself 的版本号为 2.5.0
MS_VERSION=2.5.0
# 将当前脚本的名称赋值给 MS_COMMAND 变量
MS_COMMAND="$0"
# 取消设置 CDPATH 环境变量，避免在查找文件时出现意外的路径搜索行为
unset CDPATH

# 遍历所有传入的命令行参数，将它们添加到 MS_COMMAND 变量中，以便后续使用
for f in ${1+"$@"}; do
    MS_COMMAND="$MS_COMMAND \\\\
    \\\"$f\\\""
done

# 对于 Solaris 系统，若 /usr/xpg4/bin 目录存在，则将其添加到 PATH 环境变量的开头，
# 这样系统在查找命令时会优先使用该目录下的命令，以确保使用符合 POSIX 标准的工具
if test -d /usr/xpg4/bin; then
    PATH=/usr/xpg4/bin:$PATH
    export PATH
fi

# 打印帮助信息并退出
MS_Usage()
{
    echo "用法: $0 [参数] 归档目录 文件名 标签 启动脚本 [脚本参数]"
    echo "参数可以是以下一个或多个:"
    echo "    --version | -v     : 打印 Makeself 版本号并退出"
    echo "    --help | -h        : 打印此帮助信息"
    echo "    --tar-quietly      : 抑制 tar 命令的详细输出"
    echo "    --quiet | -q       : 除错误信息外，不打印任何消息。"
    echo "    --gzip             : 使用 gzip 进行压缩（如果检测到则为默认方式）"
    echo "    --pigz             : 使用 pigz 进行压缩"
    echo "    --zstd             : 使用 zstd 进行压缩"
    echo "    --bzip2            : 使用 bzip2 代替 gzip 进行压缩"
    echo "    --pbzip2           : 使用 pbzip2 代替 gzip 进行压缩"
    echo "    --bzip3            : 使用 bzip3 代替 gzip 进行压缩"
    echo "    --xz               : 使用 xz 代替 gzip 进行压缩"
    echo "    --lzo              : 使用 lzop 代替 gzip 进行压缩"
    echo "    --lz4              : 使用 lz4 代替 gzip 进行压缩"
    echo "    --compress         : 使用 UNIX 的 'compress' 命令进行压缩"
    echo "    --complevel lvl    : 设置 gzip、pigz、zstd、xz、lzo、lz4、bzip2、pbzip2 和 bzip3 的压缩级别（默认值为 9）"
    echo "    --threads thds     : 供支持并行处理的压缩器使用的线程数。"
    echo "                         省略此参数将使用压缩器的默认值。对于启用 xz 的多线程功能最有用（也是必需的），"
    echo "                         通常使用 '--threads=0' 来使用所有可用核心。"
    echo "                         pbzip2 和 pigz 默认是并行的，设置此值可以限制它们使用的线程数。"
    echo "    --base64           : 不进行压缩，而是使用 base64 对数据进行编码"
    echo "    --gpg-encrypt      : 不进行压缩，而是使用 GPG 对数据进行加密"
    echo "    --gpg-asymmetric-encrypt-sign"
    echo "                       : 不进行压缩，而是使用 GPG 对数据进行非对称加密并签名"
    echo "    --gpg-extra opt    : 在 gpg 命令行中追加更多选项"
    echo "    --ssl-encrypt      : 不进行压缩，而是使用 OpenSSL 对数据进行加密"
    echo "    --ssl-passwd pass  : 使用给定的密码通过 OpenSSL 对数据进行加密"
    echo "    --ssl-pass-src src : 使用给定的源作为通过 OpenSSL 加密数据的密码来源。"
    echo "                         请参阅 man openssl 中的 \"PASS PHRASE ARGUMENTS\" 部分。"
    echo "                         如果未提供此选项，系统将提示用户在当前终端输入加密密码。"
    echo "    --ssl-no-md        : 不使用较旧版本 OpenSSL 不支持的 \"-md\" 选项。"
    echo "    --nochown          : 不将目标文件夹的所有权赋予当前用户（默认设置）"
    echo "    --chown            : 递归地将目标文件夹的所有权赋予当前用户"
    echo "    --nocomp           : 不压缩数据"
    echo "    --notemp           : 归档文件将在当前目录中创建归档目录，并在 ./archive_dir 中解压"
    echo "                         注意：持久化归档文件不一定需要启动脚本"
    echo "    --needroot         : 在继续操作之前，检查是否由 root 用户提取归档文件"
    echo "    --copy             : 提取时，归档文件将首先将自身复制到一个临时目录"
    echo "    --append           : 向现有的 Makeself 归档文件追加更多文件"
    echo "                         此时标签和启动脚本将被忽略"
    echo "    --target dir       : 直接提取到目标目录"
    echo "                         目录路径可以是绝对路径或相对路径"
    echo "    --current          : 文件将提取到当前目录"
    echo "                         --current 和 --target 都隐含 --notemp，并且不需要启动脚本"
    echo "    --nooverwrite      : 如果指定的目标目录已存在，则不提取归档文件"
    echo "    --tar-format opt   : 指定 tar 归档文件的格式（默认是 ustar）"
    echo "    --tar-extra opt    : 在 tar 命令行中追加更多选项"
    echo "    --untar-extra opt  : 在提取 tar 归档文件时追加更多选项"
    echo "    --nomd5            : 不计算归档文件的 MD5 校验和"
    echo "    --nocrc            : 不计算归档文件的 CRC 校验和"
    echo "    --sha256           : 计算归档文件的 SHA256 校验和"
    echo "    --header file      : 指定头脚本的位置"
    echo "    --preextract file  : 指定预提取脚本"
    echo "    --cleanup file     : 指定在中断时和成功完成时执行的清理脚本"
    echo "    --follow           : 跟随归档文件中的符号链接"
    echo "    --noprogress       : 解压过程中不显示进度"
    echo "    --nox11            : 禁用自动启动 xterm"
    echo "    --nowait           : 从 xterm 执行嵌入程序后，不等待用户输入"
    echo "    --sign passphrase  : 用于对软件包进行签名的私钥密码"
    echo "    --lsm file         : 描述软件包的 LSM 文件"
    echo "    --license file     : 追加许可文件"
    echo "    --help-header file : 为归档文件的 --help 输出添加标题"
    echo "    --packaging-date date"
    echo "                       : 使用提供的字符串作为打包日期，而不是当前日期。"
    echo
    echo "    --keep-umask       : 在执行自解压归档文件时，保持 umask 设置为 shell 默认值，而不是覆盖它。"
    echo "    --export-conf      : 将配置变量导出到启动脚本"
    echo
    echo "环境变量"
    echo "    SETUP_NOCHECK"
    echo "        如果设置为 1，则跳过校验和验证。"
    echo
    echo "示例用法:"
    echo "    $0 目标目录 生成的运行包.run 运行包标签 启动脚本.sh 参数1 参数2"
    echo "     用于创建一个自解压的运行包.run, 运行结束会自动删除解压出的目录"
    echo "    $0 --notemp 目标目录 生成的运行包.run 运行包标签 启动脚本.sh 参数1 参数2"
    echo "     用于创建一个自解压的运行包.run, 运行结束不会自动删除解压出的目录" 
    echo
    echo "不要忘记提供完全限定的启动脚本名称"
    echo "(即如果脚本在归档文件内，请加上 ./ 前缀)。"
    exit 1
}

# 默认设置
if type gzip >/dev/null 2>&1; then
    COMPRESS=gzip
elif type compress >/dev/null 2>&1; then
    COMPRESS=compress
else
    echo "错误: 缺少命令: gzip, compress" >&2
    MS_Usage
fi
# 是否加密，n 表示不加密
ENCRYPT=n
# 加密密码
PASSWD=""
# 加密密码来源
PASSWD_SRC=""
# 是否不使用 OpenSSL 的 -md 选项，n 表示使用
OPENSSL_NO_MD=n
# 压缩级别
COMPRESS_LEVEL=9
# 默认线程数，作为哨兵值
DEFAULT_THREADS=123456 
# 当前使用的线程数
THREADS=$DEFAULT_THREADS
# 是否保留临时目录，n 表示不保留
KEEP=n
# 是否提取到当前目录，n 表示否
CURRENT=n
# 是否禁用自动启动 xterm，n 表示不禁用
NOX11=n
# 从 xterm 执行嵌入程序后是否不等待用户输入，n 表示等待
NOWAIT=n
# 是否追加到现有归档文件，n 表示不追加
APPEND=n
# 是否抑制 tar 命令的详细输出，n 表示不抑制
TAR_QUIETLY=n
# 在执行自解压归档文件时是否保持 umask 设置为 shell 默认值，n 表示不保持
KEEP_UMASK=n
# 是否除错误信息外不打印任何消息，n 表示打印
QUIET=n
# 解压过程中是否不显示进度，n 表示显示
NOPROGRESS=n
# 提取时的复制方式，none 表示不复制
COPY=none
# 是否需要 root 用户提取归档文件，n 表示不需要
NEED_ROOT=n
# tar 命令的参数
TAR_ARGS=rvf
# tar 归档文件的格式
TAR_FORMAT=ustar
# tar 命令行中追加的额外选项
TAR_EXTRA=""
# gpg 命令行中追加的额外选项
GPG_EXTRA=""
# du 命令的参数
DU_ARGS=-ks
# 头脚本的位置
HEADER=`dirname "$0"`/makeself-header.sh
# 签名信息
SIGNATURE=""
# 目标目录
TARGETDIR=""
# 如果指定的目标目录已存在是否不提取归档文件，n 表示提取
NOOVERWRITE=n
# 打包日期
DATE=`LC_ALL=C date`
# 是否将配置变量导出到启动脚本，n 表示不导出
EXPORT_CONF=n
# 是否计算归档文件的 SHA256 校验和，n 表示不计算
SHA256=n
# 是否递归地将目标文件夹的所有权赋予当前用户，n 表示不赋予
OWNERSHIP=n
# 是否对软件包进行签名，n 表示不签名
SIGN=n
# 用于对软件包进行签名的私钥密码
GPG_PASSPHRASE=""
# LSM 文件相关操作
LSM_CMD="echo 无 LSM 文件。 >> \"\$archname\""


# 进入一个无限循环，用于解析命令行参数，直到遇到非选项参数为止
while true
do
    # 使用 case 语句对命令行参数 $1 进行模式匹配
    case "$1" in
    # 打印 Makeself 版本号并退出程序
    --version | -v)
        echo "Makeself 版本 $MS_VERSION"
        exit 0
        ;;
    # 设置压缩工具为 pbzip2，并移动到下一个参数
    --pbzip2)
        COMPRESS=pbzip2
        shift
        ;;
    # 设置压缩工具为 bzip3，并移动到下一个参数
    --bzip3)
        COMPRESS=bzip3
        shift
        ;;
    # 设置压缩工具为 bzip2，并移动到下一个参数
    --bzip2)
        COMPRESS=bzip2
        shift
        ;;
    # 设置压缩工具为 gzip，并移动到下一个参数
    --gzip)
        COMPRESS=gzip
        shift
        ;;
    # 设置压缩工具为 pigz，并移动到下一个参数
    --pigz)
        COMPRESS=pigz
        shift
        ;;
    # 设置压缩工具为 zstd，并移动到下一个参数
    --zstd)
        COMPRESS=zstd
        shift
        ;;
    # 设置压缩工具为 xz，并移动到下一个参数
    --xz)
        COMPRESS=xz
        shift
        ;;
    # 设置压缩工具为 lzo，并移动到下一个参数
    --lzo)
        COMPRESS=lzo
        shift
        ;;
    # 设置压缩工具为 lz4，并移动到下一个参数
    --lz4)
        COMPRESS=lz4
        shift
        ;;
    # 设置压缩工具为 compress，并移动到下一个参数
    --compress)
        COMPRESS=compress
        shift
        ;;
    # 设置压缩工具为 base64 编码方式，并移动到下一个参数
    --base64)
        COMPRESS=base64
        shift
        ;;
    # 设置压缩工具为 gpg 加密方式，并移动到下一个参数
    --gpg-encrypt)
        COMPRESS=gpg
        shift
        ;;
    # 设置压缩工具为 gpg 非对称加密并签名方式，并移动到下一个参数
    --gpg-asymmetric-encrypt-sign)
        COMPRESS=gpg-asymmetric
        shift
        ;;
    # 设置 gpg 命令行中追加的额外选项，并移动两个参数位置
    --gpg-extra)
        GPG_EXTRA="$2"
        shift 2 || { MS_Usage; exit 1; }
        ;;
    # 设置加密工具为 OpenSSL，并移动到下一个参数
    --ssl-encrypt)
        ENCRYPT=openssl
        shift
        ;;
    # 设置 OpenSSL 加密使用的密码，并移动两个参数位置
    --ssl-passwd)
        PASSWD=$2
        shift 2 || { MS_Usage; exit 1; }
        ;;
    # 设置 OpenSSL 加密密码的来源，并移动两个参数位置
    --ssl-pass-src)
        PASSWD_SRC=$2
        shift 2 || { MS_Usage; exit 1; }
        ;;
    # 不使用 OpenSSL 的 -md 选项，并移动到下一个参数
    --ssl-no-md)
        OPENSSL_NO_MD=y
        shift
        ;;
    # 不进行压缩，并移动到下一个参数
    --nocomp)
        COMPRESS=none
        shift
        ;;
    # 设置压缩级别，并移动两个参数位置
    --complevel)
        COMPRESS_LEVEL="$2"
        shift 2 || { MS_Usage; exit 1; }
        ;;
    # 设置压缩器使用的线程数，并移动两个参数位置
    --threads)
        THREADS="$2"
        shift 2 || { MS_Usage; exit 1; }
        ;;
    # 不递归地将目标文件夹的所有权赋予当前用户，并移动到下一个参数
    --nochown)
        OWNERSHIP=n
        shift
        ;;
    # 递归地将目标文件夹的所有权赋予当前用户，并移动到下一个参数
    --chown)
        OWNERSHIP=y
        shift
        ;;
    # 保留临时目录，并移动到下一个参数
    --notemp)
        KEEP=y
        shift
        ;;
    # 提取时将自身复制到一个临时目录，并移动到下一个参数
    --copy)
        COPY=copy
        shift
        ;;
    # 提取到当前目录，同时保留临时目录，并移动到下一个参数
    --current)
        CURRENT=y
        KEEP=y
        shift
        ;;
    # 设置 tar 归档文件的格式，并移动两个参数位置
    --tar-format)
        TAR_FORMAT="$2"
        shift 2 || { MS_Usage; exit 1; }
        ;;
    # 设置 tar 命令行中追加的额外选项，并移动两个参数位置
    --tar-extra)
        TAR_EXTRA="$2"
        shift 2 || { MS_Usage; exit 1; }
        ;;
    # 设置提取 tar 归档文件时追加的额外选项，并移动两个参数位置
    --untar-extra)
        UNTAR_EXTRA="$2"
        shift 2 || { MS_Usage; exit 1; }
        ;;
    # 设置提取的目标目录，同时保留临时目录，并移动两个参数位置
    --target)
        TARGETDIR="$2"
        KEEP=y
        shift 2 || { MS_Usage; exit 1; }
        ;;
    # 对软件包进行签名，设置私钥密码，并移动两个参数位置
    --sign)
        SIGN=y
        GPG_PASSPHRASE="$2"
        shift 2 || { MS_Usage; exit 1; }
        ;;
    # 如果指定的目标目录已存在，则不提取归档文件，并移动到下一个参数
    --nooverwrite)
        NOOVERWRITE=y
        shift
        ;;
    # 检查是否由 root 用户提取归档文件，并移动到下一个参数
    --needroot)
        NEED_ROOT=y
        shift
        ;;
    # 设置头脚本的位置，并移动两个参数位置
    --header)
        HEADER="$2"
        shift 2 || { MS_Usage; exit 1; }
        ;;
    # 设置预提取脚本，检查文件是否可读并进行 base64 编码，并移动两个参数位置
    --preextract)
        preextract_file="$2"
        shift 2 || { MS_Usage; exit 1; }
        test -r "$preextract_file" || { echo "无法打开预提取脚本: $preextract_file" >&2; exit 1; }
        PREEXTRACT_ENCODED=`base64 "$preextract_file"`
        ;;
    # 设置清理脚本，并移动两个参数位置
    --cleanup)
        CLEANUP_SCRIPT="$2"
        shift 2 || { MS_Usage; exit 1; }
        ;;
    # 设置许可文件，转义特殊字符，并移动两个参数位置
    --license)
        # 我们需要转义双引号中有特殊含义的所有字符
        LICENSE=$(sed 's/\\/\\\\/g; s/"/\\\"/g; s/`/\\\`/g; s/\$/\\\$/g' "$2")
        shift 2 || { MS_Usage; exit 1; }
        ;;
    # 跟随归档文件中的符号链接，修改 tar 和 du 命令的参数，并移动到下一个参数
    --follow)
        TAR_ARGS=rvhf
        DU_ARGS=-ksL
        shift
        ;;
    # 解压过程中不显示进度，并移动到下一个参数
    --noprogress)
        NOPROGRESS=y
        shift
        ;;
    # 禁用自动启动 xterm，并移动到下一个参数
    --nox11)
        NOX11=y
        shift
        ;;
    # 从 xterm 执行嵌入程序后，不等待用户输入，并移动到下一个参数
    --nowait)
        NOWAIT=y
        shift
        ;;
    # 不计算归档文件的 MD5 校验和，并移动到下一个参数
    --nomd5)
        NOMD5=y
        shift
        ;;
    # 计算归档文件的 SHA256 校验和，并移动到下一个参数
    --sha256)
        SHA256=y
        shift
        ;;
    # 不计算归档文件的 CRC 校验和，并移动到下一个参数
    --nocrc)
        NOCRC=y
        shift
        ;;
    # 向现有的 Makeself 归档文件追加更多文件，并移动到下一个参数
    --append)
        APPEND=y
        shift
        ;;
    # 设置描述软件包的 LSM 文件操作命令，并移动两个参数位置
    --lsm)
        LSM_CMD="awk 1 \"$2\" >> \"\$archname\""
        shift 2 || { MS_Usage; exit 1; }
        ;;
    # 设置打包日期，并移动两个参数位置
    --packaging-date)
        DATE="$2"
        shift 2 || { MS_Usage; exit 1; }
        ;;
    # 为归档文件的 --help 输出添加标题，并移动两个参数位置
    --help-header)
        HELPHEADER=`sed -e "s/'/'\\\\\''/g" $2`
        shift 2 || { MS_Usage; exit 1; }
        [ -n "$HELPHEADER" ] && HELPHEADER="$HELPHEADER"
        ;;
    # 抑制 tar 命令的详细输出，并移动到下一个参数
    --tar-quietly)
        TAR_QUIETLY=y
        shift
        ;;
    # 在执行自解压归档文件时，保持 umask 设置为 shell 默认值，并移动到下一个参数
    --keep-umask)
        KEEP_UMASK=y
        shift
        ;;
    # 将配置变量导出到启动脚本，并移动到下一个参数
    --export-conf)
        EXPORT_CONF=y
        shift
        ;;
    # 除错误信息外，不打印任何消息，并移动到下一个参数
    -q | --quiet)
        QUIET=y
        shift
        ;;
    # 打印帮助信息并退出程序
    -h | --help)
        MS_Usage
        ;;
    # 处理未识别的选项，打印错误信息并显示帮助信息
    -*)
        echo "未识别的标志: $1"
        MS_Usage
        ;;
    # 遇到非选项参数，跳出循环
    *)
        break
        ;;
    esac
done

# 检查命令行参数数量是否小于 1，如果是则显示使用说明
if test $# -lt 1; then
    MS_Usage
else
    # 检查第一个参数是否为一个存在的目录
    if test -d "$1"; then
        # 如果目录存在，将其赋值给 archdir 变量
        archdir="$1"
    else
        # 如果目录不存在，输出错误信息并退出脚本
        echo "目录 $1 不存在。" >&2
        exit 1
    fi
fi
# 将第二个参数赋值给归档文件名变量 archname
archname="$2"

# 检查是否设置了安静模式或者 tar 命令静默输出模式
if test "$QUIET" = "y" || test "$TAR_QUIETLY" = "y"; then
    # 如果 tar 参数为 rvf，将其修改为 rf 以去除详细输出
    if test "$TAR_ARGS" = "rvf"; then
        TAR_ARGS="rf"
    # 如果 tar 参数为 rvhf，将其修改为 rhf 以去除详细输出
    elif test "$TAR_ARGS" = "rvhf"; then
        TAR_ARGS="rhf"
    fi
fi

# 检查是否要追加到现有归档文件
if test "$APPEND" = y; then
    # 检查命令行参数数量是否小于 2，如果是则显示使用说明
    if test $# -lt 2; then
        MS_Usage
    fi

    # 从原始归档文件中收集配置信息
    OLDENV=`sh "$archname" --dumpconf`
    # 检查收集配置信息的命令是否执行成功
    if test $? -ne 0; then
        # 如果执行失败，输出错误信息并退出脚本
        echo "无法更新归档文件: $archname" >&2
        exit 1
    else
        # 执行收集到的配置信息
        eval "$OLDENV"
        # 计算旧的跳过行数
        OLDSKIP=`expr $SKIP + 1`
    fi
else
    # 检查是否不保留临时目录且命令行参数数量为 3，如果是则输出错误信息并显示使用说明
    if test "$KEEP" = n -a $# = 3; then
        echo "错误: 创建一个没有嵌入命令的临时归档文件没有意义！" >&2
        echo >&2
        MS_Usage
    fi
    # 除非指定了目标目录，否则不创建绝对路径目录
    if test "$CURRENT" = y; then
        # 如果提取到当前目录，将归档目录名设置为 .
        archdirname="."
    elif test x"$TARGETDIR" != x; then
        # 如果指定了目标目录，将归档目录名设置为目标目录
        archdirname="$TARGETDIR"
    else
        # 否则，将归档目录名设置为第一个参数的基名
        archdirname=`basename "$1"`
    fi

    # 检查命令行参数数量是否小于 3，如果是则显示使用说明
    if test $# -lt 3; then
        MS_Usage
    fi

    # 将第三个参数赋值给标签变量 LABEL
    LABEL="$3"
    # 将第四个参数赋值给脚本变量 SCRIPT
    SCRIPT="$4"
    # 如果脚本变量不为空，移动参数位置
    test "x$SCRIPT" = x || shift 1
    # 移动三个参数位置
    shift 3
    # 将剩余的参数赋值给脚本参数变量 SCRIPTARGS
    SCRIPTARGS="$*"
fi

# 检查是否不保留临时目录且提取到当前目录，如果是则输出错误信息并退出脚本
if test "$KEEP" = n -a "$CURRENT" = y; then
    echo "错误: 尝试同时使用 --notemp 和 --current 是非常危险的！" >&2
    exit 1
fi

# 根据压缩工具类型设置压缩和解压命令
case $COMPRESS in
gzip)
    # 设置 gzip 压缩命令
    GZIP_CMD="gzip -c$COMPRESS_LEVEL"
    # 设置 gzip 解压命令
    GUNZIP_CMD="gzip -cd"
    ;;
pigz) 
    # 设置 pigz 压缩命令
    GZIP_CMD="pigz -$COMPRESS_LEVEL"
    # 如果指定了线程数，在压缩命令中添加线程数参数
    if test $THREADS -ne $DEFAULT_THREADS; then # 如果未指定线程数，则使用默认值
        GZIP_CMD="$GZIP_CMD --processes $THREADS"
    fi
    # 设置 pigz 解压命令
    GUNZIP_CMD="gzip -cd"
    ;;
zstd)
    # 设置 zstd 压缩命令
    GZIP_CMD="zstd -$COMPRESS_LEVEL"
    # 如果指定了线程数，在压缩命令中添加线程数参数
    if test $THREADS -ne $DEFAULT_THREADS; then # 如果未指定线程数，则使用默认值
        GZIP_CMD="$GZIP_CMD --threads=$THREADS"
    fi
    # 设置 zstd 解压命令
    GUNZIP_CMD="zstd -cd"
    ;;
pbzip2)
    # 设置 pbzip2 压缩命令
    GZIP_CMD="pbzip2 -c$COMPRESS_LEVEL"
    # 如果指定了线程数，在压缩命令中添加线程数参数
    if test $THREADS -ne $DEFAULT_THREADS; then # 如果未指定线程数，则使用默认值
        GZIP_CMD="$GZIP_CMD -p$THREADS"
    fi
    # 设置 pbzip2 解压命令
    GUNZIP_CMD="bzip2 -d"
    ;;
bzip3)
    # 将压缩级别映射为以 MiB 为单位的块大小，计算公式为 2^(级别 - 1)
    BZ3_COMPRESS_LEVEL=`echo "2^($COMPRESS_LEVEL-1)" | bc`
    # 设置 bzip3 压缩命令
    GZIP_CMD="bzip3 -b$BZ3_COMPRESS_LEVEL"
    # 如果指定了线程数，在压缩命令中添加线程数参数
    if test $THREADS -ne $DEFAULT_THREADS; then # 如果未指定线程数，则使用默认值
        GZIP_CMD="$GZIP_CMD -j$THREADS"
    fi
    # 计算解压作业数
    JOBS=`echo "10-$COMPRESS_LEVEL" | bc`
    # 设置 bzip3 解压命令
    GUNZIP_CMD="bzip3 -dj$JOBS"
    ;;
bzip2)
    # 设置 bzip2 压缩命令
    GZIP_CMD="bzip2 -$COMPRESS_LEVEL"
    # 设置 bzip2 解压命令
    GUNZIP_CMD="bzip2 -d"
    ;;
xz)
    # 设置 xz 压缩命令
    GZIP_CMD="xz -c$COMPRESS_LEVEL"
    # 由于并非所有版本的 xz 都支持多线程，因此需要显式指定线程数
    if test $THREADS -ne $DEFAULT_THREADS; then 
        GZIP_CMD="$GZIP_CMD --threads=$THREADS"
    fi
    # 设置 xz 解压命令
    GUNZIP_CMD="xz -d"
    ;;
lzo)
    # 设置 lzo 压缩命令
    GZIP_CMD="lzop -c$COMPRESS_LEVEL"
    # 设置 lzo 解压命令
    GUNZIP_CMD="lzop -d"
    ;;
lz4)
    # 设置 lz4 压缩命令
    GZIP_CMD="lz4 -c$COMPRESS_LEVEL"
    # 设置 lz4 解压命令
    GUNZIP_CMD="lz4 -d"
    ;;
base64)
    # 设置 base64 编码命令
    GZIP_CMD="base64"
    # 设置 base64 解码命令
    GUNZIP_CMD="base64 --decode -i -"
    ;;
gpg)
    # 设置 gpg 加密压缩命令
    GZIP_CMD="gpg $GPG_EXTRA -ac -z$COMPRESS_LEVEL"
    # 设置 gpg 解密命令
    GUNZIP_CMD="gpg -d"
    # 设置加密方式为 gpg
    ENCRYPT="gpg"
    ;;
gpg-asymmetric)
    # 设置 gpg 非对称加密并签名的压缩命令
    GZIP_CMD="gpg $GPG_EXTRA -z$COMPRESS_LEVEL -es"
    # 设置 gpg 解密命令
    GUNZIP_CMD="gpg --yes -d"
    # 设置加密方式为 gpg
    ENCRYPT="gpg"
    ;;
compress)
    # 设置 compress 压缩命令
    GZIP_CMD="compress -fc"
    # 设置 compress 解压命令，如果 compress 不可用则使用 gzip
    GUNZIP_CMD="(type compress >/dev/null 2>&1 && compress -fcd || gzip -cd)"
    ;;
none)
    # 设置不压缩命令
    GZIP_CMD="cat"
    # 设置不压缩的解压命令
    GUNZIP_CMD="cat"
    ;;
esac

# 检查是否使用 OpenSSL 进行加密
if test x"$ENCRYPT" = x"openssl"; then
    # 检查是否要追加到现有归档文件，如果是则输出错误信息
    if test x"$APPEND" = x"y"; then
        echo "向现有归档文件追加内容与 OpenSSL 加密不兼容。" >&2
    fi
    
    # 设置 OpenSSL 加密命令
    ENCRYPT_CMD="openssl enc -aes-256-cbc -salt -pbkdf2"
    # 设置 OpenSSL 解密命令
    DECRYPT_CMD="openssl enc -aes-256-cbc -d -salt -pbkdf2"
    
    # 检查是否不使用 -md 选项，如果不是则添加 -md sha256 选项
    if test x"$OPENSSL_NO_MD" != x"y"; then
        ENCRYPT_CMD="$ENCRYPT_CMD -md sha256"
        DECRYPT_CMD="$DECRYPT_CMD -md sha256"
    fi

    # 检查是否指定了密码来源，如果是则在加密命令中添加密码来源参数
    if test -n "$PASSWD_SRC"; then
        ENCRYPT_CMD="$ENCRYPT_CMD -pass $PASSWD_SRC"
    # 检查是否指定了密码，如果是则在加密命令中添加密码参数
    elif test -n "$PASSWD"; then 
        ENCRYPT_CMD="$ENCRYPT_CMD -pass pass:$PASSWD"
    fi
fi

# 创建临时文件，若 TMPDIR 环境变量未设置，则使用 /tmp 目录
tmpfile="${TMPDIR:-/tmp}/mkself$$"

# 检查头文件是否存在
if test -f "$HEADER"; then
    # 保存原始归档文件名
    oldarchname="$archname"
    # 将归档文件名临时设置为临时文件
    archname="$tmpfile"
    # 生成一个伪头文件以统计其行数
    SKIP=0
    # 执行头文件内容
    . "$HEADER"
    # 统计临时文件的行数
    SKIP=`cat "$tmpfile" |wc -l`
    # 去除行数中的空格
    SKIP=`expr $SKIP`
    # 删除临时文件
    rm -f "$tmpfile"
    # 如果不是安静模式，则输出头文件的行数
    if test "$QUIET" = "n"; then
        echo "头文件有 $SKIP 行" >&2
    fi
    # 恢复原始归档文件名
    archname="$oldarchname"
else
    # 若无法打开头文件，输出错误信息并退出
    echo "无法打开头文件: $HEADER" >&2
    exit 1
fi

# 如果不是安静模式，则输出一个空行
if test "$QUIET" = "n"; then
    echo
fi

# 如果不是追加模式
if test "$APPEND" = n; then
    # 检查归档文件是否已存在
    if test -f "$archname"; then
        # 若存在，输出警告信息提示将覆盖现有文件
        echo "警告: 即将覆盖现有文件: $archname" >&2
    fi
fi

# 计算归档目录的大小（KB）
USIZE=`du $DU_ARGS "$archdir" | awk '{print $1}'`

# 如果归档目录名为 .
if test "." = "$archdirname"; then
    # 如果不保留临时目录
    if test "$KEEP" = n; then
        # 生成一个唯一的归档目录名
        archdirname="makeself-$$-`date +%Y%m%d%H%M%S`"
    fi
fi

# 检查归档目录是否存在，若不存在则输出错误信息，删除临时文件并退出
test -d "$archdir" || { echo "错误: $archdir 目录不存在。"; rm -f "$tmpfile"; exit 1; }
# 如果不是安静模式，则输出即将压缩数据和添加文件到归档的信息
if test "$QUIET" = "n"; then
    echo "即将压缩 $USIZE KB 的数据..."
    echo "正在将文件添加到名为 \"$archname\" 的归档文件中..."
fi

# 检查是否存在 GNU tar
TAR=`exec <&- 2>&-; which gtar || command -v gtar || type gtar`
# 若不存在 GNU tar，检查是否存在 bsdtar
test -x "$TAR" || TAR=`exec <&- 2>&-; which bsdtar || command -v bsdtar || type bsdtar`
# 若都不存在，则使用默认的 tar
test -x "$TAR" || TAR=tar

# 创建临时 tar 归档文件
tmparch="${TMPDIR:-/tmp}/mkself$$.tar"
(
    # 如果是追加模式
    if test "$APPEND" = "y"; then
        # 从现有归档文件中提取数据并解压到临时 tar 文件
        tail -n "+$OLDSKIP" "$archname" | eval "$GUNZIP_CMD" > "$tmparch"
    fi
    # 进入归档目录
    cd "$archdir"
    # 参考链接：https://www.etalabs.net/sh_tricks.html 用于判断目录是否为空
    # 查找文件并添加到临时 tar 文件
    find . \
        \( \
        ! -type d \
        -o \
        \( -links 2 -exec sh -c '
            # 定义一个函数用于判断目录是否为空
            is_empty () (
                cd "$1"
                set -- .[!.]* ; test -f "$1" && return 1
                set -- ..?* ; test -f "$1" && return 1
                set -- * ; test -f "$1" && return 1
                return 0
            )
            is_empty "$0"' {} \; \
        \) \
        \) -print \
        | LC_ALL=C sort \
        | sed 's/./\\&/g' \
        | xargs $TAR $TAR_EXTRA --format $TAR_FORMAT -$TAR_ARGS "$tmparch"
) || {
    # 若创建临时归档文件失败，输出错误信息，删除临时文件并退出
    echo "错误: 无法创建临时归档文件: $tmparch"
    rm -f "$tmparch" "$tmpfile"
    exit 1
}

# 计算临时 tar 归档文件的大小（KB）
USIZE=`du $DU_ARGS "$tmparch" | awk '{print $1}'`

# 对临时 tar 文件进行压缩并保存到临时文件
eval "$GZIP_CMD" <"$tmparch" >"$tmpfile" || {
    # 若压缩失败，输出错误信息，删除临时文件并退出
    echo "错误: 无法创建临时文件: $tmpfile"
    rm -f "$tmparch" "$tmpfile"
    exit 1
}
# 删除临时 tar 文件
rm -f "$tmparch"

# 如果使用 OpenSSL 进行加密
if test x"$ENCRYPT" = x"openssl"; then
    # 输出即将加密归档文件的信息
    echo "即将对归档文件 \"$archname\" 进行加密..."
    { eval "$ENCRYPT_CMD -in $tmpfile -out ${tmpfile}.enc" && mv -f ${tmpfile}.enc $tmpfile; } || \
        { echo "中止: 无法对临时文件: $tmpfile 进行加密。"; rm -f "$tmpfile"; exit 1; }
fi

# 计算临时文件的字节数
fsize=`cat "$tmpfile" | wc -c | tr -d " "`

# 计算校验和，初始化校验和值
shasum=0000000000000000000000000000000000000000000000000000000000000000
md5sum=00000000000000000000000000000000
crcsum=0000000000

# 检查是否根据用户请求跳过 CRC 校验和计算
if test "$NOCRC" = y; then
    # 如果不是安静模式，则输出提示信息
    if test "$QUIET" = "n"; then
        echo "根据用户请求，跳过 CRC 校验和计算"
    fi
else
    # 计算 CRC 校验和
    crcsum=`CMD_ENV=xpg4 cksum < "$tmpfile" | sed -e 's/ /Z/' -e 's/	/Z/' | cut -dZ -f1`
    # 如果不是安静模式，则输出 CRC 校验和
    if test "$QUIET" = "n"; then
        echo "CRC: $crcsum"
    fi
fi

# 检查是否需要计算 SHA256 校验和
if test "$SHA256" = y; then
    # 尝试查找 shasum 命令的路径
    SHA_PATH=`exec <&- 2>&-; which shasum || command -v shasum || type shasum`
    if test -x "$SHA_PATH"; then
        # 使用 shasum 命令计算 SHA256 校验和
        shasum=`eval "$SHA_PATH -a 256" < "$tmpfile" | cut -b-64`
    else
        # 若 shasum 命令不存在，尝试查找 sha256sum 命令的路径
        SHA_PATH=`exec <&- 2>&-; which sha256sum || command -v sha256sum || type sha256sum`
        shasum=`eval "$SHA_PATH" < "$tmpfile" | cut -b-64`
    fi
    # 如果不是安静模式，则输出 SHA256 校验和或提示信息
    if test "$QUIET" = "n"; then
        if test -x "$SHA_PATH"; then
            echo "SHA256: $shasum"
        else
            echo "SHA256: 无，未找到 SHA 命令"
        fi
    fi
fi

# 检查是否根据用户请求跳过 MD5 校验和计算
if test "$NOMD5" = y; then
    # 如果不是安静模式，则输出提示信息
    if test "$QUIET" = "n"; then
        echo "根据用户请求，跳过 MD5 校验和计算"
    fi
else
    # 尝试定位 MD5 二进制文件
    OLD_PATH=$PATH
    PATH=${GUESS_MD5_PATH:-"$OLD_PATH:/bin:/usr/bin:/sbin:/usr/local/ssl/bin:/usr/local/bin:/opt/openssl/bin"}
    MD5_ARG=""
    # 尝试查找 md5sum 命令的路径
    MD5_PATH=`exec <&- 2>&-; which md5sum || command -v md5sum || type md5sum`
    test -x "$MD5_PATH" || MD5_PATH=`exec <&- 2>&-; which md5 || command -v md5 || type md5`
    test -x "$MD5_PATH" || MD5_PATH=`exec <&- 2>&-; which digest || command -v digest || type digest`
    PATH=$OLD_PATH
    if test -x "$MD5_PATH"; then
        # 如果找到的是 digest 命令，需要添加 -a md5 参数
        if test `basename ${MD5_PATH}`x = digestx; then
            MD5_ARG="-a md5"
        fi
        # 计算 MD5 校验和
        md5sum=`eval "$MD5_PATH $MD5_ARG" < "$tmpfile" | cut -b-32`
        # 如果不是安静模式，则输出 MD5 校验和
        if test "$QUIET" = "n"; then
            echo "MD5: $md5sum"
        fi
    else
        # 如果不是安静模式，且未找到 MD5 命令，则输出提示信息
        if test "$QUIET" = "n"; then
            echo "MD5: 无，未找到 MD5 命令"
        fi
    fi
fi

# 检查是否需要对软件包进行签名
if test "$SIGN" = y; then
    # 尝试查找 gpg 命令的路径
    GPG_PATH=`exec <&- 2>&-; which gpg || command -v gpg || type gpg`
    if test -x "$GPG_PATH"; then
        # 使用 gpg 命令对文件进行签名并进行 base64 编码
        SIGNATURE=`$GPG_PATH --pinentry-mode=loopback --batch --yes $GPG_EXTRA --passphrase "$GPG_PASSPHRASE" --output - --detach-sig $tmpfile | base64 | tr -d \\n`
        # 如果不是安静模式，则输出签名信息
        if test "$QUIET" = "n"; then
            echo "签名: $SIGNATURE"
        fi
    else
        # 若未找到 gpg 命令，输出错误信息
        echo "缺少 gpg 命令" >&2
    fi
fi

# 计算文件总大小
totalsize=0
for size in $fsize;
do
    totalsize=`expr $totalsize + $size`
done

# 检查是否需要追加到现有归档文件
if test "$APPEND" = y; then
    # 将现有归档文件备份
    mv "$archname" "$archname".bak || exit

    # 为新归档文件准备条目
    filesizes="$fsize"
    CRCsum="$crcsum"
    MD5sum="$md5sum"
    SHAsum="$shasum"
    Signature="$SIGNATURE"
    # 生成头文件
    . "$HEADER"
    # 将新数据追加到归档文件中
    cat "$tmpfile" >> "$archname"

    # 给归档文件添加可执行权限
    chmod +x "$archname"
    # 删除备份文件
    rm -f "$archname".bak
    # 如果不是安静模式，则输出更新成功的提示信息
    if test "$QUIET" = "n"; then
        echo "自解压归档文件 \"$archname\" 已成功更新。"
    fi
else
    # 为新归档文件准备条目
    filesizes="$fsize"
    CRCsum="$crcsum"
    MD5sum="$md5sum"
    SHAsum="$shasum"
    Signature="$SIGNATURE"

    # 生成头文件
    . "$HEADER"

    # 将压缩的 tar 数据追加到存根之后
    if test "$QUIET" = "n"; then
        echo
    fi
    cat "$tmpfile" >> "$archname"
    # 给归档文件添加可执行权限
    chmod +x "$archname"
    # 如果不是安静模式，则输出创建成功的提示信息
    if test "$QUIET" = "n"; then
        echo "自解压归档文件 \"$archname\" 已成功创建。"
    fi
fi
# 删除临时文件
rm -f "$tmpfile"
