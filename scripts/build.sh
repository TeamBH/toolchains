WORKDIR=/root/android/s4/kernel/workshop/
SOURCEDIR=/root/android/s4/kernel/android_kernel_samsung_galaxy_s4/
BOOTDIR=/root/android/s4/kernel/initramfs_samsung_galaxy_s4/GT-I9502/boot-ramdisk-maxfu/
RECOVERYDIR=/root/android/s4/kernel/initramfs_samsung_galaxy_s4/GT-I9502/recovery-ramdisk-twrp/
METADIR=/root/android/s4/kernel/initramfs_samsung_galaxy_s4/recovery-flashable
TOOLCHAIN=/root/android/s4/kernel/toolchains/arm-linux-androideabi-4.6/bin/arm-linux-androideabi-
CONFIG=/root/android/s4/kernel/initramfs_samsung_galaxy_s4/GT-I9502/abootimg.cfg
DEFCONFIG=maxfu_i9502_defconfig
MODEL=i9502
VERSION=v5

echo 'Cleaning workplace...'
cd $WORKDIR
rm -rf temp
rm -rf output

echo 'Making new workplace...'
mkdir $WORKDIR/temp
mkdir $WORKDIR/output
cp -a $SOURCEDIR $WORKDIR/temp/source
cp -a $BOOTDIR $WORKDIR/temp/boot-initramfs
cp -a $RECOVERYDIR $WORKDIR/temp/recovery-initramfs
cp -a $METADIR $WORKDIR/temp/recovery-flashable

echo 'Making kernel and modules...'
cd $WORKDIR/temp/source
export USE_SEC_FIPS_MODE=true
make ARCH=arm CROSS_COMPILE=$TOOLCHAIN clean
make ARCH=arm CROSS_COMPILE=$TOOLCHAIN $DEFCONFIG
make ARCH=arm CROSS_COMPILE=$TOOLCHAIN
find -name zImage -exec cp -av {} $WORKDIR/temp \;
find -name *.ko -exec cp -av {} $WORKDIR/temp/boot-initramfs/lib/modules/ \;
find -name *.ko -exec cp -av {} $WORKDIR/temp/recovery-initramfs/lib/modules/ \;

echo 'Making ramdisks...'
chmod -R g-w $WORKDIR/temp/boot-initramfs/*
chmod -R g-w $WORKDIR/temp/recovery-initramfs/*
cd $WORKDIR/temp/boot-initramfs/
find | cpio -H newc -o --quiet --file=$WORKDIR/temp/boot-initramfs.cpio
cd $WORKDIR/temp/recovery-initramfs/
find | cpio -H newc -o --quiet --file=$WORKDIR/temp/recovery-initramfs.cpio
cd $WORKDIR/temp/
gzip -9 boot-initramfs.cpio
gzip -9 recovery-initramfs.cpio

echo 'Making images...'
abootimg --create $WORKDIR/output/boot.img -f $CONFIG -k $WORKDIR/temp/zImage -r $WORKDIR/temp/boot-initramfs.cpio.gz
abootimg --create $WORKDIR/output/recovery.img -f $CONFIG -k $WORKDIR/temp/zImage -r $WORKDIR/temp/recovery-initramfs.cpio.gz

echo 'Making Odin flashable tarballs...'
cd $WORKDIR/output/
tar -H ustar -cvf boot-$MODEL-$VERSION.tar boot.img
tar -H ustar -cvf recovery-$MODEL-$VERSION.tar recovery.img
tar -H ustar -cvf kernel-$MODEL-$VERSION.tar boot.img recovery.img

echo 'Making CWM/TWRP flashable zips...'
cp -a $WORKDIR/output/*.img $WORKDIR/temp/recovery-flashable/
cd $WORKDIR/temp/recovery-flashable/
zip -9r $WORKDIR/output/kernel-$MODEL-$VERSION.zip *

echo done
