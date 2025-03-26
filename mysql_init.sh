#!/bin/bash

# 检查是否以root权限运行
if [ "$EUID" -ne 0 ]; then 
    echo "请使用root权限运行此脚本"
    exit 1
fi

# 检查MySQL是否已安装
check_mysql_installed() {
    if command -v mysql &> /dev/null; then
        echo "MySQL已经安装"
        return 0
    else
        echo "MySQL未安装"
        return 1
    fi
}

# 安装MySQL
install_mysql() {
    echo "开始安装MySQL..."
    if command -v apt &> /dev/null; then
        # Debian/Ubuntu系统
        apt update
        apt install -y mysql-server
    elif command -v yum &> /dev/null; then
        # CentOS/RHEL系统
        yum update
        yum install -y mysql-server
    else
        echo "不支持的Linux发行版"
        exit 1
    fi
}

# 检查MySQL服务状态
check_mysql_service() {
    if systemctl is-active mysql &> /dev/null; then
        echo "MySQL服务已运行"
        return 0
    else
        echo "MySQL服务未运行"
        return 1
    fi
}

# 启动MySQL服务
start_mysql_service() {
    echo "正在启动MySQL服务..."
    systemctl start mysql
    systemctl enable mysql
}

# 主程序
echo "MySQL一键配置脚本开始运行..."

# 检查MySQL是否安装
if ! check_mysql_installed; then
    install_mysql
fi

# 检查服务状态
if ! check_mysql_service; then
    start_mysql_service
fi

# 运行安全配置向导
echo "开始运行MySQL安全配置向导..."

echo "是否要设置MySQL root密码？[Y/n]:"

echo "是否删除匿名用户？建议删除以提高安全性 [Y/n]:"

echo "是否禁止root用户远程登录？建议禁止以提高安全性 [Y/n]:"
 
echo "是否删除测试数据库？建议删除以提高安全性 [Y/n]:"

echo "是否现在刷新权限? [Y/n]:"

mysql_secure_installation

# 检查MySQL root密码是否设置
echo "正在检查MySQL root密码状态..."
if mysql -u root -e "SELECT 1" &> /dev/null; then
    echo "警告：MySQL root用户当前没有密码！"
    echo "请输入新的root密码："
    read -s root_password
    echo
    
    # 设置新密码
    mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$root_password';"
    if [ $? -eq 0 ]; then
        echo "MySQL root密码设置成功！"
    else
        echo "MySQL root密码设置失败，请手动检查。"
        exit 1
    fi
else
    echo "MySQL root密码已经正确设置。"
fi

# 询问是否创建外网访问用户
echo -n "是否需要创建一个用于外网访问的用户？[Y/n]: "
read create_remote_user

if [[ $create_remote_user =~ ^[Yy]$ || $create_remote_user == "" ]]; then
    # 获取用户名
    while true; do
        echo -n "请输入新用户名: "
        read remote_username
        if [[ -n "$remote_username" ]]; then
            break
        else
            echo "用户名不能为空，请重新输入"
        fi
    done

    # 获取密码
    echo "请输入新用户密码: "
    read -s remote_password
    echo

    # 创建用户并授权
    mysql -u root -p"$root_password" -e "CREATE USER '$remote_username'@'%' IDENTIFIED BY '$remote_password';"
    if [ $? -eq 0 ]; then
        # 授予基本权限（可根据需要调整）
        mysql -u root -p"$root_password" -e "GRANT SELECT, INSERT, UPDATE, DELETE ON *.* TO '$remote_username'@'%';"
        mysql -u root -p"$root_password" -e "FLUSH PRIVILEGES;"
        echo "外网访问用户 '$remote_username' 创建成功！"
        echo "该用户可以从任何IP地址连接到数据库"
    else
        echo "用户创建失败，请检查后重试"
        exit 1
    fi
else
    echo "跳过创建外网访问用户"
fi

echo "MySQL配置完成！"