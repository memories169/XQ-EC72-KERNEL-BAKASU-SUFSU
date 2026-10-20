#!/usr/bin/env bash
#
# Build kernel cho Sony Xperia 1 VI (pdx245 / XQ-C72) tu LineageOS kernel source,
# tich hop BakaSU + SUSFS + NoMount + BBRv3 va dong goi bang AnyKernel3.
#
# Tat ca phien ban upstream deu duoc pin cung commit de build co the lap lai.
# Co the override bang bien moi truong, vi du:
#   KERNEL_COMMIT=... BAKASU_COMMIT=... ./scripts/build.sh
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ---------------------------------------------------------------------------
# Phien ban upstream (pin commit)
# ---------------------------------------------------------------------------
KERNEL_REPO="${KERNEL_REPO:-https://github.com/LineageOS/android_kernel_sony_sm8650.git}"
KERNEL_REF="${KERNEL_REF:-lineage-24.0}"
KERNEL_COMMIT="${KERNEL_COMMIT:-3cded11904540db5fb4dc91fdade46e90ad6bba8}"

BAKASU_REPO="${BAKASU_REPO:-https://github.com/Baka-SU/BakaSU.git}"
BAKASU_COMMIT="${BAKASU_COMMIT:-7c383cfeef3a2ac450f2f1273dae74bd50356d31}"

SUSFS_REPO="${SUSFS_REPO:-https://gitlab.com/simonpunk/susfs4ksu.git}"
SUSFS_REF="${SUSFS_REF:-gki-android14-6.1}"
SUSFS_COMMIT="${SUSFS_COMMIT:-b57ed1998b82c4e3a2a81cdbf11172a560979c40}"

NOMOUNT_REPO="${NOMOUNT_REPO:-https://github.com/maxsteeel/nomount.git}"
NOMOUNT_COMMIT="${NOMOUNT_COMMIT:-7046c7ad3ee0bf4ae66e80f6b93b1e30db0cb4e3}"

PATCHES_REPO="${PATCHES_REPO:-https://github.com/WildKernels/kernel_patches.git}"
PATCHES_COMMIT="${PATCHES_COMMIT:-fa76c90e2cb284e6ce22b0b008ad4dd19820dbb1}"

ANYKERNEL_REPO="${ANYKERNEL_REPO:-https://github.com/osm0sis/AnyKernel3.git}"
ANYKERNEL_COMMIT="${ANYKERNEL_COMMIT:-020dfeccf9d7e962a48400fc94d3e451df92eead}"

# AnyKernel3 upstream chi kem binary 32-bit ARM; SM8650 (pdx245) khong chay
# duoc ELF32, nen thay magiskboot/busybox bang ban arm64 tu Magisk APK.
MAGISK_VERSION="${MAGISK_VERSION:-30.7}"
MAGISK_APK_URL="${MAGISK_APK_URL:-https://github.com/topjohnwu/Magisk/releases/download/v${MAGISK_VERSION}/Magisk-v${MAGISK_VERSION}.apk}"
MAGISK_APK_SHA256="${MAGISK_APK_SHA256:-e0d32d2123532860f97123d927b1bb86c4e08e6fd8a48bfc6b5bee0afae9ebd5}"

# ---------------------------------------------------------------------------
# Cau hinh build
# ---------------------------------------------------------------------------
WORKDIR="${WORKDIR:-$REPO_DIR/work}"
TOOLCHAIN_DIR="$WORKDIR/toolchain"
KERNEL_DIR="$WORKDIR/kernel"
BAKASU_DIR="$WORKDIR/BakaSU"
SUSFS_DIR="$WORKDIR/susfs4ksu"
NOMOUNT_DIR="$WORKDIR/NoMount"
PATCHES_DIR="$WORKDIR/kernel_patches"
ANYKERNEL_DIR="$WORKDIR/AnyKernel3"
OUT_DIR="$WORKDIR/out"
DIST_DIR="$WORKDIR/dist"

CLANG_VERSION="r487747c"
KMI_GENERATION="${KMI_GENERATION:-11}"
BRANCH="${BRANCH:-android14-6.1}"
JOBS="${JOBS:-$(nproc)}"

SKIP_SYNC="${SKIP_SYNC:-0}"
SKIP_BUILD="${SKIP_BUILD:-0}"

export ARCH=arm64
export SUBARCH=arm64

log()  { printf '\n\033[1;32m==>\033[0m %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Git helpers
# ---------------------------------------------------------------------------
# Fetch dung mot commit (nhanh, khong keo ca lich su).
fetch_commit() {
    local url="$1" commit="$2" dest="$3"

    if [ -d "$dest/.git" ]; then
        git -C "$dest" remote set-url origin "$url"
    else
        mkdir -p "$dest"
        git -C "$dest" init -q
        git -C "$dest" remote add origin "$url"
    fi

    info "fetch $url @ ${commit:0:12}"
    if ! git -C "$dest" fetch -q --depth=1 origin "$commit"; then
        warn "Khong fetch duoc theo commit, thu fetch day du..."
        git -C "$dest" fetch -q --unshallow origin 2>/dev/null || git -C "$dest" fetch -q origin
    fi
    git -C "$dest" checkout -q --detach "$commit" 2>/dev/null || \
        git -C "$dest" checkout -q --detach FETCH_HEAD
}

# Clone day du (can .git + tags + history, vi du BakaSU tinh version bang rev-list).
clone_repo() {
    local url="$1" ref="$2" commit="$3" dest="$4"

    if [ -d "$dest/.git" ]; then
        git -C "$dest" remote set-url origin "$url"
        git -C "$dest" fetch -q --tags origin
    else
        info "clone $url"
        git clone -q "$url" "$dest"
    fi

    if [ -n "$commit" ]; then
        git -C "$dest" checkout -q --detach "$commit" 2>/dev/null || {
            git -C "$dest" fetch -q origin "$commit"
            git -C "$dest" checkout -q --detach FETCH_HEAD
        }
    else
        git -C "$dest" checkout -q "$ref"
    fi
}

sync_sources() {
    log "Dong bo source code (pin commit)"

    fetch_commit "$KERNEL_REPO" "$KERNEL_COMMIT" "$KERNEL_DIR"
    # Xoa moi thay doi con sot lai tu lan build truoc.
    git -C "$KERNEL_DIR" clean -qfdx
    git -C "$KERNEL_DIR" reset -q --hard HEAD

    clone_repo "$BAKASU_REPO" "" "$BAKASU_COMMIT" "$BAKASU_DIR"
    clone_repo "$SUSFS_REPO" "$SUSFS_REF" "$SUSFS_COMMIT" "$SUSFS_DIR"
    clone_repo "$NOMOUNT_REPO" "" "$NOMOUNT_COMMIT" "$NOMOUNT_DIR"
    clone_repo "$PATCHES_REPO" "" "$PATCHES_COMMIT" "$PATCHES_DIR"
    clone_repo "$ANYKERNEL_REPO" "" "$ANYKERNEL_COMMIT" "$ANYKERNEL_DIR"

    info "kernel : $(git -C "$KERNEL_DIR" log -1 --format='%h %s')"
    info "BakaSU : $(git -C "$BAKASU_DIR" log -1 --format='%h %s')"
    info "SUSFS  : $(git -C "$SUSFS_DIR" log -1 --format='%h %s')"
    info "NoMount: $(git -C "$NOMOUNT_DIR" log -1 --format='%h %s')"
}

# ---------------------------------------------------------------------------
# Toolchain (AOSP prebuilt clang)
# ---------------------------------------------------------------------------
download() {
    local url="$1" out="$2"
    info "download $(basename "$out")"
    curl -fL --retry 5 --retry-delay 5 --connect-timeout 30 -o "$out" "$url"
}

setup_toolchain() {
    log "Chuan bi toolchain clang-$CLANG_VERSION"

    local clang_dir="$TOOLCHAIN_DIR/prebuilts/clang/host/linux-x86/clang-$CLANG_VERSION"
    local build_tools="$TOOLCHAIN_DIR/prebuilts/build-tools"
    local kbt="$TOOLCHAIN_DIR/prebuilts/kernel-build-tools"
    local sysroot="$TOOLCHAIN_DIR/prebuilts/gcc/linux-x86/host/x86_64-linux-glibc2.17-4.8/sysroot"
    local marker="$TOOLCHAIN_DIR/.complete"

    if [ ! -f "$marker" ]; then
        mkdir -p "$clang_dir" "$build_tools" "$kbt" "$sysroot"

        local tmp="$TOOLCHAIN_DIR/tmp"
        mkdir -p "$tmp"

        download "https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/main-kernel-build-2023/clang-$CLANG_VERSION.tar.gz" "$tmp/clang.tar.gz"
        tar xzf "$tmp/clang.tar.gz" -C "$clang_dir"

        download "https://android.googlesource.com/platform/prebuilts/build-tools/+archive/refs/heads/main-kernel-build-2023.tar.gz" "$tmp/build-tools.tar.gz"
        tar xzf "$tmp/build-tools.tar.gz" -C "$build_tools"

        download "https://android.googlesource.com/kernel/prebuilts/build-tools/+archive/refs/heads/main-kernel-build-2023/linux-x86.tar.gz" "$tmp/kernel-build-tools.tar.gz"
        tar xzf "$tmp/kernel-build-tools.tar.gz" -C "$kbt"

        download "https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/host/x86_64-linux-glibc2.17-4.8/+archive/refs/heads/main-kernel-build-2023/sysroot.tar.gz" "$tmp/sysroot.tar.gz"
        tar xzf "$tmp/sysroot.tar.gz" -C "$sysroot"

        rm -rf "$tmp"
        touch "$marker"
    fi

    [ -x "$clang_dir/bin/clang" ] || die "Khong tim thay clang trong $clang_dir"
    [ -d "$build_tools/linux-x86/bin" ] || die "Khong tim thay build-tools trong $build_tools"

    export PATH="$clang_dir/bin:$build_tools/linux-x86/bin:$build_tools/path/linux-x86:$kbt/bin:$PATH"
    export LD_LIBRARY_PATH="$kbt/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

    info "$(clang --version | head -n1)"
}

# ---------------------------------------------------------------------------
# Tich hop BakaSU
# ---------------------------------------------------------------------------
apply_bakasu() {
    log "Tich hop BakaSU"

    ln -sfn ../../BakaSU/kernel "$KERNEL_DIR/drivers/kernelsu"

    grep -q 'kernelsu/' "$KERNEL_DIR/drivers/Makefile" ||
        printf '\nobj-$(CONFIG_KSU) += kernelsu/\n' >> "$KERNEL_DIR/drivers/Makefile"

    printf '\nsource "drivers/kernelsu/Kconfig"\n' >> "$KERNEL_DIR/drivers/Kconfig"

    # BakaSU hien tai chan build khi thay SUSFS "chua cap nhat" (kiem tra cung,
    # chi la canh bao voi SUSFS ban moi). Bo chan nay de build tiep.
    local compat="$BAKASU_DIR/kernel/tools/susfs_compat.mk"
    if grep -q 'susfs has NOT update with latest KernelSU source' "$compat"; then
        sed -i '/susfs has NOT update with latest KernelSU source/,$d' "$compat"
        info "da go bo chan tuong thich SUSFS trong susfs_compat.mk"
    fi
}

# ---------------------------------------------------------------------------
# Tich hop SUSFS
# ---------------------------------------------------------------------------
apply_susfs() {
    log "Tich hop SUSFS"

    local patch="$SUSFS_DIR/kernel_patches/50_add_susfs_in_gki-android14-6.1.patch"
    [ -f "$patch" ] || die "Khong tim thay patch SUSFS: $patch"

    cp "$SUSFS_DIR/kernel_patches/fs/susfs.c" "$KERNEL_DIR/fs/"
    cp "$SUSFS_DIR/kernel_patches/include/linux/susfs.h" "$KERNEL_DIR/include/linux/"
    cp "$SUSFS_DIR/kernel_patches/include/linux/susfs_def.h" "$KERNEL_DIR/include/linux/"

    # BakaSU da co feature/selinux_hide.c tu hook runtime cac ham selinux.
    # Patch SUSFS them wrapper goi my_write_context/my_setprocattr (static trong
    # BakaSU) nen se gay loi link. Bo 2 file nay, giu phan con lai cua SUSFS.
    git -C "$KERNEL_DIR" apply --whitespace=nowarn \
        --exclude='security/selinux/hooks.c' \
        --exclude='security/selinux/selinuxfs.c' \
        "$patch"
    info "da ap dung $(basename "$patch") (bo qua hook selinux cua SUSFS)"
}

# ---------------------------------------------------------------------------
# Tich hop NoMount
# ---------------------------------------------------------------------------
apply_nomount() {
    log "Tich hop NoMount"

    ln -sfn ../../NoMount/kernel/src "$KERNEL_DIR/fs/nomount"

    grep -q 'CONFIG_NOMOUNT' "$KERNEL_DIR/fs/Makefile" ||
        printf '\nobj-$(CONFIG_NOMOUNT) += nomount/\n' >> "$KERNEL_DIR/fs/Makefile"

    printf '\nsource "fs/nomount/Kconfig"\n' >> "$KERNEL_DIR/fs/Kconfig"
}

# ---------------------------------------------------------------------------
# Enhanced networking (BBRv3 + sysctl)
# ---------------------------------------------------------------------------
apply_networking() {
    log "Ap dung BBRv3"

    local bbr="$PATCHES_DIR/common/bbrv3/0001-net-tcp-backport-BBRv3-to-android14-6.1.patch"
    [ -f "$bbr" ] || die "Khong tim thay patch BBRv3: $bbr"

    git -C "$KERNEL_DIR" apply --whitespace=nowarn "$bbr"
    info "da ap dung BBRv3"
}

# ---------------------------------------------------------------------------
# Host tools: libbpf 6.1 khong build duoc voi clang 17 do -Werror
# ---------------------------------------------------------------------------
fix_host_tools() {
    log "Va loi build host tools (libbpf + clang 17)"

    local makefile="$KERNEL_DIR/tools/lib/bpf/Makefile"
    if grep -q 'override CFLAGS += -Werror -Wall' "$makefile"; then
        sed -i 's/override CFLAGS += -Werror -Wall/override CFLAGS += -Wall/' "$makefile"
        info "da bo -Werror trong tools/lib/bpf/Makefile"
    fi
}

# ---------------------------------------------------------------------------
# Cau hinh kernel
# ---------------------------------------------------------------------------
configure_kernel() {
    log "Merge defconfig cho pdx245"

    # GKI release phai khop voi module stock trong vendor_dlkm/vendor_boot.
    # Ban build LineageOS pdx245 co release: 6.1.176-g3cded1190454
    # (khong co -android14-11, khong co -dirty). .scmversion duoc
    # scripts/setlocalversion doc truoc khi kiem tra git.
    printf '%s\n' "-g${KERNEL_COMMIT:0:12}" > "$KERNEL_DIR/.scmversion"

    rm -rf "$OUT_DIR"
    mkdir -p "$OUT_DIR"

    make -s -C "$KERNEL_DIR" O="$OUT_DIR" ARCH=arm64 LLVM=1 LLVM_IAS=1 gki_defconfig

    ( cd "$KERNEL_DIR" && ./scripts/kconfig/merge_config.sh -m -O "$OUT_DIR" \
        "$OUT_DIR/.config" \
        "$KERNEL_DIR/arch/arm64/configs/vendor/pineapple_GKI.config" \
        "$KERNEL_DIR/arch/arm64/configs/vendor/sony/pineapple_GKI.config" \
        "$KERNEL_DIR/arch/arm64/configs/vendor/sony/pdx245.config" \
        "$REPO_DIR/configs/xq-c72.config" >/dev/null )

    make -s -C "$KERNEL_DIR" O="$OUT_DIR" ARCH=arm64 LLVM=1 LLVM_IAS=1 olddefconfig

    # Kiem tra cac option quan trong co thuc su duoc bat hay khong.
    local cfg="$OUT_DIR/.config" missing=0
    local required=(
        CONFIG_MACH_SONY_PDX245
        CONFIG_KSU
        CONFIG_KSU_SUSFS
        CONFIG_NOMOUNT
        CONFIG_TCP_CONG_BBR3
        CONFIG_DEFAULT_BBR3
        CONFIG_MODVERSIONS
    )

    for opt in "${required[@]}"; do
        if ! grep -q "^$opt=y$" "$cfg"; then
            warn "thieu $opt=y trong .config"
            missing=1
        fi
    done
    [ "$missing" -eq 0 ] || die "Cau hinh kernel khong day du, xem $cfg"

    info "kernel release: $(cat "$OUT_DIR/include/config/kernel.release" 2>/dev/null || echo '(chua tao)')"
}

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
build_kernel() {
    log "Build kernel (jobs=$JOBS)"

    make -C "$KERNEL_DIR" O="$OUT_DIR" ARCH=arm64 LLVM=1 LLVM_IAS=1 \
        BRANCH="$BRANCH" KMI_GENERATION="$KMI_GENERATION" \
        KCFLAGS="-DKSU_NO_PREINIT" \
        HOSTCFLAGS="-DUSE_PKCS11_ENGINE" \
        KBUILD_BUILD_USER="xq-c72" \
        KBUILD_BUILD_HOST="github-actions" \
        KCONFIG_NOSILENTUPDATE=1 \
        -j"$JOBS" Image

    [ -f "$OUT_DIR/arch/arm64/boot/Image" ] || die "Khong tim thay Image sau khi build"
    info "Image: $(du -h "$OUT_DIR/arch/arm64/boot/Image" | cut -f1)"
}

# ---------------------------------------------------------------------------
# Thay binary arm64 cho AnyKernel3
# ---------------------------------------------------------------------------
install_arm64_tools() {
    local apk cache tmp
    cache="$WORKDIR/cache"
    apk="$cache/Magisk-v${MAGISK_VERSION}.apk"
    mkdir -p "$cache"

    if [ ! -f "$apk" ]; then
        log "Tai Magisk v${MAGISK_VERSION} (lay magiskboot/busybox arm64)"
        curl -fL --retry 3 --retry-delay 2 -o "$apk.tmp" "$MAGISK_APK_URL"
        echo "${MAGISK_APK_SHA256}  $apk.tmp" | sha256sum -c - >/dev/null \
            || die "Checksum Magisk APK khong khop"
        mv -f "$apk.tmp" "$apk"
    fi

    echo "${MAGISK_APK_SHA256}  $apk" | sha256sum -c - >/dev/null \
        || die "Checksum Magisk APK khong khop: $apk"

    tmp="$(mktemp -d)"
    unzip -q -o "$apk" \
        'lib/arm64-v8a/libmagiskboot.so' \
        'lib/arm64-v8a/libbusybox.so' -d "$tmp" \
        || die "Khong giai nen duoc Magisk APK"

    install -m 0755 "$tmp/lib/arm64-v8a/libmagiskboot.so" "$ANYKERNEL_DIR/tools/magiskboot"
    install -m 0755 "$tmp/lib/arm64-v8a/libbusybox.so" "$ANYKERNEL_DIR/tools/busybox"
    rm -rf "$tmp"

    file "$ANYKERNEL_DIR/tools/magiskboot" | grep -q 'ARM aarch64' \
        || die "magiskboot khong phai binary arm64"
    info "magiskboot/busybox: arm64 (Magisk v${MAGISK_VERSION})"
}

# ---------------------------------------------------------------------------
# Dong goi AnyKernel3
# ---------------------------------------------------------------------------
package_kernel() {
    log "Dong goi AnyKernel3"

    local release image zip
    release="$(cat "$OUT_DIR/include/config/kernel.release")"
    image="$OUT_DIR/arch/arm64/boot/Image"

    mkdir -p "$DIST_DIR"

    cp "$image" "$ANYKERNEL_DIR/Image"
    cp "$REPO_DIR/scripts/anykernel.sh" "$ANYKERNEL_DIR/anykernel.sh"
    sed -i "s|@KERNEL_STRING@|XQ-C72 ${release} - BakaSU + SUSFS + NoMount|g" \
        "$ANYKERNEL_DIR/anykernel.sh"

    install_arm64_tools

    zip="$DIST_DIR/XQ-C72_${release}_BakaSU-SUSFS-NoMount.zip"
    rm -f "$zip"
    ( cd "$ANYKERNEL_DIR" && zip -q -r9 "$zip" . -x '.git/*' -x 'README.md' -x '*.zip' )

    cp "$image" "$DIST_DIR/Image"
    printf '%s\n' "$release" > "$DIST_DIR/kernel.release"

    info "zip: $zip"
    ls -lh "$DIST_DIR"
}

# ---------------------------------------------------------------------------
main() {
    log "XQ-C72 kernel build"
    info "workspace: $WORKDIR"

    mkdir -p "$WORKDIR"

    if [ "$SKIP_SYNC" != "1" ]; then
        sync_sources
    else
        warn "SKIP_SYNC=1 - dung source code co san"
    fi

    setup_toolchain

    apply_bakasu
    apply_susfs
    apply_nomount
    apply_networking
    fix_host_tools

    configure_kernel

    if [ "$SKIP_BUILD" = "1" ]; then
        log "SKIP_BUILD=1 - dung sau buoc cau hinh"
        return
    fi

    build_kernel
    package_kernel

    log "Hoan tat"
}

main "$@"
