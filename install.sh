#!/bin/bash

# 默认帮助信息
show_help() {
    echo "用法: $0 [选项]"
    echo "选项:"
    echo "  -c        安装中文版本到/usr/bin/"
    echo "  -e        安装英文版本到/usr/bin/"
    echo "  -p <路径> 指定安装路径"
    echo "  -h        显示此帮助信息"
}

# 检查参数
if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

# 初始化变量
install_path="/usr/bin"
script_path=""

# 解析参数
while getopts "ce:p:h" opt; do
    case $opt in
        c)
            script_path="CN/makeself.sh"
            header_path="CN/makeself-header.sh"
            ;;
        e)
            script_path="EN/makeself.sh"
            header_path="EN/makeself-header.sh"
            ;;
        p)
            install_path="$OPTARG"
            ;;
        h)
            show_help
            exit 0
            ;;
        *)
            echo "无效选项"
            show_help
            exit 1
            ;;
    esac
done

# 检查是否选择了脚本
if [ -z "$script_path" ]; then
    echo "错误: 必须指定 -c 或 -e 选项"
    show_help
    exit 1
fi

# 检查脚本是否存在
if [ ! -f "$script_path" ]; then
    echo "错误: 找不到脚本文件 $script_path"
    exit 1
fi

# 检查是否已安装
if command -v makeself.sh >/dev/null 2>&1 || command -v makeself-header.sh >/dev/null 2>&1; then
    echo "错误: makeself.sh 或 makeself-header.sh 已存在于系统PATH中"
    exit 1
fi

# 安装逻辑
chmod +x "$script_path"
chmod +x "$header_path"
cp "$script_path" "$install_path"
cp "$header_path" "$install_path"

# 检查安装是否成功
if [ $? -eq 0 ]; then
    echo "安装成功: $script_path 和 $header_path 已安装到 $install_path"
else
    echo "安装失败: 请检查权限或路径"
    exit 1
fi