# luckfox-lyra
Luckfox Lyra, Rockchip RK3506 development.

## Install Docker and qemu
- Setup docker for multiplatform
```
docker run --privileged --rm tonistiigi/binfmt --install all; \
sudo mkdir -p /etc/docker/
```
- Configure docker
```
sudo cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "features": {
    "containerd-snapshotter": true
  }
}
EOF
```
- Restart docker
```
sudo systemctl restart docker
```

## Prepare SD card
- Extract SDK
```
mkdir lyra-sdk && tar -xvzf Luckfox_Lyra_SDK_*.tar.gz -C ./lyra-sdk
```
- Switch to docker container
```
docker build --rm -f lyra-ubuntu.dockerfile -t lyra:lyra-build .&& \
docker run --rm -it -v $PWD:/build -w /build --user $(id -u):$(id -g) lyra:lyra-build
```
 
- Expand git
```
sed -i '1s/$/2.7/' lyra-sdk/.repo/repo/repo && \
(cd lyra-sdk && .repo/repo/repo sync -l)
```
- Copy files
```
cp -v source/kernel-devicetree/* lyra-sdk/kernel-6.1/arch/arm/boot/dts/ && \
cp -v source/defconfig/rk3506g_luckfox_lyra_ubuntu_defconfig lyra-sdk/kernel-6.1/arch/arm/configs/ && \
cp -v source/defconfig/luckfox_lyra_ubuntu_defconfig lyra-sdk/device/rockchip/.chips/rk3506/ && \
cp -v source/rk3506_ddr/rk3506_ddr_750MHz_v1.04_uart.bin lyra-sdk/rkbin/bin/rk35/ && \
cp -v source/rk3506_ddr/RK3506MINIALL.ini lyra-sdk/rkbin/RKBOOT/ && \
cp -v source/rk3506_common.h lyra-sdk/u-boot/include/configs/rk3506_common.h 
```
- Configure
```
./lyra-sdk/build.sh lunch
```
- Compile
```
./lyra-sdk/build.sh kernel; \
./lyra-sdk/build.sh kernel-make:dir-pkg:headers_install; \
./lyra-sdk/build.sh uboot
```
- Exit
```
exit
```
- Flashrom
```
sudo ./lyra-sdk/tools/linux/Linux_Upgrade_Tool/Linux_Upgrade_Tool/upgrade_tool wl 0x2000 lyra-sdk/u-boot/uboot.img ; \
sudo ./lyra-sdk/tools/linux/Linux_Upgrade_Tool/Linux_Upgrade_Tool/upgrade_tool wl 0x4000 lyra-sdk/kernel-6.1/zboot.img
sudo ./lyra-sdk/tools/linux/Linux_Upgrade_Tool/Linux_Upgrade_Tool/upgrade_tool UL ./lyra-sdk/u-boot/rk3506_spl_loader_v1.04.110.bin
```
- Arm docker
```
docker build  --platform linux/arm/v7 --rm -f lyra-arm32v7.dockerfile -t lyra:arm32v7-build . ; \
docker run --privileged --platform linux/arm/v7 --rm -it -v $PWD:/build -w /build --user $(id -u):$(id -g) lyra:arm32v7-build
```
- Debootstrap
```
mkdir lyra-rootfs; \
sudo debootstrap jammy lyra-rootfs ; \
sudo mount --bind /dev lyra-rootfs/dev; \
sudo mount --bind /proc lyra-rootfs/proc; \
sudo mount --bind /sys lyra-rootfs/sys; \
sudo mount --bind /dev/pts lyra-rootfs/dev/pts
```
- Copy Files
```
sudo cp -r lyra-sdk/kernel-6.1/tar-install/lib/* lyra-rootfs/usr/lib/; \
sudo cp -r lyra-sdk/kernel/usr/include lyra-rootfs/usr ; \
sudo cp source/scripts/*.service lyra-rootfs/etc/systemd/system; \
sudo cp source/scripts/usb-gadget lyra-rootfs/usr/local/bin/; \
```
- Chroot
```
sudo chroot lyra-rootfs
```
- Update
```
cat <<EOF > /etc/apt/sources.list
deb http://ports.ubuntu.com/ubuntu-ports jammy main universe restricted multiverse
deb http://ports.ubuntu.com/ubuntu-ports jammy-updates main universe restricted multiverse
deb http://ports.ubuntu.com/ubuntu-ports jammy-security main universe restricted multiverse
deb http://ports.ubuntu.com/ubuntu-ports jammy-backports main universe restricted multiverse
EOF
apt update && apt upgrade -y ; \
apt install vim nano network-manager tmux openssh-server usbutils sshfs debootstrap -y
```
- Setup programming environment to match SDK
```
apt install -y gcc-10-base=10.3.0-15ubuntu1 && apt install -y cpp-10=10.3.0-15ubuntu1 && \
    apt install -y libgcc-10-dev=10.3.0-15ubuntu1 && apt install -y gcc-10=10.3.0-15ubuntu1 && \
    update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-10 60 --slave /usr/bin/g++ g++ /usr/bin/g++-10 ; /
apt install -y git ssh make libssl-dev \
    liblz4-tool expect expect-dev patchelf chrpath gawk texinfo chrpath \
    diffstat binfmt-support qemu-user-static live-build bison flex fakeroot \
    cmake unzip device-tree-compiler ncurses-dev debootstrap\
    libgucharmap-2-90-dev bzip2 expat gpgv2 libgmp-dev \
    libmpc-dev bc python2 rsync python-is-python3
```
- Setup network and fs
```
cat <<EOF > /etc/modules.load.d/usb-gadget.conf
# Load libcomposite.ko at boot
libcomposite
EOF
cat <<EOF >> /etc/fstab
/dev/mmcblk0p3 / ext4 rw,relatime 0 0
/dev/mmcblk0p2 none swap sw 0 0
EOF
cat <<EOF > /etc/systemd/network/cdc-rndis.network
[Match]
Name=usb0
[Network]
DHCP=yes
EOF
cat <<EOF > /etc/systemd/network/cdc-ecm.network 
[Match]
Name=usb1
[Network]
DHCP=yes
EOF
```
- Setup OS
```
systemctl enable systemd-networkd \
getty@ttyGS0 \
usb-gadget; \
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config; \
passwd root; \
depmod -b /usr/lib/modules/6.1.99/ -a; \
hostname lyra
```
- Done
```
exit
exit
```
- Copy
```
SDCDEVICE="/dev/sda"; \
sudo mount --mkdir -o loop ${SDCDEVICE}1 boot && \
sudo mount --mkdir -o loop ${SDCDEVICE}3 targetfs && \
sudo rm -r targetfs/* boot/*
sudo rsync -avhP lyra-rootfs/ targetfs/ && sudo sync
sudo cp -rv bootdir/boot.txt boot/ && \
sudo cp -v lyra-sdk/kernel-6.1/arch/arm/boot/zImage \
lyra-sdk/kernel-6.1/arch/arm/boot/dts/rk3506g-luckfox-lyra-ubuntu.dtb boot && \
sudo umount boot targetfs && sudo rm -d boot targetfs
```

