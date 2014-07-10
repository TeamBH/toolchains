echo 'Setting parameters...'
export SOURCEDIR=/root/android/android_kernel_exynos5410
export INITRDDIR=/root/android/initramfs_samsung
export CROSS_COMPILE=/root/android/toolchains/i386/arm-linux-androideabi-4.8/bin/arm-linux-androideabi-
export SYSROOT=/root/android/toolchains/i386/sysroot/
export WORKDIR=/root/android/workspace
export ARCH=arm
export USE_SEC_FIPS_MODE=true
export SEC_BUILD_OPTION_SELINUX_ENFORCE=false
export USE_CCACHE=1
export MODEL=i9502
export VERSION=v7tc
export LOCALVERSION=-$MODEL-$VERSION

export BOOTIMG=/root/android/initramfs_samsung/ja3gduos_chn_cu/boot.sdk19.img
export RECOVERYCPIO=/root/android/initramfs_samsung/ja3gduos_chn_cu/recovery.cpio.lzma
# export BOOTCOMMON=/root/android/s4/kernel/initramfs_samsung_galaxy_s4/common/boot
# export RECOVERYCOMMON=/root/android/s4/kernel/initramfs_samsung_galaxy_s4/common/recovery
# export BOOTDIR=/root/android/s4/kernel/initramfs_samsung_galaxy_s4/GT-I9502/boot
# export RECOVERYDIR=/root/android/s4/kernel/initramfs_samsung_galaxy_s4/GT-I9502/recovery
# export METADIR=/root/android/s4/kernel/initramfs_samsung_galaxy_s4/recovery-flashable
# export CONFIG=/root/android/s4/kernel/initramfs_samsung_galaxy_s4/common/abootimg.cfg
# export DEFCONFIG=maxfu_i9502_tc_defconfig

echo 'Setting workspace...'
rm -rf $WORKDIR
mkdir $WORKDIR
cd $WORKDIR
cp -a $SOURCEDIR $WORKDIR/source
cp -a $BOOTIMG $WORKDIR/boot.stock.img
abootimg -x boot.stock.img
mv zImage zImage.stock
mv initrd.img initrd.stock.img
mkdir $WORKDIR/boot-initramfs
zcat $WORKDIR/initrd.stock.img | ( cd $WORKDIR/boot-initramfs; cpio -i )
cp -a $INITRDDIR/addon/* $WORKDIR/boot-initramfs
cat $WORKDIR/boot-initramfs/res/init_patch >> $WORKDIR/boot-initramfs/init.rc
cp -a $RECOVERYCPIO $WORKDIR/
mkdir $WORKDIR/recovery-initramfs
zcat $WORKDIR/recovery.cpio.lzma | ( cd $WORKDIR/recovery-initramfs; cpio -i )
sed -i '/bootsize/d' $WORKDIR/bootimg.cfg

echo 'Making kernel and modules...'
cd $WORKDIR/source
cat $WORKDIR/source/arch/arm/configs/ja3g_00_defconfig \
    $WORKDIR/source/arch/arm/configs/ja3gduos_chn_cu \
    $WORKDIR/source/arch/arm/configs/ja3g_maxfu \
    $WORKDIR/source/arch/arm/configs/ja3g_sdk19 > $WORKDIR/source/arch/arm/configs/temp_defconfig
make temp_defconfig
make -j3
find -name zImage -exec cp -av {} $WORKDIR/ \;
find -name *.ko -exec cp -av {} $WORKDIR/boot-initramfs/lib/modules/ \;
find -name *.ko -exec cp -av {} $WORKDIR/recovery-initramfs/lib/modules/ \;

echo 'Making ramdisks...'
chmod -R g-w $WORKDIR/temp/boot-initramfs/*
chmod -R g-w $WORKDIR/temp/recovery-initramfs/*
( cd $WORKDIR/boot-initramfs; find | sort | cpio --quiet -o -H newc ) | lzma > $WORKDIR/boot-initramfs.cpio.lzma
( cd $WORKDIR/recovery-initramfs; find | sort | cpio --quiet -o -H newc ) | lzma > $WORKDIR/recovery-initramfs.cpio.lzma

echo 'Making images...'
abootimg --create $WORKDIR/boot.img -f $WORKDIR/bootimg.cfg -k $WORKDIR/zImage -r $WORKDIR/boot-initramfs.cpio.lzma
abootimg --create $WORKDIR/recovery.img -f $WORKDIR/bootimg.cfg -k $WORKDIR/zImage -r $WORKDIR/recovery-initramfs.cpio.lzma
abootimg --create $WORKDIR/boot.lite.img -f $WORKDIR/bootimg.cfg -k $WORKDIR/zImage.stock -r $WORKDIR/boot-initramfs.cpio.lzma

echo 'Making Odin flashable tarballs...'
cd $WORKDIR/
tar -cvf boot-$MODEL-$VERSION.tar boot.img
tar -cvf recovery-$MODEL-$VERSION.tar recovery.img
tar -cvf lite-$MODEL-$VERSION.tar boot.lite.img

# echo 'Making CWM/TWRP flashable zips...'
# cp -a $WORKDIR/output/*.img $WORKDIR/temp/recovery-flashable/
# cd $WORKDIR/temp/recovery-flashable/
# zip -9r $WORKDIR/output/kernel-$MODEL-$VERSION.zip *

echo done
