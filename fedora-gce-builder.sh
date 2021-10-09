#!/bin/bash

# echo all commands executed
set -x
# exit on all failures
set -e

FEDORA_VERSION=${1:-34}

# first detect the filename for the latest RAW image
IMAGE=/tmp/fedora-$FEDORA_VERSION-disk.img
RAW_NAME=$(curl http://mirrors.kernel.org/fedora/releases/$FEDORA_VERSION/Cloud/x86_64/images/ |grep raw.xz |sed -e 's/<[^>]*>//g'|cut -d" " -f1)
# download the RAW image and immediatelly decompress it into a disk.raw image
if ! [ -f $IMAGE ]; then
    curl http://mirrors.kernel.org/fedora/releases/$FEDORA_VERSION/Cloud/x86_64/images/$RAW_NAME | xz --decompress --stdout > $IMAGE
fi

# prepare the mountpoint for the image
ROOT=/mnt/fedora-$FEDORA_VERSION-disk
mkdir -vp $ROOT
losetup -fP $IMAGE
DEVICE=$( losetup -l |grep $IMAGE |awk '{print($1)}' )
mount ${DEVICE}p1 $ROOT
mv -fv $ROOT/etc/resolv.conf $ROOT/etc/resolv.conf.original
touch $ROOT/etc/resolv.conf
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
baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el8-x86_64
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
dnf clean all
EOT

# do some cleanup to make sure that no processes are blocking unmounting
dnf install -y psmisc lsof coreutils
for PROCESS in $( lsof |grep $ROOT |cut -d" " -f1 ); do
    pkill -9 $PROCESS || true
done

# cleanup the image mountpoint
umount $ROOT/etc/resolv.conf
rm -fv $ROOT/etc/resolv.conf
mv -fv $ROOT/etc/resolv.conf.original $ROOT/etc/resolv.conf
umount $ROOT/sys
umount $ROOT/proc
umount $ROOT/dev
umount $ROOT
losetup -d $DEVICE
rmdir -v $ROOT

# sync all changes to disk, again to make sure that the image is consistent
sync

# eof