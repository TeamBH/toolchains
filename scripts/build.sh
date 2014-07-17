echo 'Setting parameters...'
export SOURCEDIR=/root/android/android_kernel_samsung_exynos5410
export INITRDDIR=/root/android/initramfs_samsung_galaxy_s4
export TCHAINDIR=/root/android/toolchains
export WORKDIR=/root/android/workspace
export ARCH=arm
export USE_SEC_FIPS_MODE=true
export SEC_BUILD_OPTION_SELINUX_ENFORCE=false
ccache 1>/dev/null 2>/dev/null
if [ "$?" == "127" ]; then
  export USE_CCACHE=0
else
  export USE_CCACHE=1
fi

echo 'Setting Model...'
INDEX=1
HEAD=''
for i in `ls $INITRDDIR`; do
  if `echo $i | grep -q ja3g`; then
    HEAD=$HEAD''$INDEX
    echo $INDEX' - '`echo $i | sed -e s/ja3g_open/'Galaxy S4 International: GT-I9500'/g \
                                   -e s/ja3gduos_chn_ctc/'Galaxy S4 Duos CDMA2000: SCH-I959'/g \
                                   -e s/ja3gduos_chn_cu/'Galaxy S4 Duos WCDMA-3G: GT-I9502'/g`
    eval MODEL$INDEX=$i
    INDEX=`expr $INDEX + 1`
  fi
done
read -p 'Please Choose a Model, ('$HEAD')>' NUM
if [ -z $NUM ]; then
  NUM=`expr $INDEX - 1`
  echo 'Nothing input, use '$NUM
fi
CHOICE=MODEL$NUM
eval export MODEL=\$$CHOICE

echo 'Setting SDK...'
INDEX=1
HEAD=''
for i in `ls $INITRDDIR/$MODEL`; do
  if `echo $i | grep -q boot`; then
    HEAD=$HEAD''$INDEX
    echo $INDEX' - '`echo $i | sed -e 's/boot.//g' -e 's/.img//g' \
                                   -e 's/sdk18/TouchWiz 4.3/g' -e 's/sdk19/TouchWiz 4.4.2/g' \
                                   -e 's/aosp18/AndroidOpensource 4.3/g' -e 's/aosp19/AndroidOpensource 4.4.2/g'`
    eval SDK$INDEX=`echo $i | sed -e 's/boot.//g' -e 's/.img//g'`
    INDEX=`expr $INDEX + 1`
  fi
done
read -p 'Please Choose a SDK, ('$HEAD')>' NUM
if [ -z $NUM ]; then
  NUM=`expr $INDEX - 1`
  echo 'Nothing input, use '$NUM
fi
CHOICE=SDK$NUM
eval export SDK=\$$CHOICE
export BOOTIMG=$INITRDDIR/$MODEL/boot.$SDK.img
export RECOVERYCPIO=$INITRDDIR/$MODEL/recovery.cpio.lzma

echo 'Setting Toolchain...'
SUBARCH=`uname -m | sed -e s/i.86/i386/ -e s/sun4u/sparc64/ \
				  -e s/arm.*/arm/ -e s/sa110/arm/ \
				  -e s/s390x/s390/ -e s/parisc64/parisc/ \
				  -e s/ppc.*/powerpc/ -e s/mips.*/mips/ \
				  -e s/sh[234].*/sh/`
INDEX=1
HEAD=''
for i in `ls $TCHAINDIR/$SUBARCH`; do
  if `echo $i | grep -q $ARCH`; then
    HEAD=$HEAD''$INDEX
    echo $INDEX' - '$i
    eval TCHAIN$INDEX=$TCHAINDIR/$SUBARCH/$i/bin/${i%eabi*}eabi-
    INDEX=`expr $INDEX + 1`
  fi
done
read -p 'Please Choose a Toolchain, ('$HEAD')>' NUM
if [ -z $NUM ]; then
  NUM=`expr $INDEX - 1`
  echo 'Nothing input, use '$NUM
fi
CHOICE=TCHAIN$NUM
eval export CROSS_COMPILE=\$$CHOICE
export SYSROOT=$TCHAINDIR/$SUBARCH/sysroot/

echo 'Setting version'
VERSION=v15
echo 'Last version used is '$VERSION
read -p 'Please Input a new version, input nothing to use the old one...>' NEWVER
if [ ! -z $NEWVER ]; then
  sed -i "s/VERSION=$VERSION/VERSION=$NEWVER/g" $0
  VERSION=$NEWVER
fi
LOCALVERSION=`echo -$MODEL-$VERSION | sed -e s/ja3g_open/i9500/g -e s/ja3gduos_chn_ctc/i959/g -e s/ja3gduos_chn_cu/i9502/g`
echo $LOCALVERSION

echo 'Setting workspace...'
rm -rf $WORKDIR
mkdir $WORKDIR
cd $WORKDIR
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
cd $SOURCEDIR
git add --all > /dev/null
git commit --all --message="Change Until `date`" > /dev/null
if [ $? == 0 ]; then
  PATCH=`git format-patch HEAD~1 -o $WORKDIR`
fi
# cat $SOURCEDIR/arch/arm/configs/ja3g_00_defconfig \
#     $SOURCEDIR/arch/arm/configs/ja3gduos_chn_cu \
#     $SOURCEDIR/arch/arm/configs/ja3g_maxfu \
#     $SOURCEDIR/arch/arm/configs/ja3g_sdk19 > $SOURCEDIR/arch/arm/configs/temp_defconfig
# make temp_defconfig
make ja3gduos_chn_cu_defconfig
make -j3
find -name zImage -exec cp -av {} $WORKDIR/ \;
find -name *.ko -exec cp -av {} $WORKDIR/boot-initramfs/lib/modules/ \;
find -name *.ko -exec cp -av {} $WORKDIR/recovery-initramfs/lib/modules/ \;

echo 'Making ramdisks...'
chmod -R g-w $WORKDIR/boot-initramfs/*
chmod -R g-w $WORKDIR/recovery-initramfs/*
( cd $WORKDIR/boot-initramfs; find | sort | cpio --quiet -o -H newc ) | lzma > $WORKDIR/boot-initramfs.cpio.lzma
( cd $WORKDIR/recovery-initramfs; find | sort | cpio --quiet -o -H newc ) | lzma > $WORKDIR/recovery-initramfs.cpio.lzma

echo 'Making images...'
abootimg --create $WORKDIR/boot.img -f $WORKDIR/bootimg.cfg -k $WORKDIR/zImage -r $WORKDIR/boot-initramfs.cpio.lzma
abootimg --create $WORKDIR/recovery.img -f $WORKDIR/bootimg.cfg -k $WORKDIR/zImage -r $WORKDIR/recovery-initramfs.cpio.lzma

echo 'Making Odin flashable tarballs...'
cd $WORKDIR/
tar -cvf boot-$LOCALVERSION.tar boot.img
tar -cvf recovery-$LOCALVERSION.tar recovery.img

# echo 'Making CWM/TWRP flashable zips...'
# cp -a $WORKDIR/output/*.img $WORKDIR/temp/recovery-flashable/
# cd $WORKDIR/temp/recovery-flashable/
# zip -9r $WORKDIR/output/kernel-$MODEL-$VERSION.zip *

echo 'Cleaning Source...'
cd $SOURCEDIR
git add --all > /dev/null
git commit --all --message="Compile Rubbish of `date`"  > /dev/null
if [ $? == 0 ]; then
  git reset --hard HEAD~1 > /dev/null
fi
if [ ! -z $PATCH ]; then
  git reset --hard HEAD~1 > /dev/null
  git apply $PATCH
fi

echo done
