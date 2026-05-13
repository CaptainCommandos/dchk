#!/bin/bash

echo "Проверка подключения к интернету..."

# Проверяем интернет через ping до DNS Google
if ping -c 4 ya.ru > /dev/null 2>&1; then
    echo "Интернет работает"
else
    echo "Интернет не работает"
fi

echo
echo "Сетевые интерфейсы и IP-адреса:"

# Выводим IP-адреса с маской подсети
ip -o -4 addr show | awk '{print "Интерфейс: " $2 "\nIP-адрес/маска: " $4 "\n"}'