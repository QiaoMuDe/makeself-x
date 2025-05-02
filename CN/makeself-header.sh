# 将以下内容输出到指定文件中，该文件将作为脚本文件
cat << EOF  > "$archname"
#!/bin/sh
# 此脚本使用 Makeself $MS_VERSION 生成
# 覆盖此归档文件及其内容（如果有）的许可证完全独立于 Makeself 许可证（GPL）

# 保存原始的 umask 值
ORIG_UMASK=\`umask\`
# 如果 KEEP_UMASK 为 n，则设置 umask 为 077
if test "$KEEP_UMASK" = n; then
    umask 077
fi

# 定义 CRC 校验和
CRCsum="$CRCsum"
# 定义 MD5 校验和
MD5="$MD5sum"
# 定义 SHA 校验和
SHA="$SHAsum"
# 定义签名信息
SIGNATURE="$Signature"
# 定义临时目录根路径，默认为 /tmp
TMPROOT=\${TMPDIR:=/tmp}
# 保存用户当前工作目录
USER_PWD="\$PWD"
# 导出用户当前工作目录环境变量
export USER_PWD
# 获取当前脚本所在目录
ARCHIVE_DIR=\`dirname "\$0"\`
# 导出脚本所在目录环境变量
export ARCHIVE_DIR

# 定义标签信息
label="$LABEL"
# 定义要执行的脚本
script="$SCRIPT"
# 定义脚本的参数
scriptargs="$SCRIPTARGS"
# 定义清理脚本
cleanup_script="${CLEANUP_SCRIPT}"
# 定义许可证文本
licensetxt="$LICENSE"
# 定义帮助信息的头部
helpheader="${HELPHEADER}"
# 定义预提取脚本（已编码）
preextract="${PREEXTRACT_ENCODED}"
# 定义目标目录
targetdir="$archdirname"
# 定义文件大小列表
filesizes="$filesizes"
# 定义总大小
totalsize="$totalsize"
# 定义是否保留目标目录
keep="$KEEP"
# 定义是否不覆盖目标目录
nooverwrite="$NOOVERWRITE"
# 定义是否安静模式
quiet="n"
# 定义是否接受许可证
accept="n"
# 定义是否不检查磁盘空间
nodiskspace="n"
# 定义是否导出配置信息
export_conf="$EXPORT_CONF"
# 定义解密命令
decrypt_cmd="$DECRYPT_CMD"
# 定义跳过的行数
skip="$SKIP"

# 初始化打印命令的参数
print_cmd_arg=""
# 优先使用 printf 作为打印命令
if type printf > /dev/null; then
    print_cmd="printf"
# 若 /usr/ucb/echo 可执行，则使用它作为打印命令
elif test -x /usr/ucb/echo; then
    print_cmd="/usr/ucb/echo"
# 否则使用 echo 作为打印命令
else
    print_cmd="echo"
fi

# 如果 /usr/xpg4/bin 目录存在，则将其添加到 PATH 环境变量中
if test -d /usr/xpg4/bin; then
    PATH=/usr/xpg4/bin:\$PATH
    export PATH
fi

# 如果 /usr/sfw/bin 目录存在，则将其添加到 PATH 环境变量中
if test -d /usr/sfw/bin; then
    PATH=\$PATH:/usr/sfw/bin
    export PATH
fi

# 取消 CDPATH 环境变量
unset CDPATH

# 自定义打印函数
MS_Printf()
{
    \$print_cmd \$print_cmd_arg "\$1"
}

# 打印许可证并让用户确认的函数
MS_PrintLicense()
{
  # 定义分页器，默认为 more
  PAGER=\${PAGER:=more}
  # 如果存在许可证文本
  if test x"\$licensetxt" != x; then
    # 查找分页器的路径
    PAGER_PATH=\`exec <&- 2>&-; which \$PAGER || command -v \$PAGER || type \$PAGER\`
    # 如果分页器可执行且用户未接受许可证
    if test -x "\$PAGER_PATH" && test x"\$accept" != xy; then
      # 尝试使用分页器 -e 选项显示许可证文本
      if ! echo "\$licensetxt" | \$PAGER -e; then
        # 若失败，则直接使用分页器显示
        echo "\$licensetxt" | \$PAGER
      fi
    else
      # 若分页器不可用或用户已接受许可证，则直接打印许可证文本
      echo "\$licensetxt"
    fi
    # 如果用户未接受许可证，则提示用户输入是否接受
    if test x"\$accept" != xy; then
      while true
      do
        MS_Printf "请输入 y 接受许可证，输入 n 拒绝: "
        read yn
        if test x"\$yn" = xn; then
          keep=n
          eval \$finish; exit 1
          break;
        elif test x"\$yn" = xy; then
          break;
        fi
      done
    fi
  fi
}

# 获取指定目录可用磁盘空间的函数
MS_diskspace()
{
	(
	# 使用 df 命令获取磁盘信息，取最后一行，通过 awk 提取可用空间大小
	df -k "\$1" | tail -1 | awk '{ if (\$4 ~ /%/) {print \$3} else {print \$4} }'
	)
}

# 数据复制函数
MS_dd()
{
    # 计算块数
    blocks=\`expr \$3 / 1024\`
    # 计算剩余字节数
    bytes=\`expr \$3 % 1024\`
    # 测试 dd 命令是否支持 ibs, obs 和 conv 选项
    if dd if=/dev/zero of=/dev/null count=1 ibs=512 obs=512 conv=sync 2> /dev/null; then
        dd if="\$1" ibs=\$2 skip=1 obs=1024 conv=sync 2> /dev/null | \\
        { test \$blocks -gt 0 && dd ibs=1024 obs=1024 count=\$blocks ; \\
          test \$bytes  -gt 0 && dd ibs=1 obs=1024 count=\$bytes ; } 2> /dev/null
    else
        dd if="\$1" bs=\$2 skip=1 2> /dev/null
    fi
}

# 带进度显示的数据复制函数
MS_dd_Progress()
{
    # 如果不显示进度，则直接调用 MS_dd 函数
    if test x"\$noprogress" = xy; then
        MS_dd "\$@"
        return \$?
    fi
    # 定义源文件
    file="\$1"
    # 定义偏移量
    offset=\$2
    # 定义数据长度
    length=\$3
    # 初始化已处理位置
    pos=0
    # 初始化块大小
    bsize=4194304
    # 调整块大小，使其不超过数据长度
    while test \$bsize -gt \$length; do
        bsize=\`expr \$bsize / 4\`
    done
    # 计算块数
    blocks=\`expr \$length / \$bsize\`
    # 计算剩余字节数
    bytes=\`expr \$length % \$bsize\`
    (
        # 跳过指定偏移量的数据
        dd ibs=\$offset skip=1 count=1 2>/dev/null
        # 更新已处理位置
        pos=\`expr \$pos \+ \$bsize\`
        # 显示进度 0%
        MS_Printf "     0%% " 1>&2
        # 如果有块需要处理
        if test \$blocks -gt 0; then
            while test \$pos -le \$length; do
                # 复制一块数据
                dd bs=\$bsize count=1 2>/dev/null
                # 计算进度百分比
                pcent=\`expr \$length / 100\`
                pcent=\`expr \$pos / \$pcent\`
                if test \$pcent -lt 100; then
                    # 清除之前显示的进度信息
                    MS_Printf "\b\b\b\b\b\b\b" 1>&2
                    if test \$pcent -lt 10; then
                        # 显示个位数百分比进度
                        MS_Printf "    \$pcent%% " 1>&2
                    else
                        # 显示两位数百分比进度
                        MS_Printf "   \$pcent%% " 1>&2
                    fi
                fi
                # 更新已处理位置
                pos=\`expr \$pos \+ \$bsize\`
            done
        fi
        # 如果有剩余字节需要处理
        if test \$bytes -gt 0; then
            dd bs=\$bytes count=1 2>/dev/null
        fi
        # 清除之前显示的进度信息
        MS_Printf "\b\b\b\b\b\b\b" 1>&2
        # 显示进度 100%
        MS_Printf " 100%%  " 1>&2
    ) < "\$file"
}

# 显示帮助信息的函数
MS_Help()
{
    cat << EOH >&2
Makeself 版本 $MS_VERSION
1) 获取关于 \$0 的帮助或信息：
  \$0 --help   打印此帮助信息
  \$0 --info   打印嵌入信息：标题、默认目标目录、嵌入脚本等
  \$0 --lsm    打印嵌入的 lsm 条目（或提示无 LSM）
  \$0 --list   打印归档文件中的文件列表
  \$0 --check  检查归档文件的完整性
  \$0 --verify-sig key  根据提供的密钥 ID 验证签名
  \$0 --show-preextract  打印预提取脚本

2) 运行 \$0：
  \$0 [选项] [--] [嵌入脚本的附加参数]
  可用选项（按此顺序）：
  --confirm             在运行嵌入脚本前询问确认
  --quiet               除错误信息外不打印任何内容
  --accept              接受许可证
  --noexec              不运行嵌入脚本（隐含 --noexec-cleanup）
  --noexec-cleanup      不运行嵌入的清理脚本
  --keep                运行嵌入脚本后不删除目标目录
  --noprogress          解压缩过程中不显示进度
  --nox11               不启动 xterm 终端
  --nochown             不将目标文件夹所有权赋予当前用户
  --chown               递归地将目标文件夹所有权赋予当前用户
  --nodiskspace         不检查可用磁盘空间
  --target dir          直接提取到目标目录（绝对路径或相对路径）
                        此目录可能会进行递归所有权更改（见 --nochown）。
  --tar arg1 [arg2 ...] 通过 tar 命令访问归档文件的内容
  --ssl-pass-src src    使用给定的 src 作为 OpenSSL 解密数据的密码来源。
                        详见 man openssl 中的 "PASS PHRASE ARGUMENTS"。
                        默认会提示用户在当前终端输入解密密码。
  --cleanup-args args   清理脚本的参数。若有多个参数，请用引号括起来。
  --                    后续参数将传递给嵌入脚本${helpheader}

  环境变量：
      SETUP_NOCHECK
          若设置为 1，则跳过校验和验证。
EOH
}

# 验证签名的函数
MS_Verify_Sig()
{
    # 查找 gpg 命令的路径
    GPG_PATH=\`exec <&- 2>&-; which gpg || command -v gpg || type gpg\`
    # 查找 mktemp 命令的路径
    MKTEMP_PATH=\`exec <&- 2>&-; which mktemp || command -v mktemp || type mktemp\`
    test -x "\$GPG_PATH" || GPG_PATH=\`exec <&- 2>&-; which gpg || command -v gpg || type gpg\`
    test -x "\$MKTEMP_PATH" || MKTEMP_PATH=\`exec <&- 2>&-; which mktemp || command -v mktemp || type mktemp\`
    # 计算偏移量
	offset=\`head -n "\$skip" "\$1" | wc -c | sed "s/ //g"\`
    # 创建临时签名文件
    temp_sig=\`mktemp -t XXXXX\`
    # 解码签名信息并保存到临时文件
    echo \$SIGNATURE | base64 --decode > "\$temp_sig"
    # 验证签名并获取输出信息
    gpg_output=\`MS_dd "\$1" \$offset \$totalsize | LC_ALL=C "\$GPG_PATH" --verify "\$temp_sig" - 2>&1\`
    # 获取验证结果
    gpg_res=\$?
    # 删除临时签名文件
    rm -f "\$temp_sig"
    # 如果验证成功且签名有效
    if test \$gpg_res -eq 0 && test \`echo \$gpg_output | grep -c Good\` -eq 1; then
        # 如果签名密钥匹配
        if test \`echo \$gpg_output | grep -c \$sig_key\` -eq 1; then
            test x"\$quiet" = xn && echo "GPG 签名验证通过" >&2
        else
            echo "GPG 签名密钥不匹配" >&2
            exit 2
        fi
    else
        test x"\$quiet" = xn && echo "GPG 签名验证失败" >&2
        exit 2
    fi
}

# 检查归档文件完整性的函数
MS_Check()
{
    # 保存原始的 PATH 环境变量
    OLD_PATH="\$PATH"
    # 定义可能的 MD5 命令路径
    PATH=\${GUESS_MD5_PATH:-"\$OLD_PATH:/bin:/usr/bin:/sbin:/usr/local/ssl/bin:/usr/local/bin:/opt/openssl/bin"}
    # 初始化 MD5 命令参数
	MD5_ARG=""
    # 查找 md5sum 命令的路径
    MD5_PATH=\`exec <&- 2>&-; which md5sum || command -v md5sum || type md5sum\`
    # 若找不到 md5sum，则查找 md5 命令的路径
    test -x "\$MD5_PATH" || MD5_PATH=\`exec <&- 2>&-; which md5 || command -v md5 || type md5\`
    # 若找不到 md5，则查找 digest 命令的路径
    test -x "\$MD5_PATH" || MD5_PATH=\`exec <&- 2>&-; which digest || command -v digest || type digest\`
    # 恢复原始的 PATH 环境变量
    PATH="\$OLD_PATH"

    # 查找 shasum 命令的路径
    SHA_PATH=\`exec <&- 2>&-; which shasum || command -v shasum || type shasum\`
    # 若找不到 shasum，则查找 sha256sum 命令的路径
    test -x "\$SHA_PATH" || SHA_PATH=\`exec <&- 2>&-; which sha256sum || command -v sha256sum || type sha256sum\`

    # 如果不是安静模式，则提示正在验证归档文件完整性
    if test x"\$quiet" = xn; then
		MS_Printf "正在验证归档文件完整性..."
    fi
    # 计算偏移量
    offset=\`head -n "\$skip" "\$1" | wc -c | sed "s/ //g"\`
    # 获取文件总大小
    fsize=\`cat "\$1" | wc -c | sed "s/ //g"\`
    # 检查文件大小是否符合预期
    if test \$totalsize -ne \`expr \$fsize - \$offset\`; then
        echo " 归档文件大小异常。" >&2
        exit 2
    fi
    # 获取详细输出标志
    verb=\$2
    # 初始化文件索引
    i=1
    # 遍历文件大小列表
    for s in \$filesizes
    do
        # 获取当前文件的 CRC 校验和
		crc=\`echo \$CRCsum | cut -d" " -f\$i\`
		# 如果存在 SHA 校验命令
		if test -x "\$SHA_PATH"; then
			# 如果是 shasum 命令，则设置参数为 -a 256
			if test x"\`basename \$SHA_PATH\`" = xshasum; then
				SHA_ARG="-a 256"
			fi
			# 获取当前文件的 SHA 校验和
			sha=\`echo \$SHA | cut -d" " -f\$i\`
			# 如果 SHA 校验和为默认值，则提示未包含嵌入的 SHA256 校验和
			if test x"\$sha" = x0000000000000000000000000000000000000000000000000000000000000000; then
				test x"\$verb" = xy && echo " \$1 未包含嵌入的 SHA256 校验和。" >&2
			else
				# 计算当前文件的 SHA 校验和
				shasum=\`MS_dd_Progress "\$1" \$offset \$s | eval "\$SHA_PATH \$SHA_ARG" | cut -b-64\`;
				# 检查 SHA 校验和是否匹配
				if test x"\$shasum" != x"\$sha"; then
					echo "SHA256 校验和错误：\$shasum 与 \$sha 不一致" >&2
					exit 2
				elif test x"\$quiet" = xn; then
					MS_Printf " SHA256 校验和正确。" >&2
				fi
				# 标记 CRC 校验和为默认值
				crc="0000000000";
			fi
		fi
		# 如果存在 MD5 校验命令
		if test -x "\$MD5_PATH"; then
			# 如果是 digest 命令，则设置参数为 -a md5
			if test x"\`basename \$MD5_PATH\`" = xdigest; then
				MD5_ARG="-a md5"
			fi
			# 获取当前文件的 MD5 校验和
			md5=\`echo \$MD5 | cut -d" " -f\$i\`
			# 如果 MD5 校验和为默认值，则提示未包含嵌入的 MD5 校验和
			if test x"\$md5" = x00000000000000000000000000000000; then
				test x"\$verb" = xy && echo " \$1 未包含嵌入的 MD5 校验和。" >&2
			else
				# 计算当前文件的 MD5 校验和
				md5sum=\`MS_dd_Progress "\$1" \$offset \$s | eval "\$MD5_PATH \$MD5_ARG" | cut -b-32\`;
				# 检查 MD5 校验和是否匹配
				if test x"\$md5sum" != x"\$md5"; then
					echo "MD5 校验和错误：\$md5sum 与 \$md5 不一致" >&2
					exit 2
				elif test x"\$quiet" = xn; then
					MS_Printf " MD5 校验和正确。" >&2
				fi
				# 标记 CRC 校验和为默认值，设置详细输出标志为 n
				crc="0000000000"; verb=n
			fi
		fi
		# 如果 CRC 校验和为默认值，则提示未包含 CRC 校验和
		if test x"\$crc" = x0000000000; then
			test x"\$verb" = xy && echo " \$1 未包含 CRC 校验和。" >&2
		else
			# 计算当前文件的 CRC 校验和
			sum1=\`MS_dd_Progress "\$1" \$offset \$s | CMD_ENV=xpg4 cksum | awk '{print \$1}'\`
			# 检查 CRC 校验和是否匹配
			if test x"\$sum1" != x"\$crc"; then
				echo "校验和错误：\$sum1 与 \$crc 不一致" >&2
				exit 2
			elif test x"\$quiet" = xn; then
				MS_Printf " CRC 校验和正确。" >&2
			fi
		fi
		# 递增文件索引
		i=\`expr \$i + 1\`
		# 更新偏移量
		offset=\`expr \$offset + \$s\`
    done
    # 如果不是安静模式，则提示所有检查通过
    if test x"\$quiet" = xn; then
		echo " 一切正常。"
    fi
}

# 执行预提取脚本的函数
MS_Preextract()
{
    # 如果预提取脚本为空，则直接返回
    if test -z "\$preextract"; then
        return
    # 如果是详细模式，则提示用户是否执行预提取脚本
    elif test x"\$verbose" = xy; then
        MS_Printf "即将运行预提取脚本 ... 是否继续？[Y/n] "
        read yn
        if test x"\$yn" = xn; then
            eval \$finish; exit 1
        fi
    fi

    # 创建临时预提取脚本文件
    prescript=\`mktemp "\$tmpdir/XXXXXX"\`
    # 解码预提取脚本并保存到临时文件
    echo "\$preextract" | base64 -d > "\$prescript"
    # 给临时预提取脚本文件添加执行权限
    chmod a+x "\$prescript"

    # 在临时目录中执行预提取脚本，并获取返回值
    (cd "\$tmpdir"; eval "\"\$prescript\" \$scriptargs \"\\\$@\""); res=\$?

    # 删除临时预提取脚本文件
    rm -f "\$prescript"
    # 如果预提取脚本执行失败，则提示错误并退出
    if test \$res -ne 0; then
        echo "预提取脚本返回错误码 (\$res)" >&2
        eval \$finish; exit 1
    fi
}

# 解压缩函数
MS_Decompress()
{
    # 如果存在解密命令，则先执行解密再解压缩
    if test x"\$decrypt_cmd" != x""; then
        { eval "\$decrypt_cmd" || echo " ... 解密失败。" >&2; } | eval "$GUNZIP_CMD"
    else
        # 直接解压缩
        eval "$GUNZIP_CMD"
    fi
    
    # 如果解压缩失败，则提示错误信息
    if test \$? -ne 0; then
        echo " ... 解压缩失败。" >&2
    fi
}

# 解包函数
UnTAR()
{
    # 如果不是安静模式，则使用详细模式解包
    if test x"\$quiet" = xn; then
		tar \$1vf - $UNTAR_EXTRA 2>&1 || { echo " ... 解包失败。" >&2; kill -15 \$$; }
    else
		# 安静模式下解包
		tar \$1f - $UNTAR_EXTRA 2>&1 || { echo 解包失败。 >&2; kill -15 \$$; }
    fi
}

# 执行清理脚本的函数
MS_exec_cleanup() {
    # 如果需要清理且存在清理脚本
    if test x"\$cleanup" = xy && test x"\$cleanup_script" != x""; then
        # 标记为已清理
        cleanup=n
        # 切换到临时目录
        cd "\$tmpdir"
        # 执行清理脚本
        eval "\"\$cleanup_script\" \$scriptargs \$cleanupargs"
    fi
}

# 信号处理和清理函数
MS_cleanup()
{
    echo '捕获到信号，正在清理' >&2
    # 执行清理脚本
    MS_exec_cleanup
    # 切换到临时目录根路径
    cd "\$TMPROOT"
    # 删除临时目录
    rm -rf "\$tmpdir"
    # 执行结束操作并退出
    eval \$finish; exit 15
}

# 定义结束操作
finish=true
# 初始化 xterm 循环标志
xterm_loop=
# 初始化不显示进度标志
noprogress=$NOPROGRESS
# 初始化不启动 xterm 标志
nox11=$NOX11
# 初始化复制标志
copy=$COPY
# 初始化所有权标志
ownership=$OWNERSHIP
# 初始化详细模式标志
verbose=n
# 初始化清理标志
cleanup=y
# 初始化清理脚本参数
cleanupargs=
# 初始化签名密钥
sig_key=

# 保存初始参数
initargs="\$@"

# 循环处理命令行参数
while true
do
    case "\$1" in
    -h | --help)
        # 显示帮助信息并退出
	MS_Help
	exit 0
	;;
    -q | --quiet)
        # 设置为安静模式，不显示进度
	quiet=y
	noprogress=y
	shift
	;;
	--accept)
        # 接受许可证
	accept=y
	shift
	;;
    --info)
        # 显示归档文件信息并退出
	echo 标识信息: "\$label"
	echo 目标目录: "\$targetdir"
	echo 解压后大小: $USIZE KB
	echo 压缩方式: $COMPRESS
	if test x"$ENCRYPT" != x""; then
	    echo 加密方式: $ENCRYPT
	fi
	echo 打包日期: $DATE
	echo 使用 Makeself 版本 $MS_VERSION 构建
	echo 构建命令为: "$MS_COMMAND"
	if test x"\$script" != x; then
	    echo 提取后运行的脚本:
	    echo "    " \$script \$scriptargs
	fi
	if test x"$copy" = xcopy; then
		echo "归档文件将复制到临时位置"
	fi
	if test x"$NEED_ROOT" = xy; then
		echo "提取需要根权限"
	fi
	if test x"$KEEP" = xy; then
	    echo "目录 \$targetdir 是永久的"
	else
	    echo "\$targetdir 将在提取后删除"
	fi
	exit 0
	;;
    --dumpconf)
        # 显示配置信息并退出
	echo LABEL=\"\$label\"
	echo SCRIPT=\"\$script\"
	echo SCRIPTARGS=\"\$scriptargs\"
    echo CLEANUPSCRIPT=\"\$cleanup_script\"
	echo archdirname=\"$archdirname\"
	echo KEEP=$KEEP
	echo NOOVERWRITE=$NOOVERWRITE
	echo COMPRESS=$COMPRESS
	echo filesizes=\"\$filesizes\"
    echo totalsize=\"\$totalsize\"
	echo CRCsum=\"\$CRCsum\"
	echo MD5sum=\"\$MD5sum\"
	echo SHAsum=\"\$SHAsum\"
	echo SKIP=\"\$skip\"
	exit 0
	;;
    --lsm)
cat << EOLSM
EOF
eval "$LSM_CMD"
cat << EOF  >> "$archname"
EOLSM
	exit 0
	;;
    --list)
        # 显示目标目录并列出归档文件中的文件，然后退出
	echo 目标目录: \$targetdir
	offset=\`head -n "\$skip" "\$0" | wc -c | sed "s/ //g"\`
	for s in \$filesizes
	do
	    MS_dd "\$0" \$offset \$s | MS_Decompress | UnTAR t
	    offset=\`expr \$offset + \$s\`
	done
	exit 0
	;;
	--tar)
        # 通过 tar 命令访问归档文件内容并退出
	offset=\`head -n "\$skip" "\$0" | wc -c | sed "s/ //g"\`
	arg1="\$2"
    shift 2 || { MS_Help; exit 1; }
	for s in \$filesizes
	do
	    MS_dd "\$0" \$offset \$s | MS_Decompress | tar "\$arg1" - "\$@"
	    offset=\`expr \$offset + \$s\`
	done
	exit 0
	;;
    --check)
        # 检查归档文件完整性并退出
	MS_Check "\$0" y
	exit 0
	;;
    --verify-sig)
        # 设置签名密钥并验证签名
    sig_key="\$2"
    shift 2 || { MS_Help; exit 1; }
    MS_Verify_Sig "\$0"
    ;;
    --show-preextract)
        # 显示预提取脚本并退出，若不存在则提示错误
    if test -z "\$preextract"; then
        echo "未提供预提取脚本。" >&2
        exit 1
    fi
    echo "\$preextract" | base64 -d
    exit 0
    ;;
    --confirm)
        # 设置为详细模式
	verbose=y
	shift
	;;
	--noexec)
        # 不执行嵌入脚本和清理脚本，清空预提取脚本
	script=""
    cleanup_script=""
    preextract=""
	shift
	;;
    --noexec-cleanup)
        # 不执行清理脚本
    cleanup_script=""
    shift
    ;;
    --keep)
        # 保留目标目录
	keep=y
	shift
	;;
    --target)
        # 指定目标目录并保留
	keep=y
	targetdir="\${2:-.}"
    shift 2 || { MS_Help; exit 1; }
	;;
    --noprogress)
        # 不显示进度
	noprogress=y
	shift
	;;
    --nox11)
        # 不启动 xterm 终端
	nox11=y
	shift
	;;
    --nochown)
        # 不更改目标文件夹所有权
	ownership=n
	shift
	;;
    --chown)
        # 更改目标文件夹所有权
        ownership=y
        shift
        ;;
    --nodiskspace)
        # 不检查磁盘空间
	nodiskspace=y
	shift
	;;
    --xwin)
        # 设置结束操作并启动 xterm 循环
	if test "$NOWAIT" = n; then
		finish="echo 按回车键关闭此窗口...; read junk"
	fi
	xterm_loop=1
	shift
	;;
    --phase2)
        # 设置为第二阶段复制模式
	copy=phase2
	shift
	;;
	--ssl-pass-src)
        # 设置 OpenSSL 解密密码来源，若不支持则提示错误并退出
	if test x"$ENCRYPT" != x"openssl"; then
	    echo "无效选项 --ssl-pass-src: \$0 未使用 OpenSSL 加密！" >&2
	    exit 1
	fi
	decrypt_cmd="\$decrypt_cmd -pass \$2"
    shift 2 || { MS_Help; exit 1; }
	;;
    --cleanup-args)
        # 设置清理脚本参数
    cleanupargs="\$2"
    shift 2 || { MS_Help; exit 1; }
    ;;
    --)
        # 后续参数传递给嵌入脚本，跳出循环
	shift
	break ;;
    -*)
        # 未知选项，显示帮助信息并退出
	echo 未知标志 : "\$1" >&2
	MS_Help
	exit 1
	;;
    *)
        # 跳出循环
	break ;;
    esac
done

# 检查是否同时设置了安静模式和详细模式，若同时设置则提示错误并退出
if test x"\$quiet" = xy -a x"\$verbose" = xy; then
	echo 不能同时设置详细模式和安静模式。 >&2
	exit 1
fi

# 检查是否需要根权限，若需要但当前用户不是 root，则提示错误并退出
if test x"$NEED_ROOT" = xy -a \`id -u\` -ne 0; then
	echo "此归档文件需要管理员权限（请使用 su 或 sudo）" >&2
	exit 1	
fi

# 如果不是第二阶段复制模式，则显示并让用户确认许可证
if test x"\$copy" \!= xphase2; then
    MS_PrintLicense
fi

# 根据复制模式进行不同处理
case "\$copy" in
copy)
    # 创建临时目录
    tmpdir="\$TMPROOT"/makeself.\$RANDOM.\`date +"%y%m%d%H%M%S"\`.\$\$
    mkdir "\$tmpdir" || {
	echo "无法创建临时目录 \$tmpdir" >&2
	exit 1
    }
    # 定义复制后的脚本路径
    SCRIPT_COPY="\$tmpdir/makeself"
    echo "正在复制到临时位置..." >&2
    # 复制当前脚本到临时目录
    cp "\$0" "\$SCRIPT_COPY"
    # 给复制后的脚本添加执行权限
    chmod +x "\$SCRIPT_COPY"
    # 切换到临时目录根路径
    cd "\$TMPROOT"
    # 导出用户当前工作目录为临时目录
    export USER_PWD="\$tmpdir"
    # 以第二阶段模式执行复制后的脚本
    exec "\$SCRIPT_COPY" --phase2 -- \$initargs
    ;;
phase2)
    # 设置结束操作，删除临时目录
    finish="\$finish ; rm -rf \`dirname \$0\`"
    ;;
esac

# 如果不禁止启动 xterm 终端
if test x"\$nox11" = xn; then
    # 检查是否有终端连接到标准输出
    if test -t 1; then  # Do we have a terminal on stdout?
	:
    else
        # 如果没有终端连接到标准输出，但有 X 环境且未启动 xterm 循环
        if test x"\$DISPLAY" != x -a x"\$xterm_loop" = x; then  # No, but do we have X?
            # 检查 DISPLAY 变量是否有效
            if xset q > /dev/null 2>&1; then # Check for valid DISPLAY variable
                # 定义可能的 xterm 终端列表
                GUESS_XTERMS="xterm gnome-terminal rxvt dtterm eterm Eterm xfce4-terminal lxterminal kvt konsole aterm terminology"
                # 查找可用的 xterm 终端
                for a in \$GUESS_XTERMS; do
                    if type \$a >/dev/null 2>&1; then
                        XTERM=\$a
                        break
                    fi
                done
                # 给当前脚本添加执行权限，若失败则提示用户添加
                chmod a+x \$0 || echo 请给 \$0 添加执行权限 >&2
                # 根据脚本路径启动 xterm 终端并执行脚本
                if test \`echo "\$0" | cut -c1\` = "/"; then # Spawn a terminal!
                    exec \$XTERM -e "\$0 --xwin \$initargs"
                else
                    exec \$XTERM -e "./\$0 --xwin \$initargs"
                fi
            fi
        fi
    fi
fi

# 如果目标目录为当前目录，则临时目录为当前目录
if test x"\$targetdir" = x.; then
    tmpdir="."
else
    # 如果需要保留目标目录
    if test x"\$keep" = xy; then
        # 如果不允许覆盖且目标目录已存在，则提示错误并退出
        if test x"\$nooverwrite" = xy && test -d "\$targetdir"; then
            echo "目标目录 \$targetdir 已存在，操作中止。" >&2
            exit 1
        fi
        # 如果不是安静模式，则提示正在创建目标目录
        if test x"\$quiet" = xn; then
            echo "正在创建目录 \$targetdir" >&2
        fi
        # 临时目录为目标目录
        tmpdir="\$targetdir"
        # 创建目录时使用 -p 选项
        dashp="-p"
    else
        # 临时目录为随机生成的目录
        tmpdir="\$TMPROOT/selfgz\$\$\$RANDOM"
        dashp=""
    fi
    # 创建临时目录，若失败则提示错误并退出
    mkdir \$dashp "\$tmpdir" || {
        echo '无法创建目标目录' \$tmpdir >&2
        echo '你可以尝试使用 --target dir 选项' >&2
        eval \$finish
        exit 1
    }
fi

# 保存当前工作目录
location="\`pwd\`"
# 如果未设置跳过校验和验证，则检查归档文件完整性
if test x"\$SETUP_NOCHECK" != x1; then
    MS_Check "\$0"
fi
# 计算偏移量
offset=\`head -n "\$skip" "\$0" | wc -c | sed "s/ //g"\`

# 执行预提取脚本
MS_Preextract "\$@"

# 如果是详细模式，则提示用户是否进行提取操作
if test x"\$verbose" = xy; then
    MS_Printf "即将在 \$tmpdir 中提取 $USIZE KB ... 是否继续？[Y/n] "
    read yn
    if test x"\$yn" = xn; then
        eval \$finish; exit 1
    fi
fi

# 如果不是安静模式，则提示正在解压缩或解密并解压缩
if test x"\$quiet" = xn; then
    # 解密时需要在新行提示输入密码
    if test x"$ENCRYPT" = x"openssl"; then
        echo "正在解密并解压缩 \$label..."
    else
        MS_Printf "正在解压缩 \$label"
    fi
fi
# 初始化结果状态码
res=3
# 如果不保留目标目录，则设置信号处理函数
if test x"\$keep" = xn; then
    trap MS_cleanup 1 2 3 15
fi

# 如果需要检查磁盘空间
if test x"\$nodiskspace" = xn; then
    # 获取目标目录可用磁盘空间
    leftspace=\`MS_diskspace "\$tmpdir"\`
    if test -n "\$leftspace"; then
        # 检查可用空间是否足够
        if test "\$leftspace" -lt $USIZE; then
            echo
            echo "在 "\`dirname \$tmpdir\`" 中剩余空间不足 (\$leftspace KB)，无法解压缩 \$0 ($USIZE KB)" >&2
            echo "可使用 --nodiskspace 选项跳过此检查并继续操作" >&2
            if test x"\$keep" = xn; then
                echo "建议将 TMPDIR 设置为有更多可用空间的目录。"
            fi
            eval \$finish; exit 1
        fi
    fi
fi

# 遍历文件大小列表，进行解压缩和提取操作
for s in \$filesizes
do
    if MS_dd_Progress "\$0" \$offset \$s | MS_Decompress | ( cd "\$tmpdir"; umask \$ORIG_UMASK ; UnTAR xp ) 1>/dev/null; then
        # 如果需要更改目标文件夹所有权，则递归更改
        if test x"\$ownership" = xy; then
            (cd "\$tmpdir"; chown -R \`id -u\` .;  chgrp -R \`id -g\` .)
        fi
    else
        echo >&2
        echo "无法解压缩 \$0" >&2
        eval \$finish; exit 1
    fi
    # 更新偏移量
    offset=\`expr \$offset + \$s\`
done
# 如果不是安静模式，则输出空行
if test x"\$quiet" = xn; then
    echo
fi

# 切换到临时目录
cd "\$tmpdir"
# 初始化结果状态码为 0
res=0
# 如果存在嵌入脚本
if test x"\$script" != x; then
    # 如果需要导出配置信息
    if test x"\$export_conf" = x"y"; then
        MS_BUNDLE="\$0"
        MS_LABEL="\$label"
        MS_SCRIPT="\$script"
        MS_SCRIPTARGS="\$scriptargs"
        MS_ARCHDIRNAME="\$archdirname"
        MS_KEEP="\$KEEP"
        MS_NOOVERWRITE="\$NOOVERWRITE"
        MS_COMPRESS="\$COMPRESS"
        MS_CLEANUP="\$cleanup"
        export MS_BUNDLE MS_LABEL MS_SCRIPT MS_SCRIPTARGS
        export MS_ARCHDIRNAME MS_KEEP MS_NOOVERWRITE MS_COMPRESS
    fi

    # 如果是详细模式，则提示用户是否执行嵌入脚本
    if test x"\$verbose" = x"y"; then
        MS_Printf "是否执行: \$script \$scriptargs \$* ？[Y/n] "
        read yn
        if test x"\$yn" = x -o x"\$yn" = xy -o x"\$yn" = xY; then
            # 执行嵌入脚本并获取返回值
            eval "\"\$script\" \$scriptargs \"\\\$@\""; res=\$?;
        fi
    else
        # 直接执行嵌入脚本并获取返回值
        eval "\"\$script\" \$scriptargs \"\\\$@\""; res=\$?
    fi
    # 如果嵌入脚本执行失败，则提示错误信息
    if test "\$res" -ne 0; then
        test x"\$verbose" = xy && echo "程序 '\$script' 返回错误码 (\$res)" >&2
    fi
fi

# 执行清理脚本
MS_exec_cleanup

# 如果不保留目标目录，则删除临时目录
if test x"\$keep" = xn; then
    cd "\$TMPROOT"
    rm -rf "\$tmpdir"
fi
# 执行结束操作并退出
eval \$finish; exit \$res
EOF
