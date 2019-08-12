#!/bin/bash
set -e

backup_uuid="${BACKUP_UUID}"
data_uuid="${DATA_UUID}"
[[ -z $backup_uuid ]] && (echo "missing BACKUP_UUID disk uuid" && exit 1)
[[ -z $data_uuid ]] && (echo "missing DATA_UUID disk uuid" && exit 1)

sudo -i
apt-get update -y
apt-get upgrade -y
apt-get install -y hfsutils hfsprogs netatalk

# create mountpoints
mkdir -p /mnt/Tresor /mnt/Data || :

if ! grep $BACKUP_UUID /etc/fstab ; then
  echo "UUID=${BACKUP_UUID} /media/Tresor hfsplus force,rw,user 0 0" >>/etc/fstab
fi
if ! grep $DATA_UUID /etc/fstab ; then
  echo "UUID=${DATA_UUID} /media/Data hfsplus force,rw,user 0 0" >>/etc/fstab
fi

echo "Generated the following fstab:"
cat /etc/fstab

mount -a
df -h

# setup netatalk
netatalk -V

# reconfigure nsswitch to use mdns
sed -i'.bak' -e "s/^hosts:.*/hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4 mdns/g" /etc/nsswitch.conf

# configure afp
cat >>/etc/netatalk/afp.conf <<_EOF_
[Global]
  mimic model = TimeCapsule6,106

[Tresor]
  path = /media/Tresor
  time machine = yes

[Data]
  path = /media/Data
_EOF_

# create overrides in /etc/systemd/system for avahi and netatalk for dependency on our mounts

for s in avahi-daemon netatalk ; do
  mkdir -p /etc/systemd/system/$s.service.d
  cat >/etc/systemd/system/$s.service.d/override.conf <<_EOF_
[Unit]
RequiresMountsFor=/mnt/Tresor /mnt/Data
_EOF_

done
systemctl daemon-reload

service avahi-daemon start
systemctl avahi-daemon enable
service netatalk start
service netatalk start



