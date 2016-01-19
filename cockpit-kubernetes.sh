#! /usr/bin/env bash

# Install the pre-requisities
# dnf fails if some of the packages do not exist, we need to use --setopt=strict=0 to work around that
DNF=$(which dnf 2>/dev/null && echo "--setopt=strict=0" || which yum)
DNF_BD=$(which dnf 2>/dev/null && echo "builddep" || which yum-builddep)

$DNF install -y libvirt libvirt-client qemu-system-x86 git koji libvirt-python \
     brew qemu-kvm libvirt-daemon-kvm python-libguestfs mock rpm-build curl \
     python-lxml krb5-workstation krb5-server selinux-policy-devel nodejs npm

npm install -g phantomjs

# Setup the environment
#
test -z "$TEST_OS" && \
	TEST_OS="fedora-23" # choose one of fedora-{22,23,testing,atomic} {centos,rhel}-7
test -z "$TEST_BUILD" && \
	TEST_BUILD="fedora-24" # choose one of fedora-{22,23,testing,atomic} {centos,rhel}-7
OS_NAME="$(echo $TEST_BUILD | cut -d '-' -f 1)"
OS_RELEASE="$(echo $TEST_BUILD | cut -d '-' -f 2)"
# get system-specific values
case "$OS_NAME" in
fedora)
	KOJI="koji"
	OS_TAG=f"$OS_RELEASE"
	;;
centos)
	KOJI="koji"
	# We care only about centos 7+
	OS_TAG=epel"$OS_RELEASE"
	;;
rhel)
	KOJI="brew"
	# Get the latest tag from brew  (rhel 6+)
	OS_TAG="$(brew list-tags | grep -iE ^$OS_NAME-$OS_RELEASE.\[0-9\]\*\$ | sort | tail -1)"
	;;
*)
	echo "Unknown OS"
	exit 1
	;;
esac
test -z "$TEST_DATA" && \
	TEST_DATA="/kubernetes_imgdir" # choose directory to store test machine images
test -z "$KOJI" && \
	KOJI="$(test $(echo $TEST_OS | cut -d '-' -f 1) == rhel && echo brew || echo koji )"
test -z $COCKPIT_GIT && \
	COCKPIT_GIT="https://github.com/cockpit-project/cockpit.git"
test -z $COCKPIT_DIR && \
	COCKPIT_DIR="/cockpit"
test -z "$ARCH" && \
	ARCH="$(uname -m)"
test -z "$BUILD" && \
	BUILD="$($KOJI latest-build --quiet $OS_TAG kubernetes | awk '{print $1}')"
test -z "$PKG_DIR" && \
	PKG_DIR="/kubernetes_pkgdir"

# These are used by vm-* scripts
export "TEST_OS" "TEST_DATA"

# Print out the environment
echo "TEST_OS=$TEST_OS"
echo "TEST_DATA=$TEST_DATA"
echo "TEST_BUILD=$TEST_BUILD"
echo "KOJI=$KOJI"
echo "COCKPIT_GIT=$COCKPIT_GIT"
echo "ARCH=$ARCH"
echo "BUILD=$BUILD"
echo "$PKG_DIR"

#exit 1

# Tell qemu to run as root
egrep -v user\|group /etc/libvirt/qemu.conf > /etc/libvirt/qemu.conf.mod
echo -e 'user = "root"\ngroup = "root"' >> /etc/libvirt/qemu.conf.mod
mv -f /etc/libvirt/qemu.conf.mod /etc/libvirt/qemu.conf

# Enable libvirt
systemctl enable libvirtd
systemctl restart libvirtd
systemctl stop firewalld

rm -rf "$COCKPIT_DIR"

# Get teh sources
git clone "$COCKPIT_GIT" "$COCKPIT_DIR"

pushd "$COCKPIT_DIR"

# Build and install latest cockpit
$DNF_BD ./tools/cockpit.spec

./autogen.sh --enable-maintainer-mode --enable-debug
make -j4
make install

# Perform tests
pushd ./test

# Prepare VMs
./vm-prep

# Get the packages
rm -rf "$PKG_DIR"
mkdir -p "$PKG_DIR"
pushd "$PKG_DIR"
koji download-build --arch="$ARCH" --arch=noarch $BUILD
popd

# Allow access to all
mkdir -p "$PKG_DIR" "$TEST_DATA"
chcon -R -u system_u -r object_r -t virt_image_t "$TEST_DATA"

ln -sf "$TEST_DATA"/images/* "./images/"

chcon -R -u system_u -r object_r -t virt_image_t "./images/"

# Prepare test suite
./testsuite-prepare

./vm-install "$PKG_DIR"/*.rpm

./check-kubernetes -tvs
EX=$?

popd

popd

exit $EX
