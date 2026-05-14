#!/bin/bash

echo "Имя устройства:"
hostname
echo

echo "Полное имя устройства:"
full_name=$(hostname -f 2>/dev/null)

if [ -n "$full_name" ]; then
    echo "$full_name"
else
    echo "$(hostname) — полное доменное имя не задано"
fi

echo
echo "Проверка интернета через ping до ya.ru"
echo

ping -c 2 ya.ru

echo
echo "Сетевые интерфейсы и IP-адреса:"
echo

ip -o -4 addr show | awk '{print "Интерфейс: " $2 "\nIP-адрес/маска: " $4 "\n"}'

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
echo "=== Проверка пользователей в sudoers ==="
echo

printf "%-25s %-10s %-10s %-10s\n" "Пользователь" "UID" "GID" "SUDOERS"
printf "%-25s %-10s %-10s %-10s\n" "------------" "---" "---" "-------"

check_sudoers_user() {
    local checked_user
    checked_user="$1"

    if [ -r /etc/sudoers ]; then
        if grep -E "^[[:space:]]*$checked_user[[:space:]]+" /etc/sudoers 2>/dev/null | grep -vE "^[[:space:]]*#" > /dev/null 2>&1; then
            echo "да"
            return
        fi
    fi

    if [ -d /etc/sudoers.d ]; then
        if grep -R -E "^[[:space:]]*$checked_user[[:space:]]+" /etc/sudoers.d/ 2>/dev/null | grep -vE "^[[:space:]]*#" > /dev/null 2>&1; then
            echo "да"
            return
        fi
    fi

    echo "нет"
}

while IFS=: read -r login_name passwd_field user_id group_id user_comment home_dir user_shell; do
    if [ "$user_id" -ge 1000 ] && [ "$user_id" -lt 65534 ]; then
        sudoers_status=$(check_sudoers_user "$login_name")
        printf "%-25s %-10s %-10s %-10s\n" "$login_name" "$user_id" "$group_id" "$sudoers_status"
    fi
done < /etc/passwd
