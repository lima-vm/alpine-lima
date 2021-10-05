ALPINE_VERSION ?= 3.13.5
REPO_VERSION ?= $(shell echo "$(ALPINE_VERSION)" | sed -E 's/^([0-9]+\.[0-9]+).*/v\1/')
GIT_TAG ?= $(shell echo "v$(ALPINE_VERSION)" | sed 's/^vedge$$/origin\/master/')
BUILD_ID ?= $(shell git describe --tags)

# Editions should be 5 chars or less because the full name is used as
# the volume id, and cannot exceed 32 characters.
# len("alpine-lima-12345-3.13.5-x86_64") == 31
EDITION ?= std

NERDCTL_VERSION=0.11.1

.PHONY: mkimage
mkimage:
	cd src/aports && git fetch && git checkout $(GIT_TAG)
	docker build \
		--tag mkimage:$(ALPINE_VERSION) \
		--build-arg ALPINE_VERSION=$(ALPINE_VERSION) \
		.

.PHONY: iso
iso: nerdctl-$(NERDCTL_VERSION)
	ALPINE_VERSION=$(ALPINE_VERSION) NERDCTL_VERSION=$(NERDCTL_VERSION) REPO_VERSION=$(REPO_VERSION) EDITION=$(EDITION) BUILD_ID=$(BUILD_ID) ./build.sh

nerdctl-$(NERDCTL_VERSION):
	curl -o $@ -Ls https://github.com/containerd/nerdctl/releases/download/v$(NERDCTL_VERSION)/nerdctl-full-$(NERDCTL_VERSION)-linux-amd64.tar.gz

.PHONY: lima
lima:
	ALPINE_VERSION=$(ALPINE_VERSION) EDITION=$(EDITION) ./lima.sh

.PHONY: run
run:
	qemu-system-x86_64 \
		-boot order=d,splash-time=0,menu=on \
		-cdrom iso/alpine-lima-$(EDITION)-$(ALPINE_VERSION)-x86_64.iso \
		-cpu host \
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
