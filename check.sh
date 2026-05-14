#!/bin/bash

pause_script() {
    echo
    read -n 1 -s -r -p "Нажмите любую клавишу для продолжения..."
    echo
    echo
}


echo "Имя устройства:"
hostname
echo


echo
echo "Проверка интернета через ping до ya.ru"
echo

ping -c 2 ya.ru

echo
echo "Сетевые интерфейсы и IP-адреса:"
echo

ip -o -4 addr show | awk '{print "Интерфейс: " $2 "\nIP-адрес/маска: " $4 "\n"}'

pause_script

echo
echo "=== Созданные пользователи на устройстве ==="
echo

printf "%-25s %-10s %-10s\n" "Пользователь" "UID" "GID"
printf "%-25s %-10s %-10s\n" "------------" "---" "---"

awk -F: '
$3 >= 1000 && $3 < 65534 {
    printf "%-25s %-10s %-10s\n", $1, $3, $4
}
' /etc/passwd

echo
echo "=== Строки sudoers для пользователей ==="
echo

printf "%-25s %-10s %-10s %s\n" "Пользователь" "UID" "GID" "Строка sudoers"
printf "%-25s %-10s %-10s %s\n" "------------" "---" "---" "--------------"

get_sudoers_line() {
    local checked_user
    checked_user="$1"

    local result

    result=$(
        {
            if [ -r /etc/sudoers ]; then
                grep -E "^[[:space:]]*${checked_user}[[:space:]]+" /etc/sudoers 2>/dev/null
            fi

            if [ -d /etc/sudoers.d ]; then
                grep -R -h -E "^[[:space:]]*${checked_user}[[:space:]]+" /etc/sudoers.d/ 2>/dev/null
            fi
        } | grep -vE "^[[:space:]]*#" | head -n 1
    )

    if [ -n "$result" ]; then
        echo "$result"
    else
        echo "строка не найдена"
    fi
}

while IFS=: read -r login_name passwd_field user_id group_id user_comment home_dir user_shell; do
    if [ "$user_id" -ge 1000 ] && [ "$user_id" -lt 65534 ]; then
        sudoers_line=$(get_sudoers_line "$login_name")
        printf "%-25s %-10s %-10s %s\n" "$login_name" "$user_id" "$group_id" "$sudoers_line"
    fi
done < /etc/passwd

pause_script

echo
echo "=== Параметры SSH ==="
echo

if command -v sshd >/dev/null 2>&1; then

    ssh_config=$(sshd -T 2>/dev/null)

    if [ -n "$ssh_config" ]; then

        ssh_port=$(echo "$ssh_config" | awk '$1 == "port" {print $2}')
        ssh_banner=$(echo "$ssh_config" | awk '$1 == "banner" {print $2}')
        ssh_allow_users=$(echo "$ssh_config" | awk '$1 == "allowusers" {$1=""; sub(/^ /, ""); print}')

        echo "Порт SSH: ${ssh_port:-не найден}"

        if [ -n "$ssh_banner" ] && [ "$ssh_banner" != "none" ]; then
            echo "Баннер SSH: есть"
            echo "Файл баннера: $ssh_banner"
        else
            echo "Баннер SSH: не задан"
        fi

        if [ -n "$ssh_allow_users" ]; then
            echo "AllowUsers: задан"
            echo "Значение AllowUsers: $ssh_allow_users"
        else
            echo "AllowUsers: не задан"
        fi

    else
        echo "Не удалось получить параметры sshd."
        echo "Попробуйте запустить скрипт через sudo:"
        echo "sudo bash $0"
    fi

else
    echo "sshd не найден. Возможно, OpenSSH Server не установлен."
fi

echo
echo "=== SELinux ==="
echo

if command -v getenforce >/dev/null 2>&1; then
    selinux_mode=$(getenforce)
    echo "Текущий режим SELinux: $selinux_mode"
else
    echo "getenforce не найден. Возможно, SELinux не установлен или отключён."
fi

if [ -f /etc/selinux/config ]; then
    selinux_config_mode=$(grep -E '^SELINUX=' /etc/selinux/config | cut -d= -f2)
    echo "Режим SELinux в конфигурации: ${selinux_config_mode:-не найден}"
else
    echo "Файл /etc/selinux/config не найден"
fi

pause_script

echo
echo "=== Информация о туннелях IPv4 ==="
echo

if command -v ip >/dev/null 2>&1; then

    tunnel_list=$(ip tunnel show 2>/dev/null)

    if [ -n "$tunnel_list" ]; then

        echo "$tunnel_list" | while IFS= read -r tunnel_line; do

            tunnel_name=$(echo "$tunnel_line" | awk -F: '{print $1}')
            tunnel_params=$(echo "$tunnel_line" | cut -d: -f2-)

            tunnel_mode=$(echo "$tunnel_params" | awk '
                {
                    for (i = 1; i <= NF; i++) {
                        if ($i == "mode") {
                            print $(i+1)
                            exit
                        }
                    }
                }
            ')

            tunnel_parent=$(echo "$tunnel_params" | awk '
                {
                    for (i = 1; i <= NF; i++) {
                        if ($i == "dev") {
                            print $(i+1)
                            exit
                        }
                    }
                }
            ')

            tunnel_local=$(echo "$tunnel_params" | awk '
                {
                    for (i = 1; i <= NF; i++) {
                        if ($i == "local") {
                            print $(i+1)
                            exit
                        }
                    }
                }
            ')

            tunnel_remote=$(echo "$tunnel_params" | awk '
                {
                    for (i = 1; i <= NF; i++) {
                        if ($i == "remote") {
                            print $(i+1)
                            exit
                        }
                    }
                }
            ')

            tunnel_ipv4=$(ip -o -4 addr show dev "$tunnel_name" 2>/dev/null | awk '{print $4}' | paste -sd ", " -)

            echo "Туннель: $tunnel_name"
            echo "Родительский интерфейс: ${tunnel_parent:-не указан}"
            echo "Локальный IP: ${tunnel_local:-не указан}"
            echo "Удаленный IP: ${tunnel_remote:-не указан}"
            echo "Конфигурация IPv4: ${tunnel_ipv4:-IPv4-адрес не назначен}"
            echo

        done

    else
        echo "IPv4-туннели не найдены."
    fi

else
    echo "Команда ip не найдена."
fi


pause_script

echo
echo "=== Проверка FRR OSPF ==="
echo

if ! command -v vtysh >/dev/null 2>&1; then
    echo "FRR: не установлен"
    echo "Проверка FRR OSPF завершена."
else
    echo "FRR: установлен"
    echo

    echo "=== Состояние службы FRR ==="
    echo

    if command -v systemctl >/dev/null 2>&1; then
        if systemctl is-active --quiet frr; then
            echo "Служба FRR: работает"
        else
            echo "Служба FRR: не работает"
        fi
    else
        echo "systemctl не найден. Невозможно проверить службу FRR."
    fi

    echo
    echo "=== Проверка демона ospfd ==="
    echo

    if [ -f /etc/frr/daemons ]; then
        ospfd_status=$(grep -E '^ospfd=' /etc/frr/daemons | cut -d= -f2)

        if [ "$ospfd_status" = "yes" ]; then
            echo "ospfd: включен"
        else
            echo "ospfd: не включен"
            echo "Проверка OSPF завершена."
            return 2>/dev/null || true
        fi
    else
        echo "Файл /etc/frr/daemons не найден"
        echo "Проверка OSPF завершена."
        return 2>/dev/null || true
    fi

    echo
    echo "=== Конфигурация OSPF ==="
    echo

    ospf_config=$(vtysh -c "show running-config" 2>/dev/null | awk '
        /^router ospf/ {show=1}
        show==1 {print}
        show==1 && /^!/ {show=0}
    ')

    if [ -n "$ospf_config" ]; then
        echo "$ospf_config"
    else
        echo "Конфигурация router ospf не найдена."
    fi

    echo
    echo "=== Интерфейсы OSPF ==="
    echo

    ospf_interface=$(vtysh -c "show ip ospf interface" 2>/dev/null)

    if [ -n "$ospf_interface" ]; then
        echo "$ospf_interface"
    else
        echo "Интерфейсы OSPF не найдены или OSPF не настроен."
    fi

    echo
    echo "=== Соседи OSPF ==="
    echo

    ospf_neighbors=$(vtysh -c "show ip ospf neighbor" 2>/dev/null)

    if [ -n "$ospf_neighbors" ]; then
        echo "$ospf_neighbors"
    else
        echo "OSPF-соседи не найдены."
    fi

    echo
    echo "=== Маршруты OSPF ==="
    echo

    ospf_routes=$(vtysh -c "show ip route ospf" 2>/dev/null)

    if [ -n "$ospf_routes" ]; then
        echo "$ospf_routes"
    else
        echo "OSPF-маршруты не найдены."
    fi


fi



