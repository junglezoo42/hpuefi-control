#!/usr/bin/env bash

set -euo pipefail

export DEBFULLNAME="junglezoo42"
export DEBEMAIL="junglezoo42@mail.de"

UPSTREAM_URL="https://ftp.hp.com/pub/softpaq/sp150501-151000/sp150953.tgz"
UPSTREAM_FILE="$(basename $UPSTREAM_URL)"

GIT_URL_HP_FLASH="https://tw-mloschwitz:$GH_TOKEN@github.com/junglezoo42/debian-for-hp-flash.git"
GIT_URL_HPUEFI_KMOD="https://tw-mloschwitz:$GH_TOKEN@github.com/junglezoo42/debian-for-hpuefi-mod.git"

cleanup () {
	# delete cruft
	rm -rf src
}

download_upstream () {
	# ensure wget and git installed
	sudo apt -y install wget git
	# download upstream tarball
	wget -O $UPSTREAM_FILE $UPSTREAM_URL
}

unpack_orig () {
	# Unpack original tarball to "src" directory
	mkdir -p src
	tar xvfz $UPSTREAM_FILE -C src
}

move_files () {
	# determine name and version of upstream tarballs
	hp_flash_basename=$(basename src/non-rpms/hp-flash-*)
	hp_uefi_mod_basename=$(basename src/non-rpms/hpuefi-mod-*)
	hp_flash_version=$(echo ${hp_flash_basename} | cut -f3 -d'-' | sed 's/_x86_64//g' | sed 's/.tgz//g')
	hp_uefi_mod_version=$(echo ${hp_uefi_mod_basename} | cut -f3 -d'-' | sed 's/.tgz//g')

	mkdir -p src/build

	mv src/non-rpms/${hp_flash_basename} src/build/hp-flash_${hp_flash_version}.orig.tar.gz
	mv src/non-rpms/${hp_uefi_mod_basename} src/build/hpuefi-mod_${hp_uefi_mod_version}.orig.tar.gz
}

unpack () {
	# Unpack all required files
	mkdir -p src/build/hp-flash-${hp_flash_version}
	mkdir -p src/build/hpuefi-mod-${hp_uefi_mod_version}
	tar xvfz src/build/hp-flash_${hp_flash_version}.orig.tar.gz -C src/build/hp-flash-${hp_flash_version} --strip-components=2
	tar xvfz src/build/hpuefi-mod_${hp_uefi_mod_version}.orig.tar.gz -C src/build/hpuefi-mod-${hp_uefi_mod_version} --strip-components=2
	git clone $GIT_URL_HP_FLASH src/build/hp-flash-${hp_flash_version}/debian
	git clone $GIT_URL_HPUEFI_KMOD src/build/hpuefi-mod-${hp_uefi_mod_version}/debian
}

prepare_system () {
	sudo apt -y install build-essential devscripts debhelper-compat dh-exec dh-sequence-dkms
}

create_changelog () {
	(cd src/build/hp-flash-${hp_flash_version} && dch -D jammy -l unofficial "New upstream release")
	(cd src/build/hpuefi-mod-${hp_uefi_mod_version} && dch -D jammy -l unofficial "New upstream release")
}

build_packages () {
	(cd src/build/hp-flash-${hp_flash_version} && dpkg-buildpackage -rfakeroot -uc -us -S -sa)
	(cd src/build/hpuefi-mod-${hp_uefi_mod_version} && dpkg-buildpackage -rfakeroot -uc -us -S -sa)
}

move_packages () {
	mkdir -p sources
	mv src/build/*.{xz,buildinfo,dsc,changes,gz} sources/ 
}

sign_packages () {
	(cd sources && debsign *.changes)
}

upload_packages () {
	(cd sources && dput ppa:junglezoo42/hpuefi *.changes)
}

update_git () {
	(cd src/build/hp-flash-${hp_flash_version}/debian && git commit -a -m "Update changelog" && git push origin)
	(cd src/build/hpuefi-mod-${hp_uefi_mod_version}/debian && git commit -a -m "Update changelog" && git push origin)
}

cleanup
download_upstream
unpack_orig
move_files
unpack
prepare_system
create_changelog
build_packages
move_packages
sign_packages
upload_packages
update_git
