#! /bin/bash

function getNextRoot() {
    rootUuid=$(cat /proc/cmdline | sed -e 's/^.*root=//' -e 's/ .*$//' | sed 's/PARTUUID=\(.*\)\/.*/\1/')
    currentKernel=$(blkid | grep $rootUuid | sed 's/.*PARTLABEL="\(.*\)" PARTUUID=.*/\1/')

    case $currentKernel in
     KERN-A)
          echo "ROOT-B"
          ;;
     KERN-B)
          echo "ROOT-A"
          ;;
     *)
          echo "UNKNOWN"
          ;;
    esac
}

function makePartitionWriteable() {
    partitionNumber=$1
    /usr/share/vboot/bin/make_dev_ssd.sh --remove_rootfs_verification --image /dev/mmcblk0 --partition $partitionNumber
}

function copyGaleforce() {
    partitionNumber=$1
    destinationDevice=$2

    makePartitionWriteable $partitionNumber
    rootMount=/tmp/rootmount
    mkdir -p $rootMount
    mount $destinationDevice $rootMount
    cp -R /galeforce $rootMount
    $rootMount/galeforce/patch.sh
    umount $rootMount
}

function copyGaleforceBruteForce() {
    makePartitionWriteable 2
    makePartitionWriteable 4

    mkdir -p /tmp/roota /tmp/rootb
    mount /dev/mmcblk0p3 /tmp/roota
    mount /dev/mmcblk0p5 /tmp/rootb

    if [ ! -d /tmp/roota/galeforce ]
    then
        echo "Copying galeforce to ROOT-A"
        cp -R /galeforce /tmp/roota
    else
        echo "Copying galeforce to ROOT-B"
        cp -R /galeforce /tmp/rootb
    fi

    umount /tmp/roota
    umount /tmp/rootb
}

echo "Update detected"
nextRoot=$(getNextRoot)

case $nextRoot in
 ROOT-A)
      echo "Copying galeforce from ROOT-B to ROOT-A"
      copyGaleforce 2 /dev/mmcblk0p3
      ;;
 ROOT-B)
      echo "Copying galeforce from ROOT-A to ROOT-B"
      copyGaleforce 4 /dev/mmcblk0p5
      ;;
 *)
      echo "Unable to determine current root. Last gasp effort."
      copyGaleforceBruteForce
      ;;
esac

echo "Updated finished"