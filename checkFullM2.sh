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


echo
echo "=== Проверка настройки домена ==="
echo


echo "=== Имя домена ==="
echo

domain_name=""

if command -v realm >/dev/null 2>&1; then
    domain_name=$(realm list 2>/dev/null | awk -F: '/realm-name/ {gsub(/^[ \t]+/, "", $2); print $2; exit}')
fi

if [ -z "$domain_name" ]; then
    domain_name=$(hostname -d 2>/dev/null)
fi

if [ -z "$domain_name" ] && command -v dnsdomainname >/dev/null 2>&1; then
    domain_name=$(dnsdomainname 2>/dev/null)
fi

if [ -z "$domain_name" ]; then
    echo "Домен не найден."
    echo "Проверка домена завершена."
    exit 0
fi

echo "Домен: $domain_name"

echo
echo "=== Информация о подключении к домену ==="
echo

if command -v realm >/dev/null 2>&1; then
    realm list 2>/dev/null

    if [ $? -ne 0 ]; then
        echo "Не удалось получить информацию через realm."
    fi
else
    echo "Команда realm не найдена."
fi

echo
echo "=== Проверка SSSD ==="
echo

if command -v systemctl >/dev/null 2>&1; then
    if systemctl list-unit-files 2>/dev/null | grep -q '^sssd\.service'; then
        if systemctl is-active --quiet sssd; then
            echo "Служба SSSD: работает"
        else
            echo "Служба SSSD: не работает"
        fi
    else
        echo "Служба SSSD не найдена."
    fi
else
    echo "systemctl не найден."
fi

if command -v sssctl >/dev/null 2>&1; then
    echo
    echo "Домены SSSD:"
    sssctl domain-list 2>/dev/null
fi

echo
echo "=== Проверка Samba/Winbind ==="
echo

if command -v net >/dev/null 2>&1; then
    echo "Информация net ads:"
    net ads info 2>/dev/null || echo "Не удалось получить net ads info."
else
    echo "Команда net не найдена."
fi

echo
echo "=== Машины, включенные в домен ==="
echo

machines_found=0

if command -v samba-tool >/dev/null 2>&1; then
    echo "Список машин через samba-tool:"
    echo

    samba-tool computer list 2>/dev/null

    if [ $? -eq 0 ]; then
        machines_found=1
    else
        echo "Не удалось получить список машин через samba-tool."
    fi
fi

if [ "$machines_found" -eq 0 ] && command -v ldapsearch >/dev/null 2>&1; then
    echo "Список машин через ldapsearch:"
    echo

    ldap_base=$(echo "$domain_name" | awk -F. '{
        for (i = 1; i <= NF; i++) {
            if (i == 1) {
                printf "DC=%s", $i
            } else {
                printf ",DC=%s", $i
            }
        }
    }')

    ldapsearch -LLL -Y GSSAPI -b "$ldap_base" "(&(objectClass=computer))" dNSHostName sAMAccountName 2>/dev/null | \
    awk '
        /^sAMAccountName:/ {
            name=$0
            sub(/^sAMAccountName:[[:space:]]*/, "", name)
            print "Имя машины: " name
        }

        /^dNSHostName:/ {
            dns=$0
            sub(/^dNSHostName:[[:space:]]*/, "", dns)
            print "DNS-имя: " dns
            print ""
        }
    '

    if [ "${PIPESTATUS[0]}" -eq 0 ]; then
        machines_found=1
    else
        echo "Не удалось получить список машин через ldapsearch."
        echo "Возможно, нужен Kerberos-билет: kinit user@$domain_name"
    fi
fi

if [ "$machines_found" -eq 0 ]; then
    echo "Список машин домена получить не удалось."
    echo "Нужен samba-tool или ldapsearch с правами на чтение каталога."
fi

echo
echo "=== Локальные пользовательские группы ==="
echo

printf "%-30s %-10s %s\n" "Группа" "GID" "Пользователи"
printf "%-30s %-10s %s\n" "------" "---" "------------"

while IFS=: read -r group_name password_field group_id group_members; do
    if [ "$group_id" -ge 1000 ] && [ "$group_id" -lt 65534 ]; then

        users_in_group=""

        if [ -n "$group_members" ]; then
            users_in_group="$group_members"
        fi

        primary_users=$(awk -F: -v gid="$group_id" '
            $4 == gid && $3 >= 1000 && $3 < 65534 {
                print $1
            }
        ' /etc/passwd | paste -sd "," -)

        if [ -n "$primary_users" ]; then
            if [ -n "$users_in_group" ]; then
                users_in_group="$users_in_group,$primary_users"
            else
                users_in_group="$primary_users"
            fi
        fi

        if [ -z "$users_in_group" ]; then
            users_in_group="нет пользователей"
        fi

        printf "%-30s %-10s %s\n" "$group_name" "$group_id" "$users_in_group"
    fi
done < /etc/group

echo
echo "=== Локальные пользователи ==="
echo

printf "%-25s %-10s %-10s %-30s %s\n" "Пользователь" "UID" "GID" "Домашний каталог" "Shell"
printf "%-25s %-10s %-10s %-30s %s\n" "------------" "---" "---" "---------------" "-----"

awk -F: '
$3 >= 1000 && $3 < 65534 {
    printf "%-25s %-10s %-10s %-30s %s\n", $1, $3, $4, $6, $7
}
' /etc/passwd

echo
echo "Проверка домена завершена."
