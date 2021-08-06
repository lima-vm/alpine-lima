# This script collects information from `ip -o link` about current interface
# names with data from "cidata/network-config" about the desired state.
#
# Arrays:
# - curname[addr] => current name for addr
# - use[itf]      => current address for interface (name is "in use" if recorded here)
# - newname[addr] => desired name for addr
#
# The script tries to minimize the number of renames. It processes as many as possible,
# and if newnames is not yet empty, it renames one of the addresses to a temporary
# name to break cyclic dependencies.
#
# The generated script is being run by lima-init when all links are still down, so
# no commands are produced to change the interface status (names can only be changed
# in DOWN status).

### Collect info from `ip -o link`.
# 3: eth1: <BROADCAST,MULTICAST> [...] state DOWN qlen 1000\    link/ether 22:aa:56:ca:ea:6e [...]
/link\/ether/ {
    iface = gensub(/^[0-9]+: ([^ ]+):.*/, "\\1", 1, $0)
    addr = gensub(/.*link\/ether ([^ ]+).*/, "\\1", 1, $0)
    curname[addr] = iface
    use[iface] = addr
}

### Collect info from network-config.
# macaddress: '22:e5:f4:59:9b:63'
/macaddress/ {
    gsub("'", "")
    addr = $2
}

# set-name: vde0
/set-name/ {
    if (addr in newname) {
        # This should not happen with lima
        printf "echo \"Address %s already assigned to '%s', ignoring '%s'\"\n", addr, newname[addr], $2
    }
    else {
        newname[addr] = $2
    }
}

### Rename interfaces to match network-config settings.
function rename(addr, target) {
    print "ip link set", curname[addr], "name", target
    delete use[curname[addr]]
    curname[addr] = target
    use[target] = addr
}

function availname() {
    itf = 0
    do {
        itfname = "itf" itf
        itf = itf + 1
    } while (itfname in use)
    return itfname
}

BEGIN {
    print "set -eux"
}

END {
    do {
        len = length(newname)
        for (addr in newname) {
            # Does the address exist?
            if (!(addr in curname)) {
                # This too should not happen with lima
                printf "echo \"Address %s not found, cannot assign to '%s'\"\n", addr, newname[addr]
                delete newname[addr]
                continue
            }
            # Does the current interface name already match the desired name?
            if (newname[addr] == curname[addr]) {
                # Nothing to do; already has the correct name.
                delete newname[addr]
                continue
            }
            # Is the desired interface name in use and not going to be renamed?
            if ((newname[addr] in use) && !(use[newname[addr]] in newname)) {
                # Assign the current address to a generic itf to make the name available
                rename(use[newname[addr]], availname())
            }
            # Is the desired interface name not being used right now?
            if (!(newname[addr] in use)) {
                rename(addr, newname[addr])
                delete newname[addr]
                continue
            }
        }
        # If not a single newname could be resolved, then the remaining names must be
        # locked in a cycle. Break it by renaming a random interface to a temporary name.
        if (len == length(newname)) {
            for (addr in newname) {
                rename(addr, availname())
                break
            }
        }
    } while (length(newname) > 0)
}
