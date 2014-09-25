echo 'Setting parameters...'
export BASEDIR=`pwd`
export SOURCEDIR=$BASEDIR/android_kernel_samsung_exynos5410
export INITRDDIR=$BASEDIR/initramfs_samsung_galaxy_s4
export TCHAINDIR=$BASEDIR/toolchains
export WORKDIR=$BASEDIR/workspace
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
BASECONFIG=$i'_00_defconfig'
  if [ -f $SOURCEDIR/arch/arm/configs/$BASECONFIG ]; then
    if `echo $i | grep -q ja3g`; then
      HEAD=$HEAD''$INDEX
      echo $INDEX' - '`echo $i | sed -e s/ja3gduos_chn_cu/'Galaxy S4 Duos WCDMA-3G: GT-I9502'/g \
                                     -e s/ja3gduos_chn_ctc/'Galaxy S4 Duos CDMA2000: SCH-I959'/g \
                                     -e s/ja3g_chn_open/'Galaxy S4 International: GT-I9500'/g`
      eval MODEL$INDEX=$i
      INDEX=`expr $INDEX + 1`
    fi
  fi
done
read -p 'Please Choose a Model, ('$HEAD')>' NUM
if [ -z $NUM ]; then
  NUM=`expr $INDEX - 1`
  echo 'Nothing input, use '$NUM
fi
CHOICE=MODEL$NUM
eval export MODEL=\$$CHOICE
BASECONFIG=$MODEL'_00_defconfig'
MODCONFIG=ja3g_maxfu

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
export RECOVERYCPIOCN=$INITRDDIR/$MODEL/recovery-chinese.cpio.lzma
export RECOVERYCPIOEN=$INITRDDIR/$MODEL/recovery-english.cpio.lzma

echo 'Setting Toolchain...'
SYSTEM=`uname`
SUBARCH=`uname -m | sed -e s/i.86/i386/ -e s/sun4u/sparc64/ -e s/arm.*/arm/ -e s/sa110/arm/ \
				  -e s/s390x/s390/ -e s/parisc64/parisc/ -e s/ppc.*/powerpc/ -e s/mips.*/mips/ \
				  -e s/sh[234].*/sh/`
INDEX=1
HEAD=''
for i in `ls $TCHAINDIR/$SYSTEM/$SUBARCH`; do
  if `echo $i | grep -q $ARCH`; then
    HEAD=$HEAD''$INDEX
    echo $INDEX' - '$i
    eval TCHAIN$INDEX=$TCHAINDIR/$SYSTEM/$SUBARCH/$i/bin/${i%eabi*}eabi-
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
API=`echo $SDK | sed 's/aosp/sdk/g'`
export SYSROOT=$TCHAINDIR/$SYSTEM/$SUBARCH/sysroot/$API/

echo 'Setting version'
VERSION=v16b3
echo 'Last version used is '$VERSION
read -p 'Please Input a new version, input nothing to use the old one...>' NEWVER
if [ ! -z $NEWVER ]; then
  sed -i "s/VERSION=$VERSION/VERSION=$NEWVER/g" $0
  VERSION=$NEWVER
fi
export LOCALVERSION=`echo -$MODEL-$VERSION | sed -e s/ja3gduos_chn_ctc/i959/g -e s/ja3gduos_chn_cu/i9502/g -e s/ja3g_chn_open/i9500/g`
KERNELPACK='kernel'$LOCALVERSION

echo 'Setting workspace...'
rm -rf $WORKDIR
mkdir $WORKDIR
cd $WORKDIR
cp -a $BOOTIMG $WORKDIR/boot.stock.img
$TCHAINDIR/$SYSTEM/$SUBARCH/abootimg/abootimg -x boot.stock.img
sed -i '/bootsize/d' $WORKDIR/bootimg.cfg
mv zImage zImage.stock
mv initrd.img initrd.stock.img
mkdir $WORKDIR/boot-ramdisk-lite
$TCHAINDIR/$SYSTEM/$SUBARCH/busybox/busybox zcat $WORKDIR/initrd.stock.img | ( cd $WORKDIR/boot-ramdisk-lite; cpio -i )
mkdir $WORKDIR/boot-ramdisk-full
$TCHAINDIR/$SYSTEM/$SUBARCH/busybox/busybox zcat $WORKDIR/initrd.stock.img | ( cd $WORKDIR/boot-ramdisk-full; cpio -i )
if [ -d $WORKDIR/boot-ramdisk-full/lib/modules/ ]; then
  find $WORKDIR/boot-ramdisk-full/lib/modules/ -name *.ko -exec rm -f {} \;
else
  mkdir -p $WORKDIR/boot-ramdisk-full/lib/modules/
fi
cp -a $RECOVERYCPIOCN $WORKDIR/
mkdir $WORKDIR/recovery-ramdisk-chinese
$TCHAINDIR/$SYSTEM/$SUBARCH/busybox/busybox lzcat $WORKDIR/recovery-chinese.cpio.lzma | ( cd $WORKDIR/recovery-ramdisk-chinese; cpio -i )
if [ -d $WORKDIR/recovery-ramdisk-chinese/lib/modules/ ]; then
  find $WORKDIR/recovery-ramdisk-chinese/lib/modules/ -name *.ko -exec rm -f {} \;
else
  mkdir -p $WORKDIR/recovery-ramdisk-chinese/lib/modules/
fi
cp -a $RECOVERYCPIOEN $WORKDIR/
mkdir $WORKDIR/recovery-ramdisk-english
$TCHAINDIR/$SYSTEM/$SUBARCH/busybox/busybox lzcat $WORKDIR/recovery-english.cpio.lzma | ( cd $WORKDIR/recovery-ramdisk-english; cpio -i )
if [ -d $WORKDIR/recovery-ramdisk-english/lib/modules/ ]; then
  find $WORKDIR/recovery-ramdisk-english/lib/modules/ -name *.ko -exec rm -f {} \;
else
  mkdir -p $WORKDIR/recovery-ramdisk-english/lib/modules/
fi



echo 'Setting post-init services'
echo '1. init.d support: run shell scripts in /system/etc/init.d after kernel inited.'
echo '2. STweaks support: Make the kernel support STweaks app.'
echo '3. Entropy generator: Reduce lag.'
echo '4. Wolfson Sound Control: For i 9500 only, currently not working.'
echo '5. Tweaks: Some tweaks, not suggested.'

read -p 'Please input the number(s) of the service(s) you want, eg. 4,23,12345, suggest at least 1)>' SERVNUM
SERVLIST='none'
if echo $SERVNUM | grep -q 1; then
  cp -a $INITRDDIR/addons/initd/sbin/* $WORKDIR/boot-ramdisk-lite/sbin/
  cat $INITRDDIR/addons/initd/init.rc.catrd >> $WORKDIR/boot-ramdisk-lite/init.rc
  cp -a $INITRDDIR/addons/initd/sbin/* $WORKDIR/boot-ramdisk-full/sbin/
  cat $INITRDDIR/addons/initd/init.rc.catrd >> $WORKDIR/boot-ramdisk-full/init.rc
  SERVLIST=`echo $SERVLIST | sed -e s/none//g`' init.d'
fi
if echo $SERVNUM | grep -q 2; then
  cp -a $INITRDDIR/addons/stweaks/sbin/* $WORKDIR/boot-ramdisk-lite/sbin/
  cp -a $INITRDDIR/addons/stweaks/res $WORKDIR/boot-ramdisk-lite/
  cat $INITRDDIR/addons/stweaks/init.rc.catrd >> $WORKDIR/boot-ramdisk-lite/init.rc
  cp -a $INITRDDIR/addons/stweaks/sbin/* $WORKDIR/boot-ramdisk-full/sbin/
  cp -a $INITRDDIR/addons/stweaks/res $WORKDIR/boot-ramdisk-full/
  cat $INITRDDIR/addons/stweaks/init.rc.catrd >> $WORKDIR/boot-ramdisk-full/init.rc
  SERVLIST=`echo $SERVLIST | sed -e s/none//g`' STweaks'
fi
if echo $SERVNUM | grep -q 3; then
  cp -a $INITRDDIR/addons/rngd/sbin/* $WORKDIR/boot-ramdisk-lite/sbin/
  cat $INITRDDIR/addons/rngd/init.rc.catrd >> $WORKDIR/boot-ramdisk-lite/init.rc
  cp -a $INITRDDIR/addons/rngd/sbin/* $WORKDIR/boot-ramdisk-full/sbin/
  cat $INITRDDIR/addons/rngd/init.rc.catrd >> $WORKDIR/boot-ramdisk-full/init.rc
  SERVLIST=`echo $SERVLIST | sed -e s/none//g`' RNGD'
fi
if echo $SERVNUM | grep -q 4; then
  cp -a $INITRDDIR/addons/wolfsoncontrol/sbin/* $WORKDIR/boot-ramdisk-lite/sbin/
  cat $INITRDDIR/addons/wolfsoncontrol/init.rc.catrd >> $WORKDIR/boot-ramdisk-lite/init.rc
  cp -a $INITRDDIR/addons/wolfsoncontrol/sbin/* $WORKDIR/boot-ramdisk-full/sbin/
  cat $INITRDDIR/addons/wolfsoncontrol/init.rc.catrd >> $WORKDIR/boot-ramdisk-full/init.rc
  SERVLIST=`echo $SERVLIST | sed -e s/none//g`' Wolfsoncontrol'
fi
if echo $SERVNUM | grep -q 5; then
  cp -a $INITRDDIR/addons/tweaks/sbin/* $WORKDIR/boot-ramdisk-lite/sbin/
  cat $INITRDDIR/addons/tweaks/init.rc.catrd >> $WORKDIR/boot-ramdisk-lite/init.rc
  cp -a $INITRDDIR/addons/tweaks/sbin/* $WORKDIR/boot-ramdisk-full/sbin/
  cat $INITRDDIR/addons/tweaks/init.rc.catrd >> $WORKDIR/boot-ramdisk-full/init.rc
  SERVLIST=`echo $SERVLIST | sed -e s/none//g`' Tweaks'
fi

echo 'About to compile the kernel...'
echo 'Model: '`echo $MODEL | sed -e s/ja3gduos_chn_cu/'Galaxy S4 Duos WCDMA-3G: GT-I9502'/g \
                                     -e s/ja3gduos_chn_ctc/'Galaxy S4 Duos CDMA2000: SCH-I959'/g \
                                     -e s/ja3g_chn_open/'Galaxy S4 International: GT-I9500'/g`'.'
echo 'Version: 3.4.5-MaxFour'$LOCALVERSION
echo 'Android SDK: '`echo $SDK | sed -e 's/sdk18/TouchWiz 4.3/g' -e 's/sdk19/TouchWiz 4.4.2/g' \
                                     -e 's/aosp18/AndroidOpensource 4.3/g' -e 's/aosp19/AndroidOpensource 4.4.2/g'`
echo 'SYSROOT: '$SYSROOT
echo 'Services: '$SERVLIST
echo 'Result: '$WORKDIR'/'$KERNELPACK
read -p 'Input anything with ENTER to continue.>' INPUT

echo 'Making kernel and modules...'
cd $SOURCEDIR
git add --all > /dev/null
git commit --all --message="Change Until `date`" > /dev/null
if [ $? == 0 ]; then
  PATCH=`git format-patch HEAD~1 -o $WORKDIR`
fi
cat $SOURCEDIR/arch/arm/configs/$BASECONFIG \
    $SOURCEDIR/arch/arm/configs/$MODCONFIG > $SOURCEDIR/arch/arm/configs/temp_defconfig
make temp_defconfig 1>$WORKDIR/normal.output.txt 2>$WORKDIR/critial.output.txt
make -j3 1>>$WORKDIR/normal.output.txt 2>>$WORKDIR/critial.output.txt
find -name zImage -exec cp -av {} $WORKDIR/ \;
find -name *.ko -exec cp -av {} $WORKDIR/boot-ramdisk-full/lib/modules/ \;
find -name *.ko -exec cp -av {} $WORKDIR/recovery-ramdisk-chinese/lib/modules/ \;
find -name *.ko -exec cp -av {} $WORKDIR/recovery-ramdisk-english/lib/modules/ \;

echo 'Making ramdisks...'
chmod -R g-w $WORKDIR/boot-ramdisk-lite/*
( cd $WORKDIR/boot-ramdisk-lite; find | sort | cpio --quiet -o -H newc ) | gzip > $WORKDIR/boot-ramdisk-lite.cpio.gzip
chmod -R g-w $WORKDIR/boot-ramdisk-full/*
( cd $WORKDIR/boot-ramdisk-full; find | sort | cpio --quiet -o -H newc ) | lzma > $WORKDIR/boot-ramdisk-full.cpio.lzma
chmod -R g-w $WORKDIR/recovery-ramdisk-chinese/*
( cd $WORKDIR/recovery-ramdisk-chinese; find | sort | cpio --quiet -o -H newc ) | lzma > $WORKDIR/recovery-ramdisk-chinese.cpio.lzma
chmod -R g-w $WORKDIR/recovery-ramdisk-english/*
( cd $WORKDIR/recovery-ramdisk-english; find | sort | cpio --quiet -o -H newc ) | lzma > $WORKDIR/recovery-ramdisk-english.cpio.lzma

echo 'Making images...'
rm -rf $WORKDIR/$KERNELPACK
mkdir $WORKDIR/$KERNELPACK
$TCHAINDIR/$SYSTEM/$SUBARCH/abootimg/abootimg --create $WORKDIR/$KERNELPACK/boot-lite.img -f $WORKDIR/bootimg.cfg -k $WORKDIR/zImage.stock -r $WORKDIR/boot-ramdisk-lite.cpio.gzip
$TCHAINDIR/$SYSTEM/$SUBARCH/abootimg/abootimg --create $WORKDIR/$KERNELPACK/boot-full.img -f $WORKDIR/bootimg.cfg -k $WORKDIR/zImage -r $WORKDIR/boot-ramdisk-full.cpio.lzma
$TCHAINDIR/$SYSTEM/$SUBARCH/abootimg/abootimg --create $WORKDIR/$KERNELPACK/recovery-chinese.img -f $WORKDIR/bootimg.cfg -k $WORKDIR/zImage -r $WORKDIR/recovery-ramdisk-chinese.cpio.lzma
$TCHAINDIR/$SYSTEM/$SUBARCH/abootimg/abootimg --create $WORKDIR/$KERNELPACK/recovery-english.img -f $WORKDIR/bootimg.cfg -k $WORKDIR/zImage -r $WORKDIR/recovery-ramdisk-english.cpio.lzma

echo 'Making Odin flashable tarballs...'
cd $WORKDIR/$KERNELPACK/
cp -a $WORKDIR/$KERNELPACK/boot-lite.img $WORKDIR/$KERNELPACK/boot.img
cp -a $WORKDIR/$KERNELPACK/recovery-chinese.img $WORKDIR/$KERNELPACK/recovery.img
$TCHAINDIR/$SYSTEM/$SUBARCH/busybox/busybox tar -cvf $WORKDIR/$KERNELPACK/$KERNELPACK-lite-cn.tar boot.img recovery.img
md5sum -t $WORKDIR/$KERNELPACK/$KERNELPACK-lite-cn.tar >> $WORKDIR/$KERNELPACK/$KERNELPACK-lite-cn.tar
mv $WORKDIR/$KERNELPACK/$KERNELPACK-lite-cn.tar $WORKDIR/$KERNELPACK/$KERNELPACK-lite-cn.tar.md5
rm $WORKDIR/$KERNELPACK/boot.img
rm $WORKDIR/$KERNELPACK/recovery.img
cp -a $WORKDIR/$KERNELPACK/boot-full.img $WORKDIR/$KERNELPACK/boot.img
cp -a $WORKDIR/$KERNELPACK/recovery-chinese.img $WORKDIR/$KERNELPACK/recovery.img
$TCHAINDIR/$SYSTEM/$SUBARCH/busybox/busybox tar -cvf $WORKDIR/$KERNELPACK/$KERNELPACK-full-cn.tar boot.img recovery.img
md5sum -t $WORKDIR/$KERNELPACK/$KERNELPACK-full-cn.tar >> $WORKDIR/$KERNELPACK/$KERNELPACK-full-cn.tar
mv $WORKDIR/$KERNELPACK/$KERNELPACK-full-cn.tar $WORKDIR/$KERNELPACK/$KERNELPACK-full-cn.tar.md5
rm $WORKDIR/$KERNELPACK/boot.img
rm $WORKDIR/$KERNELPACK/recovery.img
cp -a $WORKDIR/$KERNELPACK/boot-lite.img $WORKDIR/$KERNELPACK/boot.img
cp -a $WORKDIR/$KERNELPACK/recovery-english.img $WORKDIR/$KERNELPACK/recovery.img
$TCHAINDIR/$SYSTEM/$SUBARCH/busybox/busybox tar -cvf $WORKDIR/$KERNELPACK/$KERNELPACK-lite-en.tar boot.img recovery.img
md5sum -t $WORKDIR/$KERNELPACK/$KERNELPACK-lite-en.tar >> $WORKDIR/$KERNELPACK/$KERNELPACK-lite-en.tar
mv $WORKDIR/$KERNELPACK/$KERNELPACK-lite-en.tar $WORKDIR/$KERNELPACK/$KERNELPACK-lite-en.tar.md5
rm $WORKDIR/$KERNELPACK/boot.img
rm $WORKDIR/$KERNELPACK/recovery.img
cp -a $WORKDIR/$KERNELPACK/boot-full.img $WORKDIR/$KERNELPACK/boot.img
cp -a $WORKDIR/$KERNELPACK/recovery-english.img $WORKDIR/$KERNELPACK/recovery.img
$TCHAINDIR/$SYSTEM/$SUBARCH/busybox/busybox tar -cvf $WORKDIR/$KERNELPACK/$KERNELPACK-full-en.tar boot.img recovery.img
md5sum -t $WORKDIR/$KERNELPACK/$KERNELPACK-full-en.tar >> $WORKDIR/$KERNELPACK/$KERNELPACK-full-en.tar
mv $WORKDIR/$KERNELPACK/$KERNELPACK-full-en.tar $WORKDIR/$KERNELPACK/$KERNELPACK-full-en.tar.md5
rm $WORKDIR/$KERNELPACK/boot.img
rm $WORKDIR/$KERNELPACK/recovery.img

echo 'Making CWM/TWRP flashable zips...'
cp -a $INITRDDIR/recovery-flashable $WORKDIR
cp -a $WORKDIR/$KERNELPACK/boot-lite.img $WORKDIR/recovery-flashable/boot.img
cp -a $WORKDIR/$KERNELPACK/recovery-chinese.img $WORKDIR/recovery-flashable/recovery.img
cd $WORKDIR/recovery-flashable/
zip -9r $WORKDIR/$KERNELPACK/$KERNELPACK-lite-cn.zip *
rm $WORKDIR/recovery-flashable/boot.img
rm $WORKDIR/recovery-flashable/recovery.img
cp -a $WORKDIR/$KERNELPACK/boot-full.img $WORKDIR/recovery-flashable/boot.img
cp -a $WORKDIR/$KERNELPACK/recovery-chinese.img $WORKDIR/recovery-flashable/recovery.img
cd $WORKDIR/recovery-flashable/
zip -9r $WORKDIR/$KERNELPACK/$KERNELPACK-full-cn.zip *
rm $WORKDIR/recovery-flashable/boot.img
rm $WORKDIR/recovery-flashable/recovery.img
cp -a $WORKDIR/$KERNELPACK/boot-lite.img $WORKDIR/recovery-flashable/boot.img
cp -a $WORKDIR/$KERNELPACK/recovery-english.img $WORKDIR/recovery-flashable/recovery.img
cd $WORKDIR/recovery-flashable/
zip -9r $WORKDIR/$KERNELPACK/$KERNELPACK-lite-en.zip *
rm $WORKDIR/recovery-flashable/boot.img
rm $WORKDIR/recovery-flashable/recovery.img
cp -a $WORKDIR/$KERNELPACK/boot-full.img $WORKDIR/recovery-flashable/boot.img
cp -a $WORKDIR/$KERNELPACK/recovery-english.img $WORKDIR/recovery-flashable/recovery.img
cd $WORKDIR/recovery-flashable/
zip -9r $WORKDIR/$KERNELPACK/$KERNELPACK-full-en.zip *
rm $WORKDIR/recovery-flashable/boot.img
rm $WORKDIR/recovery-flashable/recovery.img

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
