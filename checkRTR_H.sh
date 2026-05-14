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
                grep -E "^[[:space:]]*$checked_user[[:space:]]+" /etc/sudoers 2>/dev/null
            fi

            if [ -d /etc/sudoers.d ]; then
                grep -R -h -E "^[[:space:]]*$checked_user[[:space:]]+" /etc/sudoers.d/ 2>/dev/null
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
