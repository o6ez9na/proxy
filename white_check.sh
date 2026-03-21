#!/bin/bash

set -e

echo "=== Обновление пакетов ==="
sudo apt update -y

echo "=== Установка nginx ==="
sudo apt install -y nginx

echo "=== Включаем nginx в автозапуск ==="
sudo systemctl enable nginx

echo "=== Запускаем nginx ==="
sudo systemctl start nginx

echo "=== Открываем firewall (если ufw есть) ==="
if command -v ufw >/dev/null 2>&1; then
    sudo ufw allow 'Nginx Full' || true
fi

echo "=== Создаем простую страницу ==="
sudo tee /var/www/html/index.html > /dev/null <<EOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>My Server</title>
    <style>
        body {
            background: #0f172a;
            color: #e2e8f0;
            font-family: Arial, sans-serif;
            text-align: center;
            padding-top: 100px;
        }
        h1 {
            font-size: 48px;
        }
    </style>
</head>
<body>
    <h1>🚀 Server is working</h1>
    <p>Nginx успешно запущен</p>
</body>
</html>
EOF

echo "=== Перезапуск nginx ==="
sudo systemctl restart nginx

echo "=== Готово ==="
echo "Открой в браузере: http://$(hostname -I | awk '{print $1}')"
