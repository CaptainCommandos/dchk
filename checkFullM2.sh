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
    exit 0
fi

echo "Домен: $domain_name"
echo

if ! command -v samba-tool >/dev/null 2>&1; then
    echo "samba-tool не найден."
    echo "Невозможно вывести группы и пользователей домена."
    exit 0
fi

echo "=== Информация о домене ==="
echo

samba-tool domain info 127.0.0.1 2>/dev/null || echo "Не удалось получить информацию о домене."
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
echo "=== Пользовательские группы домена и пользователи в них ==="
echo

is_standard_domain_group() {
    group_name="$1"

    case "$group_name" in
        "Allowed RODC Password Replication Group") return 0 ;;
        "Denied RODC Password Replication Group") return 0 ;;
        "Enterprise Read-only Domain Controllers") return 0 ;;
        "Cloneable Domain Controllers") return 0 ;;
        "RAS and IAS Servers") return 0 ;;
        "Cert Publishers") return 0 ;;
        "DnsAdmins") return 0 ;;
        "DnsUpdateProxy") return 0 ;;

        "Domain Admins") return 0 ;;
        "Domain Computers") return 0 ;;
        "Domain Controllers") return 0 ;;
        "Domain Guests") return 0 ;;
        "Domain Users") return 0 ;;

        "Enterprise Admins") return 0 ;;
        "Schema Admins") return 0 ;;
        "Group Policy Creator Owners") return 0 ;;
        "Read-only Domain Controllers") return 0 ;;

        "Administrators") return 0 ;;
        "Users") return 0 ;;
        "Guests") return 0 ;;
        "Print Operators") return 0 ;;
        "Backup Operators") return 0 ;;
        "Replicator") return 0 ;;
        "Remote Desktop Users") return 0 ;;
        "Network Configuration Operators") return 0 ;;
        "Performance Monitor Users") return 0 ;;
        "Performance Log Users") return 0 ;;
        "Distributed COM Users") return 0 ;;
        "IIS_IUSRS") return 0 ;;
        "Cryptographic Operators") return 0 ;;
        "Event Log Readers") return 0 ;;
        "Certificate Service DCOM Access") return 0 ;;
        "RDS Remote Access Servers") return 0 ;;
        "RDS Endpoint Servers") return 0 ;;
        "RDS Management Servers") return 0 ;;
        "Hyper-V Administrators") return 0 ;;
        "Access Control Assistance Operators") return 0 ;;
        "Remote Management Users") return 0 ;;
        "Storage Replica Administrators") return 0 ;;

        *) return 1 ;;
    esac
}

custom_group_count=0

if samba-tool group list >/tmp/domain_groups.txt 2>/dev/null; then
    if [ ! -s /tmp/domain_groups.txt ]; then
        echo "Группы домена не найдены."
    else
        while IFS= read -r domain_group; do
            [ -z "$domain_group" ] && continue

            if is_standard_domain_group "$domain_group"; then
                continue
            fi

            custom_group_count=$((custom_group_count + 1))

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

        if [ "$custom_group_count" -eq 0 ]; then
            echo "Пользовательские группы домена не найдены."
        fi
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
        grep -vE '^(Administrator|Guest|krbtgt)$' /tmp/domain_users.txt

        if [ $? -ne 0 ]; then
            echo "Пользовательские пользователи домена не найдены."
        fi
    else
        echo "Пользователи домена не найдены."
    fi
else
    echo "Не удалось получить список пользователей домена."
fi

rm -f /tmp/domain_users.txt

echo
