# makeself-x

一个用于创建自解压安装脚本的工具，支持中英文版本。

本项目分支来自 [megastep/makeself](https://github.com/megastep/makeself.git)

## 功能特性

- 生成自解压的shell脚本归档文件
- 支持中英文双语界面
- 提供进度显示和完整性校验
- 灵活的安装选项配置

## 安装方法

使用install.sh脚本进行安装：

```bash
# 安装中文版本
./install.sh -cn

# 安装英文版本
./install.sh -en

# 自定义安装路径
./install.sh -cn -p /custom/path
```

## 使用方法

1. 准备要打包的文件目录
2. 运行makeself.sh脚本生成自解压包：

```bash
./makeself.sh [选项] 源目录 输出文件名 "描述信息" 启动脚本
```

常用选项：
- --help 显示帮助信息
- --version 显示版本信息
- --gzip 使用gzip压缩
- --bzip2 使用bzip2压缩

## 项目结构

- CN/ 中文版本脚本
- EN/ 英文版本脚本
- install.sh 安装脚本

## 贡献指南

欢迎提交Pull Request或Issue报告问题。

## 许可证

GPL v3