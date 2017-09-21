images :=
images += distros/centos/7/aarch64/image-rootfs.tar.gz
images += distros/centos/7/x86_64/image-rootfs.tar.gz
images += distros/debian/jessie/x86_64/image-rootfs.tar.gz
#images += distros/scientific/6/x86_64/image-rootfs.tar.gz
images += distros/ubuntu/14.04/x86_64/image-rootfs.tar.gz
images += distros/ubuntu/16.04/aarch64/image-rootfs.tar.gz
images += distros/ubuntu/16.04/x86_64/image-rootfs.tar.gz
images += distros/ubuntu/17.04/x86_64/image-rootfs.tar.gz

dt := $(shell date -u -Iseconds)

FILTER = $(foreach v,$(2),$(if $(findstring $(1),$(v)),$(v),))
ubuntu_rootfses := $(subst image-,,$(strip $(call FILTER,ubuntu,${images})))

ifeq ($V,1)
Q=
else
Q=@
endif
E := $(Q)echo
E +=

all: $(images)

.PHONY: fetch
fetch: $(ubuntu_rootfses)

$(images):
	$(E)"BUILD  $@"
	$(Q)cd $(@D) && \
	docker build -q -t $(subst /,-,$@) --build-arg BUILDDATE=$(dt) . >/dev/null && \
	docker save $(subst /,-,$@) | $(CURDIR)/tools/packet-save2image >$(@F).tmp && \
	mv $(@F).tmp $(@F)

distros/ubuntu/14.04/x86_64/rootfs.tar.gz:
	$(E)"GET    $@"
	$(Q)tools/get-ubuntu-image trusty amd64 $(@D)
distros/ubuntu/16.04/aarch64/rootfs.tar.gz:
	$(E)"GET    $@"
	$(Q)tools/get-ubuntu-image xenial arm64 $(@D)
distros/ubuntu/16.04/x86_64/rootfs.tar.gz:
	$(E)"GET    $@"
	$(Q)tools/get-ubuntu-image xenial amd64 $(@D)
distros/ubuntu/17.04/x86_64/rootfs.tar.gz:
	$(E)"GET    $@"
	$(Q)tools/get-ubuntu-image zesty amd64 $(@D)

# aarch64 needs qemu-aarch64-static
distros/centos/7/aarch64/image-rootfs.tar.gz: distros/centos/7/aarch64/qemu-aarch64-static
distros/ubuntu/16.04/aarch64/image-rootfs.tar.gz: distros/ubuntu/16.04/aarch64/qemu-aarch64-static

# aarch64 cloud images
distros/ubuntu/16.04/aarch64/image-rootfs.tar.gz: distros/ubuntu/16.04/aarch64/rootfs.tar.gz

# x86_64 cloud images
distros/ubuntu/14.04/x86_64/image-rootfs.tar.gz: distros/ubuntu/14.04/x86_64/rootfs.tar.gz
distros/ubuntu/16.04/x86_64/image-rootfs.tar.gz: distros/ubuntu/16.04/x86_64/rootfs.tar.gz
distros/ubuntu/17.04/x86_64/image-rootfs.tar.gz: distros/ubuntu/17.04/x86_64/rootfs.tar.gz

qemu-aarch64-static: /proc/sys/fs/binfmt_misc/aarch64
	$(E)"GET    $@"
	$(Q)wget -qN https://github.com/multiarch/qemu-user-static/releases/download/v2.9.1/$@.tar.gz && \
	tar -zxf $@.tar.gz && touch $@

distros/ubuntu/16.04/aarch64/qemu-aarch64-static: qemu-aarch64-static
	$(Q)install -m 755 $^ $@

distros/centos/7/aarch64/qemu-aarch64-static: qemu-aarch64-static
	$(Q)install -m 755 $^ $@

/proc/sys/fs/binfmt_misc/aarch64:
	$(E) 'You need to configure qemu-aarch64-static for aarch64 programs, for example:'
	$(E)
	$(E) '        docker run --rm --privileged multiarch/qemu-user-static:register --reset'
	$(E)
	$(E) 'and can disable all binfmt with:'
	$(E)
	$(E) '        echo -1 > /proc/sys/fs/binfmt_misc/status'
	$(E)
	$(Q)exit 1

clean:
	rm -f qemu-aarch64-static distros/ubuntu/16.04/aarch64/qemu-aarch64-static distros/centos/7/aarch64/qemu-aarch64-static $(ubuntu_rootfses) $(images)
