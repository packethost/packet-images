![](https://img.shields.io/badge/Stability-Maintained-green.svg)

# Equinix Metal Images

This repository contains Dockerfiles that we use as the basis for the OSes that we provision. The Dockerfiles contained here are the source for the official Equinix Metal managed images, other semi-official images are managed by the community.

This repository is [Maintained](https://github.com/packethost/standards/blob/master/maintained-statement.md) meaning that this software is supported by Equinix Metal and its community - available to use in production environments.

### Official Images
- [CentOS 7] ([branches](https://github.com/packethost/packet-images/branches/all?query=centos7-))
- [Debian 8] ([branches](https://github.com/packethost/packet-images/branches/all?query=debian8-))
- [Debian 9] ([branches](https://github.com/packethost/packet-images/branches/all?query=debian9-))
- [Debian 10] ([branches](https://github.com/packethost/packet-images/branches/all?query=debian10-))
- [FreeBSD] (not present, [archived branches](https://github.com/packethost/packet-images/branches/all?query=freebsd))
- [OpenSUSE 42.3] ([branches](https://github.com/packethost/packet-images/branches/all?query=opensuse))
- [Scientific Linux 6] ([branches](https://github.com/packethost/packet-images/branches/all?query=scientific))
- [SUSE SLES12 SP3] ([branches](https://github.com/packethost/packet-images/branches/all?query=suse_sles))
- [Ubuntu 14.04] ([branches](https://github.com/packethost/packet-images/branches/all?query=ubuntu_14_04))
- [Ubuntu 16.04] ([branches](https://github.com/packethost/packet-images/branches/all?query=ubuntu_16_04))
- [Ubuntu 18.04] ([branches](https://github.com/packethost/packet-images/branches/all?query=ubuntu_18_04))
- [Ubuntu 19.04 (deprecated)] ([branches](https://github.com/packethost/packet-images/branches/all?query=ubuntu_19_04))
- Virtuozzo (not present)
- VMWare (not present)
- Windows (not present, [archived branches](https://github.com/packethost/packet-images/branches/all?query=windows))

### Semi Official Images
- RancherOS - maintained by [Rancher](https://github.com/rancher)
- Container Linux - maintained by [CoreOS](https://github.com/coreos)
- NixOS - maintained by [@grahamc](https://github.com/grahamc) [NixOS](https://github.com/grahamc/packet-provision-nixos-ipxe)


Within this repo you will find a collection of tools, examples and docs for building OS images to be used on Equinix Metal baremetal servers.

  - Building images from Dockerfile
  - Converting Docker images for use on physical baremetal servers

TLDR:  Build docker image, save docker image to archive and convert the archive to a rootfs
image. The image can be used on a baremetal physical server with or without docker.

### Overview
Branch layout consists of a primary "base" branch for each supported operating system distro. See [centos\_7-base](https://github.com/packethost/packet-images/blob/centos_7-base/x86_64/Dockerfile), [ubuntu\_17\_10-base](https://github.com/packethost/packet-images/blob/ubuntu_17_10-base/x86_64/Dockerfile), etc. The base branch contains a Dockerfile (per supported architecture) with a sufficient level of customization (stage 1) to produce a standardized operating system experience across Equinix Metal's hardware offering. If any hardware specific changes are to be included in a particular image, a separate branch is created for the hardware type / plan the image is customized. Any such hardware specific image is formed by using the base image as the template. For example, if we want to create a new image for ubuntu_17_10-supermachine1, the Dockerfile for this branch will use "FROM ubuntu_17_10-base" as to complete a multi-stage (stage 2) build based off the official Equinix Metal base image.

### Dependencies
There is only a small list of deps required to run image builds, but we recommend a dedicated
machine or VM for this purpose simply to keep things isolated. This repo makes use of [git-lfs](https://git-lfs.github.com/) for installation asset storage and serves as the source of truth for images cached downstream. The build script uses read-tree for bringing together the base and hardware specific branches at build time.

 - Docker 1.1.11 and above (older version may work)
 - JQ
 - A Linux docker host on top of CentOS 7 / Ubuntu 16
 - git-lfs

### Installation
**Using git:**

    git clone git@github.com:packethost/packet-images.git
    sudo cp ./tools/packet-save2image /usr/bin/
    chmod u+x /usr/bin/packet-save2image

**or**

**Using wget**

    sudo wget -O /usr/bin/packet-save2image https://raw.githubusercontent.com/packethost/packet-images/master/tools/packet-save2image
    sudo chmod u+x /usr/bin/packet-*

### Example image build
Here we are walking through an example docker image build, docker image save and conversion.
The branch should contain install assets (image, kernel, initrd, modules) and Dockerfile.
Build tools are intentionally kept separate from operating system branches.
To create a new image you may create an orphan branch (to exclude any pre-existing contents) of the packet-images repo.

    # TODO: Retrieve or create ubuntu_17_10-base image
    [packet-images]$ git checkout --orphan ubuntu_17_10-supermachine1
    [packet-images]$ git rm --cached -r .
    [packet-images]$ vi Dockerfile
    # Fill in Dockerfile with content
    [packet-images]$ echo "RUN apt-get -y install mlx" >> Dockerfile
    [packet-images]$ docker build -t ubuntu_17_10-supermachine1 . && docker save ubuntu_17_10-supermachine1 > ubuntu_17_10-supermachine1.tar && packet-save2image < ubuntu_17_10-supermachine1.tar > image.tar.gz
    [packet-images]$ git lfs track *.tar.gz
    [packet-images]$ git add Dockerfile .gitattributes image.tar.gz
    [packet-images]$ git commit -m "Add Mellanox package for supermachine1"
    [packet-images]$ git push origin ubuntu_17_10-supermachine1
    # get latest commit sha (latest image tag)
    [packet-images]$ git rev-parse --verify HEAD

Using build script method:

    [packet-images]$ ./tools/build.sh -d debian_9 -p t1.small.x86 -a x86_64 -b debian_9-t1.small.x86-dev
    Checking out debian_9-t1.small.x86-dev...
    Switched to and reset branch 'debian_9-t1.small.x86-dev'
    Create read-tree for debian_9-base...
    Create read-tree for debian_9-t1.small.x86...
    Build debian_9-base with docker...
    Build debian_9-t1.small.x86 with docker...
    Save image

Generate CHANGELOG automatically:

    [packet-images]$ ./tools/compare-debian     <previous/old commit sha>
    ======================================================================
    Ovierview:
    ======================================================================
    Image Size
        Current: 320M
        Previous:: 317M
    Filesystem Size
        Current: 897M
        Previous: 893M
    Packages
        Current: 449
    Previous: 448
    Kernel(s)
        Current:
          linux-image-4.9.0-5-amd644.9.65-3+deb9u3
        Previous:
          linux-image-4.9.0-5-amd644.9.65-3+deb9u2
    ======================================================================
    New Packages:
    ======================================================================
    wget1.18-5+deb9u2
    ======================================================================
    Updated Packages:
    libpam-systemd:amd64232-25+deb9u2			      |	libpam-systemd:amd64232-25+deb9u3
    ...snip...
    ======================================================================

### Kernel/Initrd/Modules
Currently, the kernel and related files are separately packaged for later extraction (at installation time) onto the target server filesystem.
The creation of a generic initrd will be attempted from within the Dockerfile using mkinitramfs, dracut or similar.
You may also add your own outside kernel by supplying kernel.tar.gz, initrd.tar.gz and modules.tar.gz.
The default generic initrd (created inside Docker) can be packaged automatically using the tools/archive-$OS helper script.

Archiving the kernel:

    [packet-images]$ ./tools/archive-debian ./image.tar.gz ./
    Kernel file: image-temp/boot/vmlinuz-4.9.0-5-amd64
    Initrd file: image-temp/boot/initrd.img-4.9.0-5-amd64
    Kernel version: 4.9.0-5-amd64
    Temp directory is: /tmp/initrd4me-AI0m6tH
    Archive dir is: ./
    Archiving kernel...
    Total bytes written: 4218880 (4.1MiB, 40MiB/s)
    Archiving initrd...
    Total bytes written: 18432000 (18MiB, 36MiB/s)
    Archiving modules...
    ..................Total bytes written: 186152960 (178MiB, 28MiB/s)
    [packet-images]$ ls -al *.tar.gz | grep -v image
    -rw-r--r-- 1 root root  18316647 May 15 22:24 initrd.tar.gz
    -rw-r--r-- 1 root root   4036476 May 15 22:24 kernel.tar.gz
    -rw-r--r-- 1 root root  50173835 May 15 22:24 modules.tar.gz

### Deploying your custom image on Equinix Metal
You have a working image built, so now what?
Run it using our [custom_image feature](https://metal.equinix.com/developers/docs/operating-systems/custom-images/#deploying-a-custom-image), or use it via [iPXE/Custom OS](https://metal.equinix.com/developers/docs/operating-systems/custom-ipxe/).
