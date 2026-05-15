#!/bin/bash

pause_script() {
    echo

    if [ -r /dev/tty ]; then
        read -n 1 -s -r -p "Нажмите любую клавишу для продолжения..." < /dev/tty
    else
        read -n 1 -s -r -p "Нажмите любую клавишу для продолжения..."
    fi

    echo
    echo
}

echo "=== Имя устройства ==="
hostname
echo


echo
echo "=== Проверка интернета через ping до ya.ru ==="
echo

ping -c 2 ya.ru

echo
echo "=== Сетевые интерфейсы и IP-адреса ==="
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

echo "=== Часовой пояс ==="
timedatectl
echo


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
            echo "Содержимое баннера:"
            cat $ssh_banner
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
    pause_script
    echo
    echo "=== Конфигурация OSPF ==="
    echo

    ospf_config=$(vtysh -c "show running-config" 2>/dev/null)

    if [ -n "$ospf_config" ]; then
        echo "$ospf_config"
    else
        echo "Конфигурация router ospf не найдена."
    fi
    pause_script
    echo
    echo "=== Соседи OSPF ==="
    echo

    ospf_neighbors=$(vtysh -c "show ip ospf neighbor" 2>/dev/null)

    if [ -n "$ospf_neighbors" ]; then
        echo "$ospf_neighbors"
    else
        echo "OSPF-соседи не найдены."
    fi
    pause_script
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

pause_script

echo
echo "=== Проверка DHCP-сервера ==="
echo

dhcp_installed=0

if command -v dhcpd >/dev/null 2>&1; then
    dhcp_installed=1
fi

if command -v rpm >/dev/null 2>&1; then
    if rpm -q dhcp-server >/dev/null 2>&1; then
        dhcp_installed=1
    fi
fi

if [ "$dhcp_installed" -eq 0 ]; then
    echo "DHCP-сервер: не установлен"
else
    echo "DHCP-сервер: установлен"
    echo

    echo "=== Файл dhcpd.conf ==="
    echo

    dhcp_config=""

    if [ -f /etc/dhcp/dhcpd.conf ]; then
        dhcp_config="/etc/dhcp/dhcpd.conf"
    elif [ -f /etc/dhcpd.conf ]; then
        dhcp_config="/etc/dhcpd.conf"
    fi

    if [ -n "$dhcp_config" ]; then
        echo "Файл конфигурации: $dhcp_config"
        echo
        echo "-----------------------------------"
        echo

        cat "$dhcp_config"

        echo
        echo "-----------------------------------"
    else
        echo "Файл dhcpd.conf не найден."
        echo "Проверялись:"
        echo "/etc/dhcp/dhcpd.conf"
        echo "/etc/dhcpd.conf"
    fi
fi

pause_script

#DNS

echo
echo "=== Проверка DNS-сервера BIND ==="
echo

dns_installed=0

if command -v named >/dev/null 2>&1; then
    dns_installed=1
fi

if command -v named-checkconf >/dev/null 2>&1; then
    dns_installed=1
fi

if command -v rpm >/dev/null 2>&1; then
    if rpm -q bind >/dev/null 2>&1; then
        dns_installed=1
    fi
fi

if [ "$dns_installed" -eq 0 ]; then
    echo "DNS-сервер BIND/named: не установлен"
    echo "Проверка DNS завершена."
else
    echo "DNS-сервер BIND/named: установлен"
    echo

    echo "=== Состояние службы DNS ==="
    echo

    dns_service=""

    if command -v systemctl >/dev/null 2>&1; then
        if systemctl list-unit-files 2>/dev/null | grep -q '^named\.service'; then
            dns_service="named"
        elif systemctl list-unit-files 2>/dev/null | grep -q '^bind\.service'; then
            dns_service="bind"
        elif systemctl list-unit-files 2>/dev/null | grep -q '^bind9\.service'; then
            dns_service="bind9"
        fi

        if [ -n "$dns_service" ]; then
            if systemctl is-active --quiet "$dns_service"; then
                echo "Служба DNS: работает"
            else
                echo "Служба DNS: не работает"
            fi
        else
            echo "Служба named/bind/bind9 не найдена в systemd."
        fi
    else
        echo "systemctl не найден. Невозможно проверить службу DNS."
    fi

    echo
    echo "=== Конфигурация DNS ==="
    echo

    dns_config=""

    if [ -f /etc/named.conf ]; then
        dns_config="/etc/named.conf"
    elif [ -f /etc/bind/named.conf ]; then
        dns_config="/etc/bind/named.conf"
    fi

    if [ -z "$dns_config" ]; then
        echo "Основной файл named.conf не найден."
        echo "Проверялись:"
        echo "/etc/named.conf"
        echo "/etc/bind/named.conf"
    else
        echo "Основной конфигурационный файл: $dns_config"
        echo

        if command -v named-checkconf >/dev/null 2>&1; then
            echo "Проверка синтаксиса named.conf:"

            if named-checkconf "$dns_config" >/dev/null 2>&1; then
                echo "Синтаксис конфигурации: ошибок не найдено"
            else
                echo "Синтаксис конфигурации: есть ошибки"
                named-checkconf "$dns_config" 2>&1
            fi
        else
            echo "named-checkconf не найден. Проверка синтаксиса пропущена."
        fi

        echo
        echo "=== DNS-зоны ==="
        echo

        temp_dns_file=$(mktemp)
        temp_zones_file=$(mktemp)

        {
            cat "$dns_config" 2>/dev/null

            grep -E '^[[:space:]]*include[[:space:]]+"' "$dns_config" 2>/dev/null | while IFS= read -r include_line; do
                include_path=$(echo "$include_line" | sed -n 's/.*include[[:space:]]*"\([^"]*\)".*/\1/p')

                if [ -n "$include_path" ]; then
                    for included_file in $include_path; do
                        if [ -f "$included_file" ]; then
                            cat "$included_file" 2>/dev/null
                        fi
                    done
                fi
            done
        } > "$temp_dns_file"

        awk '
            function is_standard_zone(name, file) {
                if (name == ".") return 1
                if (name == "localhost") return 1
                if (name == "localhost.localdomain") return 1
                if (name == "localdomain") return 1

                if (name == "0.0.127.in-addr.arpa") return 1
                if (name == "1.0.0.127.in-addr.arpa") return 1
                if (name == "127.in-addr.arpa") return 1
                if (name == "0.in-addr.arpa") return 1
                if (name == "255.in-addr.arpa") return 1

                if (name == "1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.ip6.arpa") return 1

                if (file == "named.localhost") return 1
                if (file == "named.loopback") return 1
                if (file == "named.empty") return 1

                return 0
            }

            /^[[:space:]]*zone[[:space:]]+"/ {
                in_zone=1
                zone_block=$0 "\n"

                zone_name=$0
                gsub(/^[[:space:]]*zone[[:space:]]+"/, "", zone_name)
                gsub(/".*/, "", zone_name)

                zone_file=""
                next
            }

            in_zone == 1 {
                zone_block = zone_block $0 "\n"

                if ($0 ~ /^[[:space:]]*file[[:space:]]+"/) {
                    zone_file=$0
                    gsub(/^[[:space:]]*file[[:space:]]*"/, "", zone_file)
                    gsub(/".*/, "", zone_file)
                }

                if ($0 ~ /^[[:space:]]*};/) {
                    if (is_standard_zone(zone_name, zone_file) == 0) {
                        print "###ZONE_START###"
                        print "ZONE_NAME=" zone_name
                        print "ZONE_FILE=" zone_file
                        print "ZONE_BLOCK_START"
                        printf "%s", zone_block
                        print "ZONE_BLOCK_END"
                        print "###ZONE_END###"
                    }

                    in_zone=0
                    zone_name=""
                    zone_file=""
                    zone_block=""
                }
            }
        ' "$temp_dns_file" > "$temp_zones_file"

        zone_count=$(grep -c '^###ZONE_START###' "$temp_zones_file")

        if [ "$zone_count" -eq 0 ]; then
            echo "Пользовательские DNS-зоны не найдены."
        else
            echo "Найдено пользовательских зон: $zone_count"
            echo

            current_zone_number=0

            while IFS= read -r line; do
                if [ "$line" = "###ZONE_START###" ]; then
                    zone_name=""
                    zone_file=""
                    zone_block=""
                    in_zone_block=0
                    continue
                fi

                if echo "$line" | grep -q '^ZONE_NAME='; then
                    zone_name=$(echo "$line" | sed 's/^ZONE_NAME=//')
                    continue
                fi

                if echo "$line" | grep -q '^ZONE_FILE='; then
                    zone_file=$(echo "$line" | sed 's/^ZONE_FILE=//')
                    continue
                fi

                if [ "$line" = "ZONE_BLOCK_START" ]; then
                    in_zone_block=1
                    continue
                fi

                if [ "$line" = "ZONE_BLOCK_END" ]; then
                    in_zone_block=0
                    continue
                fi

                if [ "$line" = "###ZONE_END###" ]; then
                    current_zone_number=$((current_zone_number + 1))

                    echo
                    echo "========================================"
                    echo "Зона $current_zone_number из $zone_count"
                    echo "========================================"
                    echo

                    echo "Зона: $zone_name"

                    if echo "$zone_name" | grep -qE 'in-addr\.arpa$|ip6\.arpa$'; then
                        echo "Тип зоны: обратная"
                    else
                        echo "Тип зоны: прямая"
                    fi

                    echo "Файл зоны: ${zone_file:-не указан}"
                    echo

                    echo "=== Параметры зоны из named.conf ==="
                    echo
                    printf "%b" "$zone_block"

                    echo
                    echo "=== Внутренние записи зоны ==="
                    echo

                    full_zone_path=""

                    if [ -n "$zone_file" ]; then
                        if [[ "$zone_file" = /* ]]; then
                            full_zone_path="$zone_file"
                        else
                            if [ -d /var/named ]; then
                                full_zone_path="/var/named/$zone_file"
                            elif [ -d /var/cache/bind ]; then
                                full_zone_path="/var/cache/bind/$zone_file"
                            else
                                full_zone_path="$zone_file"
                            fi
                        fi
                    fi

                    if [ -n "$full_zone_path" ] && [ -f "$full_zone_path" ]; then
                        echo "Путь к файлу зоны: $full_zone_path"
                        echo
                        echo "----- НАЧАЛО ЗАПИСЕЙ ЗОНЫ -----"
                        echo

                        grep -vE '^[[:space:]]*$' "$full_zone_path" | grep -vE '^[[:space:]]*;'

                        echo
                        echo "----- КОНЕЦ ЗАПИСЕЙ ЗОНЫ -----"

                        if command -v named-checkzone >/dev/null 2>&1; then
                            echo
                            echo "Проверка зоны:"
                            named-checkzone "$zone_name" "$full_zone_path" 2>&1
                            pause_script
                        fi
                    else
                        echo "Файл зоны не найден или не указан."
                    fi
                fi

                if [ "$in_zone_block" -eq 1 ]; then
                    zone_block="${zone_block}${line}\n"
                fi

            done < "$temp_zones_file"
        fi

        rm -f "$temp_dns_file" "$temp_zones_file"
    fi
    
fi

