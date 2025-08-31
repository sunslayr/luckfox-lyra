FROM arm32v7/ubuntu:jammy
SHELL ["/bin/bash", "-c"]
ENTRYPOINT echo -e "\033[0;32mEntered arm32v7 docker environment\033[0m" && /bin/bash

ENV DEBIAN_FRONTEND=non-interactive
ENV TZ=Etc/UTC
RUN apt update && \
      apt -y install sudo tzdata

RUN \
    groupadd -g 1000 lyra && useradd -u 1000 -g lyra -G sudo -m -s /bin/bash lyra && \
    sed -i /etc/sudoers -re 's/^%sudo.*/%sudo ALL=(ALL:ALL) NOPASSWD: ALL/g' && \
    sed -i /etc/sudoers -re 's/^root.*/root ALL=(ALL:ALL) NOPASSWD: ALL/g' && \
    sed -i /etc/sudoers -re 's/^#includedir.*/## **Removed the include directive** ##"/g' && \
    echo "lyra ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    echo "Customized the sudoers file for passwordless access to the lyra user!" && \
    echo "lyra user:";  su - lyra -c id

RUN \
    apt install -y gcc-10-base=10.3.0-15ubuntu1 && apt install -y cpp-10=10.3.0-15ubuntu1 && \
    apt install -y libgcc-10-dev=10.3.0-15ubuntu1 && apt install -y gcc-10=10.3.0-15ubuntu1 && \
    update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-10 60 --slave /usr/bin/g++ g++ /usr/bin/g++-10

RUN apt update && apt install -y git ssh make libssl-dev \
    liblz4-tool expect expect-dev patchelf chrpath gawk texinfo chrpath \
    diffstat binfmt-support qemu-user-static live-build bison flex fakeroot \
    cmake unzip device-tree-compiler ncurses-dev debootstrap\
    libgucharmap-2-90-dev bzip2 expat gpgv2 libgmp-dev \
    libmpc-dev bc python2 rsync python-is-python3
