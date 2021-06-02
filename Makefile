.PHONY: image
image:
	docker build -t mkimg:latest .

.PHONY: iso
iso:
	./build.sh

.PHONY: run
run:
	qemu-system-x86_64 -boot d -cdrom iso/alpine-lima-dev-x86_64.iso -cpu Haswell-v4 -machine q35,accel=hvf -smp 4,sockets=1,cores=4,threads=1 -m 4096 -net nic,model=virtio -net user,net=192.168.5.0/24
