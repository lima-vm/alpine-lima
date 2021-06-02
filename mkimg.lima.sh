profile_lima() {
	profile_standard
	profile_abbrev="lima"
	title="Linux on Mac"
	desc="Similar to standard.
		Slimmed down kernel.
		Optimized for virtual systems.
		Configured for lima."
	arch="aarch64 x86 x86_64"
	kernel_addons=
	kernel_flavors="virt"
	kernel_cmdline="console=tty0 console=ttyS0,115200"
	syslinux_serial="0 115200"
}
