#!/usr/bin/env bash

USAGE="Usage: $0 -d ubuntu_16_04 -p baremetal_0 -a x86_64 -b ubuntu_16_04-baremetal_0-dev
Required Arguments:
	-a arch      System architecture {aarch64|x86_64}
	-d distro    Operating system distro and version
	-p plan      Hardware plan
Options:
	-b branch    Destination branch to checkout (ie: distro-plan-dev)
	-t token     Packet.net auth token
	-h           This help message
	-v           Turn on verbose messages for debugging
Description: This script installs the specified OS from an image file on to one or more block devices and handles the kernel and initrd for the
underlying hardware.
"

while getopts "a:k:M:o:p:x:b:d:f:m:t:u:hv" OPTION; do
	case $OPTION in
	a) arch=$OPTARG ;;
	b) branch=$OPTARG ;;
	d) distro=$OPTARG ;;
	p) plan=$OPTARG ;;
	t)
		# shellcheck disable=SC2034
		token=$OPTARG
		;;
	h) echo "$USAGE" && exit 0 ;;
	v) set -x && export VERBOSE=1 ;;
	*) echo "$USAGE" && exit 1 ;;
	esac
done

set -e -o nounset -o pipefail

echo "Create read-tree for work/$distro-base..."
rm -rf "work/$distro-base/"
git read-tree --prefix="work/$distro-base/" -u "remotes/origin/$distro-base"
git reset HEAD

if [[ ! -d "work/$distro-base/$arch" ]]; then
	echo "$arch doesn't exist for $distro-base! exiting..."
	exit 1
fi

if [[ $arch == aarch64 ]]; then
	wget -qN https://github.com/multiarch/qemu-user-static/releases/download/v2.11.0/qemu-aarch64-static
	echo '6e6829651103fa4d2e009e7e01cfdf39a46ffd53b2297075d9b70de20f965f97  qemu-aarch64-static' | sha256sum -c
	chmod +x qemu-aarch64-static
	cp qemu-aarch64-static "work/$distro-base/$arch"
fi

echo "Create read-tree for $distro-$plan..."
rm -rf "work/$distro-$plan/"
GIT_LFS_SKIP_SMUDGE=1 git read-tree --prefix="work/$distro-$plan/" -u "remotes/origin/$distro-$plan"
git reset HEAD
(
	cd "work/$distro-$plan"
	# shellcheck disable=SC2046
	git lfs checkout $(awk '!/image.tar.gz/ {print $1}' .gitattributes)
)

# shellcheck disable=SC2001
version=$(echo "${distro#*_}" | sed 's|_|.|g')
os=${distro%%_*}
# use image get script for distros we support
case ${os} in
	centos* | ubuntu*) ./tools/"get-$os-image" "$version" "$arch" "work/$distro-base/$arch" ;;
	scientific* | debian* | freebsd* | rhel* | opensuse*) echo "Skipping raw image fetch for $os" ;;
esac

echo "Build $distro-base with docker..."
docker build -t "$distro-base" "work/$distro-base/$arch"

echo "Build $distro-$plan with docker..."
docker build -t "$distro-$plan" "work/$distro-$plan"

#echo "Build branch $branch for $distro-$plan with docker..."
#docker build -q -t $distro-$plan . >/dev/null && \

echo "Save docker image"
# shellcheck disable=SC2024
docker save "$distro-$plan" | fakeroot tools/packet-save2image >"$distro-$plan-image.tar.gz.tmp"
mv "$distro-$plan-image.tar.gz.tmp" "$distro-$plan-image.tar.gz"

if [[ -n ${branch:-} ]]; then
	echo "Checking out $branch..."
	if [[ `git branch --list $branch` ]] ; then
		GIT_LFS_SKIP_SMUDGE=1 git checkout "$branch"
	else
        	echo "Branch $branch doesnt exist yet! Creating..."
		git checkout --orphan $branch
		git rm --cached -r .
	fi

	mv "work/$distro-$plan/"* .
	mv "$distro-$plan-image.tar.gz" image.tar.gz
	./tools/"archive-$os" image.tar.gz ./
	ls -al
	git lfs track *.tar.gz
	OLDIMAGE=$(git ls-remote | grep "refs/heads/$distro-$plan" | awk {'print $1'})
	if [[ -z $OLDIMAGE ]] ; then
        	echo "No OLDIMAGE set! Skipping image compare"
	else
        	echo "OLDIMAGE set"
		echo "Generating CHANGELOG based on previous image $OLDIMAGE"
		touch CHANGELOG
		./tools/compare-$os $OLDIMAGE >> CHANGELOG
	fi

	git add *.tar.gz Dockerfile .gitattributes CHANGELOG

	#echo "commiting and tagging"
	#git add -u
	#git commit -m 'commit artifacts'
	#ALLOW_NON_MASTER=1 git tag-and-release "$branch"
fi

## Push image_tag to Packet
