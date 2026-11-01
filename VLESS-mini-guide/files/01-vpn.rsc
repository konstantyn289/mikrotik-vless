# VLESS-mini: сеть, DNS, файрвол и автоматика. Проверено на cAP ac, RouterOS 7.25.
# Перед импортом замени:
#   bridge      -> бридж, через который точка выходит в интернет
#   wlan1       -> радиоинтерфейс для VPN-сети
#   ТВОЁ_ИМЯ_СЕТИ -> имя новой Wi-Fi-сети
# Сеть 192.168.90.0/24 и 172.31.77.0/30 не должны быть заняты.
# Правило vpn-socksify выключено: vpn-watch включит его, когда связь заработает.

/interface bridge add name=vpn_bridge port-cost-mode=short
/ip address add address=192.168.90.1/24 comment=vpn interface=vpn_bridge
/ip pool add comment=vpn name=vpn-pool ranges=192.168.90.10-192.168.90.200
/ip dhcp-server network add address=192.168.90.0/24 comment=vpn dns-server=192.168.90.1 gateway=192.168.90.1
/ip dhcp-server add address-pool=vpn-pool interface=vpn_bridge lease-time=1h name=vpn-dhcp

/interface wireless add disabled=no master-interface=wlan1 name=vpn_wifi ssid="ТВОЁ_ИМЯ_СЕТИ" wds-default-bridge=vpn_bridge wps-mode=disabled
/interface bridge port add bridge=vpn_bridge comment=vpn interface=vpn_wifi

/interface veth add address=172.31.77.2/30 dhcp=no gateway=172.31.77.1 gateway6="" name=veth1
/ip address add address=172.31.77.1/30 comment=vpn-setup interface=veth1
/ip socksify add disabled=no name=vless port=1081 socks5-server=172.31.77.2

/ip dns set allow-remote-requests=yes servers=8.8.8.8,1.1.1.1 use-doh-server=https://1.1.1.1/dns-query verify-doh-cert=yes
/ip dns static
add address-list=ru comment=vpn forward-to=8.8.8.8 match-subdomain=yes name=ru type=FWD
add address-list=ru comment=vpn forward-to=8.8.8.8 match-subdomain=yes name=su type=FWD
add address-list=ru comment=vpn forward-to=8.8.8.8 match-subdomain=yes name=xn--p1ai type=FWD
add address-list=ru comment=vpn forward-to=8.8.8.8 match-subdomain=yes name=vk.com type=FWD
add address-list=ru comment=vpn forward-to=8.8.8.8 match-subdomain=yes name=yandex.net type=FWD

/ip firewall address-list
add address=10.0.0.0/8 comment=vpn list=novpn
add address=172.16.0.0/12 comment=vpn list=novpn
add address=192.168.0.0/16 comment=vpn list=novpn

/ip firewall filter
add action=accept chain=input comment=vpn connection-state=established,related
add action=accept chain=input comment=vpn dst-port=53,67 in-interface=vpn_bridge protocol=udp
add action=accept chain=input comment=vpn dst-port=53,1081 in-interface=vpn_bridge protocol=tcp
add action=drop chain=input comment=vpn in-interface=vpn_bridge
add action=drop chain=input comment=vpn dst-port=53 in-interface=bridge protocol=udp
add action=drop chain=input comment=vpn dst-port=53 in-interface=bridge protocol=tcp
add action=drop chain=forward comment=vpn dst-address-list=novpn in-interface=vpn_bridge
add action=drop chain=forward comment=vpn dst-address-list=!ru dst-port=443 in-interface=vpn_bridge protocol=udp

/ip firewall nat
add action=masquerade chain=srcnat comment=vpn-setup out-interface=bridge src-address=172.31.77.0/30
add action=masquerade chain=srcnat comment=vpn out-interface=bridge src-address=192.168.90.0/24
add action=redirect chain=dstnat comment=vpn dst-port=53 in-interface=vpn_bridge protocol=udp to-ports=53
add action=redirect chain=dstnat comment=vpn dst-port=53 in-interface=vpn_bridge protocol=tcp to-ports=53
add action=accept chain=dstnat comment=vpn dst-address-list=ru in-interface=vpn_bridge
add action=accept chain=dstnat comment=vpn dst-address-list=novpn in-interface=vpn_bridge
add action=socksify chain=dstnat comment=vpn-socksify disabled=yes in-interface=vpn_bridge protocol=tcp socksify-service=vless
add action=socksify chain=output comment=vpn-doh dst-address=1.1.1.1 dst-port=443 protocol=tcp socksify-service=vless
add action=socksify chain=output comment=vpn-probe dst-address=1.0.0.1 dst-port=80,443 protocol=tcp socksify-service=vless

/tool netwatch add comment=vpn down-script="/ip firewall nat disable [find comment=vpn-socksify]" host=172.31.77.2 interval=15s port=1080 type=tcp-conn up-script=""

/system script add comment=vpn dont-require-permissions=yes name=vpn-watch policy=ftp,reboot,read,write,policy,test,sensitive source=[/file get flash/vcfg/vpn-watch.txt contents]
/system scheduler
add comment=vpn interval=1w name=ru-list on-event="/import flash/vcfg/ru-list.rsc" start-time=startup
add comment=vpn interval=20s name=vpn-watch on-event="/system script run vpn-watch" policy=ftp,reboot,read,write,policy,test,sensitive start-time=startup
