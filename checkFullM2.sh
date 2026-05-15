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
echo "=== Проверка домена ==="
echo

domain_name=""

if command -v samba-tool >/dev/null 2>&1; then
    domain_name=$(samba-tool domain info 127.0.0.1 2>/dev/null | awk -F: '/Domain/ {gsub(/^[ \t]+/, "", $2); print $2; exit}')
fi

if [ -z "$domain_name" ] && command -v realm >/dev/null 2>&1; then
    domain_name=$(realm list 2>/dev/null | awk -F: '/realm-name/ {gsub(/^[ \t]+/, "", $2); print $2; exit}')
fi

if [ -z "$domain_name" ]; then
    domain_name=$(hostname -d 2>/dev/null)
fi

if [ -z "$domain_name" ]; then
    echo "Домен не найден."
    echo "Проверка домена завершена."
    exit 0
fi

echo "Домен: $domain_name"
echo

echo "=== Информация о домене ==="
echo

if command -v samba-tool >/dev/null 2>&1; then
    samba-tool domain info 127.0.0.1 2>/dev/null || echo "Не удалось получить информацию через samba-tool."
else
    echo "samba-tool не найден."
    echo "Для вывода групп и пользователей домена нужен samba-tool."
    echo "Проверка домена завершена."
    exit 0
fi

echo
echo "=== Машины, включенные в домен ==="
echo

if samba-tool computer list >/tmp/domain_computers.txt 2>/dev/null; then
    if [ -s /tmp/domain_computers.txt ]; then
        cat /tmp/domain_computers.txt
    else
        echo "Машины в домене не найдены."
    fi
else
    echo "Не удалось получить список машин домена."
fi

rm -f /tmp/domain_computers.txt

echo
echo "=== Группы домена и пользователи в группах ==="
echo

if samba-tool group list >/tmp/domain_groups.txt 2>/dev/null; then
    if [ ! -s /tmp/domain_groups.txt ]; then
        echo "Группы домена не найдены."
    else
        while IFS= read -r domain_group; do
            [ -z "$domain_group" ] && continue

            echo "----------------------------------------"
            echo "Группа: $domain_group"
            echo "Пользователи в группе:"
            echo

            if samba-tool group listmembers "$domain_group" >/tmp/domain_group_members.txt 2>/dev/null; then
                if [ -s /tmp/domain_group_members.txt ]; then
                    cat /tmp/domain_group_members.txt
                else
                    echo "Пользователей нет."
                fi
            else
                echo "Не удалось получить пользователей группы."
            fi

            echo

        done < /tmp/domain_groups.txt
    fi
else
    echo "Не удалось получить список групп домена."
fi

rm -f /tmp/domain_groups.txt /tmp/domain_group_members.txt

echo
echo "=== Пользователи домена ==="
echo

if samba-tool user list >/tmp/domain_users.txt 2>/dev/null; then
    if [ -s /tmp/domain_users.txt ]; then
        cat /tmp/domain_users.txt
    else
        echo "Пользователи домена не найдены."
    fi
else
    echo "Не удалось получить список пользователей домена."
fi

rm -f /tmp/domain_users.txt

echo
