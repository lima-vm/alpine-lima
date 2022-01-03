profile_lima() {
	profile_standard
	profile_abbrev="lima"
	title="Linux Virtual Machines"
	desc="Similar to standard.
		Slimmed down kernel.
		Optimized for virtual systems.
		Configured for lima."
	arch="aarch64 x86 x86_64"
	initfs_cmdline="modules=loop,squashfs,sd-mod,usb-storage"
	kernel_addons=
	kernel_flavors="virt"
	kernel_cmdline="console=tty0 console=ttyS0,115200"
	syslinux_serial="0 115200"
	apkovl="genapkovl-lima.sh"
	apks="$apks openssh-server-pam"
        if [ "${LIMA_INSTALL_CA_CERTIFICATES}" == "true" ]; then
            apks="$apks ca-certificates"
        fi
        if [ "${LIMA_INSTALL_CLOUD_INIT}" == "true" ]; then
            apks="$apks cloud-init"
        fi
        if [ "${LIMA_INSTALL_DOCKER}" == "true" ]; then
            apks="$apks libseccomp runc containerd tini-static device-mapper-libs"
            apks="$apks docker-engine docker-openrc docker-cli docker"
            apks="$apks socat"
        fi
        if [ "${LIMA_INSTALL_CONTAINERD}" == "true" ]; then
            apks="$apks runc containerd cni-plugins"
	fi
        if [ "${LIMA_INSTALL_LIMA_INIT}" == "true" ]; then
            apks="$apks e2fsprogs lsblk sfdisk shadow sudo udev"
        fi
        if [ "${LIMA_INSTALL_K3S}" == "true" ]; then
            apks="$apks k3s"
        fi
        if [ "${LIMA_INSTALL_LOGROTATE}" == "true" ]; then
            apks="$apks logrotate"
        fi
        if [ "${LIMA_INSTALL_SSHFS}" == "true" ]; then
            apks="$apks sshfs"
        fi
        if [ "${LIMA_INSTALL_IPTABLES}" == "true" ] || [ "${LIMA_INSTALL_NERDCTL}" == "true" ]; then
            apks="$apks iptables ip6tables"
        fi
}
