#!/bin/bash

echo "Имя устройства:"
hostname
echo

# Проверяем интернет через ping до DNS Google
echo "Проверка интернета через ping до ya.ru"
echo

ping -c 2 ya.ru

echo
echo "Сетевые интерфейсы и IP-адреса:"

# Выводим IP-адреса с маской подсети
ip -o -4 addr show | awk '{print "Интерфейс: " $2 "\nIP-адрес/маска: " $4 "\n"}'

#Пользователи
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
#Наличие прав
echo "Файл sudoers"
echo
check_sudoers_user() {
    login_name="$1"

    if [ -r /etc/sudoers ]; then
        if grep -E "^[[:space:]]*$login_name[[:space:]]+" /etc/sudoers | grep -vE "^[[:space:]]*#" > /dev/null 2>&1; then
            echo "да"
            return
        fi
    fi

    if [ -d /etc/sudoers.d ]; then
        if grep -R -E "^[[:space:]]*$login_name[[:space:]]+" /etc/sudoers.d/ 2>/dev/null | grep -vE "^[[:space:]]*#" > /dev/null 2>&1; then
            echo "да"
            return
        fi
    fi

    echo "нет"
}

while IFS=: read -r login_name passwd_field user_id group_id user_comment home_dir user_shell; do
    if [ "$user_id" -ge 1000 ] && [ "$user_id" -lt 65534 ]; then
        SUDOERS_STATUS=$(check_sudoers_user "$login_name")
        printf "%-25s %-10s %-10s %-10s\n" "$login_name" "$user_id" "$group_id" "$SUDOERS_STATUS"
    fi
done < /etc/passwd
