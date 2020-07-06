#!/bin/bash

# echo all commands executed
set -x
# exit on all failures
set -e

FEDORA_VERSION=${1:-32}

# first detect the filename for the latest RAW image
IMAGE=/tmp/fedora-$FEDORA_VERSION-disk.img
RAW_NAME=$(curl http://mirrors.kernel.org/fedora/releases/$FEDORA_VERSION/Cloud/x86_64/images/ |grep raw.xz |sed -e 's/<[^>]*>//g'|cut -d" " -f1)
# download the RAW image and immediatelly decompress it into a disk.raw image
curl http://mirrors.kernel.org/fedora/releases/$FEDORA_VERSION/Cloud/x86_64/images/$RAW_NAME | xz --decompress --stdout > $IMAGE

# prepare the mountpoint for the image
ROOT=/mnt/fedora-$FEDORA_VERSION-disk
if [ -d "$ROOT" ]; then
    echo "err: Previous mount folder detected at: $ROOT. Unmount and remove it manually to be safe."
    exit 1
fi
mkdir -vp $ROOT
losetup -fP $IMAGE
DEVICE=$( losetup -l |grep $IMAGE |awk '{print($1)}' )
mount ${DEVICE}p1 $ROOT
mount --bind /etc/resolv.conf $ROOT/etc/resolv.conf
mount --bind /sys $ROOT/sys
mount --bind /proc $ROOT/proc
mount --bind /dev $ROOT/dev

# remove cloud-init, replace with gce utils
chroot $ROOT /bin/bash << "EOT"
dnf -y remove cloud-init
dnf -y install google-compute-engine-tools
systemctl enable google-accounts-daemon google-clock-skew-daemon \
    google-instance-setup google-network-daemon \
    google-shutdown-scripts google-startup-scripts
EOT

# install google cloud sdk
chroot $ROOT /bin/bash << "EOT"
tee -a /etc/yum.repos.d/google-cloud-sdk.repo << EOM
[google-cloud-sdk]
name=Google Cloud SDK
baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
       https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOM
dnf -y install google-cloud-sdk
EOT

# FIXME: install stackdriver agent, and disable it from systemd
#chroot $ROOT /bin/bash << "EOT"
#curl https://dl.google.com/cloudagents/add-monitoring-agent-repo.sh | sh
#dnf -y install stackdriver-agent
#systemctl disable stackdriver-agent
#EOT

# FIXME: install stackdriver logging, and disable it from systemd
#chroot $ROOT /bin/bash << "EOT"
#curl https://dl.google.com/cloudagents/add-logging-agent-repo.sh | sh
#dnf -y install google-fluentd
#systemctl disable google-fluentd
#EOT

# final tasks
chroot $ROOT /bin/bash << "EOT"
dnf -y upgrade --refresh && dnf clean all
touch /.autorelabel
sync
EOT

# cleanup the image mountpoint
umount $ROOT/etc/resolv.conf
umount $ROOT/sys
umount $ROOT/proc
umount $ROOT/dev
umount $ROOT
losetup -d $DEVICE
rmdir -v $ROOT

# sync all changes to disk, again to make sure that the image is consistent
sync

# eof