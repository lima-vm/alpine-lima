# alpine-lima: build Alpine based ISO images for lima

[Lima](https://github.com/lima-vm/lima) launches Linux Virtual Machines on macOS.

This repo contains the scripts and tools to build an ISO image for Lima to be used by [Rancher Desktop](https://github.com/rancher-sandbox/rancher-desktop).

The requirements include:

* Create the smallest image possible because it will be included in the download of the Rancher Desktop application.

* Don't bundle any software that will not be used by Rancher Desktop: beyond keeping the image small, it also avoids having to update the image when one of the packages that isn't even being used has a CVE issued against it.

* Include all the optional packages needed by Lima and Rancher Desktop, so no internet connection is required to start up Rancher Desktop.

## Editions

The scripts in this repo can build multiple "editions" of the ISO: "min", "ci", "std", "k3s".

### Minimum: min

The "min" edition is just the base image used for everything else. It does configure the network adapters but is otherwise identical to the Alpine "virt" flavour. It can be tested locally with `qemu` and a console window, but doesn't work with Lima because it doesn't include any `cloud-init` functionality.

### Cloud-Init: ci

The "ci" edition just adds `cloud-init` on top of "min". It is used for testing Lima support for Alpine, to make sure that all optional packages are installed and configured correctly by the boot scripts.

### Standard: std

The "std" edition uses a custom "lima-init" script instead of "cloud-init" to avoid pulling in all the additional dependencies. It includes all optional requirements from Lima.

Right now the "std" edition also installs `qemu-aarch64` and configures it via `binfmt_misc` to be able to run Apple Silicon binaries. This is not the whole `qemu-openrc` package, but just the minimal subset for this one architecture, plus the configuration script.

### Kubernetes: k3s

The "k3s" edition is the same as "ci" plus `k3s` pre-installed. This is still subject to change.

### Rancher Desktop: rd

The "rd" edition was meant to be tailored exactly to the requirements of Rancher Desktop. For the time being it would be identical to the "std" edition, so "rd" does not exist yet.

## Building and testing

Note that this repo includes the [Alpine aports](https://github.com/alpinelinux/aports.git) repository as a submodule. If you didn't specify the `--recursive` option when cloning this repo, then you need to initialize the submodule by running:

```
git submodule update --init
```

The examples show the default values for `ALPINE_VERSION=3.13.5 EDITION=std`. The options need to be specified only to select non-default setting.

### Build the builder

The ISO builder will be created inside a docker image. You can specify the Alpine version used to create it:

```
make mkimage ALPINE_VERSION=3.13.5
```

### Build the ISO

This docker image can then be used to create ISO images that will be stored under `./iso`:

```
make iso ALPINE_VERSION=3.13.5 EDITION=std
```

### Run the ISO with qemu

```
make run ALPINE_VERSION=3.13.5 EDITION=std
```

### Run the ISO with Lima

```
make lima ALPINE_VERSION=3.13.5 EDITION=std
```
