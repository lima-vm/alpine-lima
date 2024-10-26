ALPINE_VERSION ?= 3.20.3
REPO_VERSION ?= $(shell echo "$(ALPINE_VERSION)" | sed -E 's/^([0-9]+\.[0-9]+).*/v\1/')
GIT_TAG ?= $(shell echo "v$(ALPINE_VERSION)" | sed 's/^vedge$$/origin\/master/')
BUILD_ID ?= $(shell git describe --tags)
DOCKER ?= docker

# Editions should be 5 chars or less because the full name is used as
# the volume id, and cannot exceed 32 characters.
# len("alpine-lima-12345-3.13.5-x86_64") == 31
EDITION ?= std

# Architecture defaults to the current system's.
ARCH ?= $(shell uname -m)
ifeq ($(strip $(ARCH)),arm64)
ARCH = aarch64
endif

# ARCH is derived from `uname -m` but the alternate architecture name (e.g. amd64, arm64)
# is required for Docker and asset downloads.
ARCH_ALIAS_x86_64 = amd64
ARCH_ALIAS_aarch64 = arm64
ARCH_ALIAS = $(shell echo "$(ARCH_ALIAS_$(ARCH))")

QEMU_VERSION=v8.1.5
BINFMT_IMAGE=tonistiigi/binfmt:qemu-$(QEMU_VERSION)

.PHONY: mkimage
mkimage:
	cd src/aports && git fetch && git checkout $(GIT_TAG)
	$(DOCKER) build \
		--progress plain --no-cache \
		--tag mkimage:$(ALPINE_VERSION)-$(ARCH) \
		--build-arg ALPINE_VERSION=$(ALPINE_VERSION) \
		--build-arg BINFMT_IMAGE=$(BINFMT_IMAGE) \
		--platform linux/$(ARCH_ALIAS) \
		.

.PHONY: iso
iso: qemu-$(QEMU_VERSION)-copying
	ALPINE_VERSION=$(ALPINE_VERSION) QEMU_VERSION=$(QEMU_VERSION) REPO_VERSION=$(REPO_VERSION) EDITION=$(EDITION) BUILD_ID=$(BUILD_ID) ARCH=$(ARCH) ARCH_ALIAS=$(ARCH_ALIAS) ./build.sh


qemu-$(QEMU_VERSION)-copying:
	curl -o $@ -Ls https://raw.githubusercontent.com/qemu/qemu/$(QEMU_VERSION)/COPYING

.PHONY: lima
lima:
	ALPINE_VERSION=$(ALPINE_VERSION) EDITION=$(EDITION) ARCH=$(ARCH) ./lima.sh

.PHONY: run
run:
	accel=tcg; display=sdl; \
	case "$(shell uname)" in \
		Darwin) accel=hvf; display=cocoa;; \
		Linux) accel=kvm; display=gtk;; \
	esac; \
	qemu-system-$(ARCH) \
		-boot order=d,splash-time=0,menu=on \
		-cdrom iso/alpine-lima-$(EDITION)-$(ALPINE_VERSION)-$(ARCH).iso \
		-cpu host \
		-machine q35,accel=$$accel \
		-smp 4,sockets=1,cores=4,threads=1 \
		-m 4096 \
		-net nic,model=virtio \
		-net user,net=192.168.5.0/24,hostfwd=tcp:127.0.0.1:20022-:22 \
		-display $$display \
		-device virtio-rng-pci \
		-device virtio-vga \
		-device virtio-keyboard-pci \
		-device virtio-mouse-pci \
		-parallel none
