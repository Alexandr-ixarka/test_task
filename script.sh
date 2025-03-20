sudo bash -c 'cat << EOF > /usr/local/bin/monitor_test.sh
#!/bin/bash

# Лог-файл
LOG_FILE="/var/log/monitoring.log"

# URL для мониторинга
MONITORING_URL="https://test.com/monitoring/test/api"

# Имя процесса
PROCESS_NAME="test"

# Файл для хранения PID процесса
PID_FILE="/var/run/monitor_test.pid"

# Функция для записи в лог
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Проверка, запущен ли процесс
if pgrep -x "$PROCESS_NAME" > /dev/null; then
    # Получаем текущий PID процесса
    CURRENT_PID=$(pgrep -x "$PROCESS_NAME")

    # Проверяем, был ли процесс перезапущен
    if [ -f "$PID_FILE" ]; then
        PREVIOUS_PID=$(cat "$PID_FILE")
        if [ "$CURRENT_PID" != "$PREVIOUS_PID" ]; then
            log_message "Процесс $PROCESS_NAME был перезапущен. Старый PID: $PREVIOUS_PID, новый PID: $CURRENT_PID."
        fi
    fi

    # Сохраняем текущий PID в файл
    echo "$CURRENT_PID" > "$PID_FILE"

    # Отправляем запрос на сервер мониторинга
    if curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$MONITORING_URL" | grep -q "200"; then

        log_message "Процесс $PROCESS_NAME запущен, запрос на $MONITORING_URL успешен."
    else
        log_message "Процесс $PROCESS_NAME запущен, но сервер мониторинга недоступен."
    fi
else
    # Процесс не запущен, ничего не делаем
    if [ -f "$PID_FILE" ]; then
        rm "$PID_FILE"
    fi
fi

EOF'

chmod +x /usr/local/bin/monitor_test.sh

sudo bash -c 'cat << EOF > /etc/systemd/system/monitor_test.service
[Unit]
Description=Monitor Test Process
After=network.target

[Service]
ExecStart=/usr/local/bin/monitor_test.sh
Restart=on-failure
RestartSec=60

[Install]
WantedBy=multi-user.target
EOF'

sudo bash -c 'cat << EOF > /etc/systemd/system/monitor_test.timer
[Unit]
Description=Run monitor-test every minute

[Timer]
OnBootSec=1min
OnUnitActiveSec=1min
Unit=monitor-test.service

[Install]
WantedBy=timers.target
EOF'


sudo systemctl enable monitor_test.timer
sudo systemctl start monitor_test.timer
sudo systemctl enable monitor-test.service
sudo systemctl start monitor_test.service
sudo systemctl daemon-reload
