# ProxyRevoke

Небольшая утилита для macOS: направляет соединения к одному IPv4-адресу прокси через физическое сетевое подключение (Wi-Fi/Ethernet). VPN для остального трафика продолжает работать по своим правилам.

`proxy-bypass.sh` запускается системной службой launchd каждые 15 секунд, отслеживает интерфейс и шлюз, восстанавливает маршрут и раз в минуту проверяет TCP-порт прокси. Поддерживаются интерфейсы `en*` и `bridge*`. VPN с блокировкой трафика вне туннеля может блокировать этот маршрут.

`ProxyCurl.app` — оболочка над системным curl. Запускайте её исполняемый файл из терминала с обычными аргументами curl. Утилита сама не меняет настройки прокси браузеров: в браузере нужно отдельно указать HTTP-прокси.

## Установка

1. Скопируйте `config.example` в `config.local`.
2. Заполните `PROXY_HOST`, `PROXY_PORT` и `PROXY_URL` одним и тем же адресом и портом. Специальные символы логина и пароля в URL нужно кодировать. Файл читается как shell-конфигурация: используйте только доверенные настройки.
3. Выполните `chmod 600 config.local` и `./scripts/install.sh` от обычного пользователя. Для установки службы потребуется пароль администратора.

Установщик сохраняет настройки curl в `~/Library/Application Support/ProxyRevoke/config.local`, приложение — в `~/Applications/ProxyCurl.app`, службу — в `/Library/LaunchDaemons/local.proxy-bypass.plist`, исполняемый скрипт — в `/Library/PrivilegedHelperTools/local.proxy-bypass.sh`. Системный файл `/Library/Preferences/local.proxy-bypass.conf` содержит только IP и порт. Повторная установка обновляет адрес и удаляет старый маршрут.

```sh
launchctl print system/local.proxy-bypass
route -n get YOUR_PROXY_IP
"$HOME/Applications/ProxyCurl.app/Contents/MacOS/ProxyCurl" https://example.com
```

Для смены прокси измените `config.local` и повторите установку. Исходники в этой папке не нужны для работы установленной службы.

## Публикация

`config.local` исключён из Git. В отслеживаемых файлах нет личных адресов прокси и учётных данных. Не добавляйте локальный конфиг через `git add -f`.

## Удаление службы

```sh
sudo launchctl bootout system/local.proxy-bypass
sudo route -n delete -host YOUR_PROXY_IP
sudo rm -f /Library/LaunchDaemons/local.proxy-bypass.plist /Library/PrivilegedHelperTools/local.proxy-bypass.sh /Library/Preferences/local.proxy-bypass.conf
```

Приложение `~/Applications/ProxyCurl.app` и папку `~/Library/Application Support/ProxyRevoke` можно удалить отдельно.
