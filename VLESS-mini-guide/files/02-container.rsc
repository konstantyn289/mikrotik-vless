# Создаёт контейнер из ram/vless.tar. Запускать после 01-vpn.rsc.
/container mounts add comment=vpn-setup dst=/config list=vcfg src=/flash/vcfg
/container add cmd="--uri-file /config/connection.uri --listen-port 1080" comment=vpn-setup entrypoint=/vless-mini env="VLESS_BIND=0.0.0.0" file=ram/vless.tar interface=veth1 layer-dir="" logging=yes memory-max=24.0MiB mountlists=vcfg name=vless restart-policy=always root-dir=/flash/vless start-on-boot=yes
