ALPINE_VERSION ?= 3.13.5

# Editions should be 5 chars or less because the full name is used as
# the volume id, and cannot exceed 32 characters.
# len("alpine-lima-12345-3.13.5-x86_64") == 31
EDITION ?= std

.PHONY: mkimage
mkimage:
	cd src/aports && git fetch && git checkout v$(ALPINE_VERSION)
	docker build \
		--tag mkimage:$(ALPINE_VERSION) \
		--build-arg ALPINE_VERSION=$(ALPINE_VERSION) \
		.

.PHONY: iso
iso:
	ALPINE_VERSION=$(ALPINE_VERSION) EDITION=$(EDITION) ./build.sh

.PHONY: run
run:
	qemu-system-x86_64 \
		-boot order=d,splash-time=0,menu=on \
		-cdrom iso/alpine-lima-$(EDITION)-$(ALPINE_VERSION)-x86_64.iso \
		-cpu Haswell-v4 \
		-machine q35,accel=hvf \
		-smp 4,sockets=1,cores=4,threads=1 \
		-m 4096 \
		-net nic,model=virtio \
		-net user,net=192.168.5.0/24,hostfwd=tcp:127.0.0.1:20022-:22 \
		-display cocoa \
		-device virtio-rng-pci \
		-device virtio-vga \
		-device virtio-keyboard-pci \
		-device virtio-mouse-pci \
		-parallel none
