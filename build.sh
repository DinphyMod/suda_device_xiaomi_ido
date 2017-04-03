#!/bin/bash
readonly txtrst=$(tput sgr0) # 
device=$1
buildDate=$(date +%Y%m%d%H%M)

export SM_BUILD_DATE=$buildDate
if [ ! "$CCACHE_DIR" ] && [ "$USE_CCACHE" = 1 ]; then
	echo "正在设置CCACHE路径，稍等.."
	export CCACHE_DIR=/media/dinphy/DinphyMod/.ccache
fi
if [ "$CCACHE_DIR" ]
then
	if [ ! -d "$CCACHE_DIR" ]; then
	  mkdir -p "$CCACHE_DIR"
	fi
	BASE_CCACHE_DIR=$(echo ${CCACHE_DIR%%/sm_*})
	export CCACHE_DIR=$BASE_CCACHE_DIR/$device
	if [ -z "$CCACHE_SIZE" ]; then
	    CCACHE_SIZE=50G
	fi
	echo "正在设置CCACHE空间，稍等.."
	prebuilts/misc/linux-x86/ccache/ccache -M $CCACHE_SIZE
fi
echo "正在设置VM虚拟内存，稍等.."
export JACK_SERVER_VM_ARGUMENTS="-Dfile.encoding=UTF-8 -XX:+TieredCompilation -Xmx8192m"
export SM_BUILDTYPE=UNOFFICIAL

echo -e "$txtrst"

# Set text colors
readonly grn=$(tput setaf 2) #  green

function info {
  echo "$txtrst${grn}$*$txtrst"
}

function askyn {
  local question=$1
  local default=$2
  local prompt response
  case "$default" in
    y|Y) prompt="$txtrst$grn$question [Y/n]? $txtrst"; default="y";;
    n|N) prompt="$txtrst$grn$question [y/N]? $txtrst"; default="n";;
     '') prompt="$txtrst$grn$question [y/n]? $txtrst";;
      *) echo "Error in script"; exit 1;;
  esac

  while :; do
    read -n 1 -rp "$prompt" response
    [[ -n $response ]] && echo >&2
    if [[ $response =~ ^[Yy]([Ee][Ss])?$ ]]; then
      [ -t 1 ] || echo y
      return 0
    elif [[ $response =~ ^[Nn]([Oo])?$ ]]; then
      [ -t 1 ] || echo n
      return 1
    elif [[ -z $reponse && -n $default ]]; then
      [ -t 1 ] || echo $default
      [[ $default = y ]]
      return $?
    fi
  done
}

if [ "$1" = "" ]; then
  info "错了，请输入< ./build.sh codename >开始构建"
  info ""
  exit 1
fi

info "构建时间:$buildDate"
info "构建机型:$device"
echo -e "$txtrst"

BP=$(askyn "是否在编译前移除build.prop?(推荐)" $BP)
QCLEAN=$(askyn "你想在编译前执行mka installclean吗?(快速清理)" $QCLEAN)
CLEAN=$(askyn "你想在编译前执行make clean吗?(清理较慢, 将清理out文件夹所有文件...)" $CLEAN)


TST=$(date +%s)

info "正在构建 $device"
source build/envsetup.sh
croot
lunch sm_$device-userdebug

if [ "$BP" = y ]; then
  info "正在执行移除 build.prop"
  rm -f out/target/product/$device/system/build.prop
fi

if [ "$CLEAN" = y ]; then
  info "正在执行完全清理..."
    make clean
fi

if [ "$QCLEAN" = y ]; then
  info "正在执行部分清理..."
  mka installclean
fi

if [ -f out/target/product/$device/obj/PACKAGING/target_files_intermediates/*".zip" ]; then 
    rm out/target/product/$device/obj/PACKAGING/target_files_intermediates/*".zip";
fi

if [ -f out/target/product/$device/*"OFFICIAL-$device.zip" ]; then 
    rm out/target/product/$device/*"OFFICIAL-$device.zip"
fi

info "现在，开始编译$device..."
brunch $device

if [ ! -d suda_rom ];then 
    mkdir suda_rom
fi

if [ ! -d suda_rom/$device ];then 
    mkdir suda_rom/$device
fi

if [ -f out/target/product/$device/*"OFFICIAL-$device.zip" ]; then 
    mv out/target/product/$device/*"OFFICIAL-$device.zip" suda_rom/$device
    mv out/target/product/$device/*"OFFICIAL-$device.zip.md5sum" suda_rom/$device
fi

if [ -f out/target/product/$device/obj/PACKAGING/target_files_intermediates/*".zip" ]; then 
    mv out/target/product/$device/obj/PACKAGING/target_files_intermediates/*".zip" suda_rom/$device/"$device-$buildDate-target.zip"
fi

echo ""
TET=$(date +%s)
info "编译完成，总共用了 $(((TET-TST)/60)) 分 $(((TET-TST)%60)) 秒.."
echo "$txtrst"
echo ""
