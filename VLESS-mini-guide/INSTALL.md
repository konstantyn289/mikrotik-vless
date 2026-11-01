# Установка VLESS-mini на MikroTik

Гайд для точки **cAP ac на RouterOS 7.25**. Нужны ARMv7, 128 МБ памяти и примерно 500 КБ свободного флеша. На других устройствах не проверялось.

Что получится: отдельная Wi-Fi-сеть, где TCP идёт через VLESS + REALITY, а российские сайты идут напрямую. Если все серверы упали, интернет на 10 минут идёт напрямую, **без VPN**.

Не поддерживается: UDP через VPN, WebSocket, gRPC, XHTTP. Нужен сервер VLESS + TCP + REALITY + Vision.

## Что нужно

- `vless.tar`: образ контейнера. **В эту папку не входит**, см. README.
- Твоя ссылка `vless://`. Никому её не показывай и не клади в репозиторий.
- Физический доступ к устройству: для шага 3 нужна кнопка или отключение питания.

## 1. Бэкап

```routeros
/export file=before-vless
```

Скачай файл на компьютер.

## 2. Пакет container

Скачай на mikrotik.com архив Extra packages для arm той же версии, что на устройстве. Загрузи `container-*.npk` в корень файлов и перезагрузи устройство.

## 3. Разрешить контейнеры

```routeros
/system/device-mode/update container=yes activation-timeout=5m
```

За 5 минут нажми кнопку Reset/Mode или выключи и включи питание. Обычный `reboot` отменяет разрешение. Проверка:

```routeros
/system/device-mode/print
```

Должно быть `container: yes`.

## 4. Диск в памяти и файлы

```routeros
/disk add slot=ram tmpfs-max-size=4000000 type=tmpfs
/file add name=flash/vcfg type=directory
```

Загрузи на устройство:

| Откуда | Куда |
|---|---|
| `vless.tar` | `ram/vless.tar` |
| `files/vpn-watch.txt` | `flash/vcfg/vpn-watch.txt` |
| твой `connection.uri` | `flash/vcfg/connection.uri` |
| твой `servers.txt` | `flash/vcfg/servers.txt` |
| твой `ru-list.rsc` | `flash/vcfg/ru-list.rsc` |

В `servers.txt` по одной ссылке на строку, в конце каждой строки перевод строки. В `connection.uri` одна ссылка, первая из `servers.txt`. Образцы лежат в `files/*.example`.

Если у точки нет маршрута в интернет, добавь его, указав свой роутер:

```routeros
/ip route add comment=vpn-setup dst-address=0.0.0.0/0 gateway=IP_РОУТЕРА
```

## 5. Сеть и файрвол

Открой `files/01-vpn.rsc` и замени значения из шапки. Загрузи файлы `01-vpn.rsc` и `02-container.rsc` в `ram/`, потом:

```routeros
/import ram/01-vpn.rsc
```

Если на устройстве уже есть правила файрвола, проверь порядок: новые правила встают в конец списка.

Из новой сети нет доступа к управлению точкой, заходи из основной. Это сделано специально.

## 6. Контейнер

```routeros
/import ram/02-container.rsc
/container print
```

Подожди, пока извлечение закончится, потом запусти контейнер и посмотри лог:

```routeros
/container start [find name=vless]
/log print where topics~"container"
```

Хорошая строка: `[reality] authenticated`.

## 7. Проверка

Через минуту подключись к новой сети и открой сайт, показывающий твой IP. Должен быть адрес сервера. Если нет, смотри:

```routeros
/log print where message~"vpn-watch"
/ip firewall nat print where comment=vpn-socksify
```

Когда всё работает, освободи память:

```routeros
/file remove ram/vless.tar
```

## Откат

Останови и удали контейнер, удали всё с комментариями `vpn` и `vpn-setup`, папку `flash/vcfg`, `vpn_wifi`, `vpn_bridge` и `veth1`. Либо верни настройки из бэкапа с шага 1.
