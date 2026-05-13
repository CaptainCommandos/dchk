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
    USERNAME="$1"

    # Проверка в основном файле /etc/sudoers
    if [ -r /etc/sudoers ]; then
        if grep -E "^[[:space:]]*$USERNAME[[:space:]]+" /etc/sudoers | grep -vE "^[[:space:]]*#" > /dev/null 2>&1; then
            echo "да"
            return
        fi
    fi

    # Проверка в файлах /etc/sudoers.d/
    if [ -d /etc/sudoers.d ]; then
        if grep -R -E "^[[:space:]]*$USERNAME[[:space:]]+" /etc/sudoers.d/ 2>/dev/null | grep -vE "^[[:space:]]*#" > /dev/null 2>&1; then
            echo "да"
            return
        fi
    fi

    echo "нет"
}

while IFS=: read -r USERNAME PASSWORD USER_ID GROUP_ID COMMENT HOME_DIR USER_SHELL; do
    if [ "$USER_ID" -ge 1000 ] && [ "$USER_ID" -lt 65534 ]; then
        SUDOERS_STATUS=$(check_sudoers_user "$USERNAME")
        printf "%-25s %-10s %-10s %-10s\n" "$USERNAME" "$USER_ID" "$GROUP_ID" "$SUDOERS_STATUS"
    fi
done < /etc/passwd
