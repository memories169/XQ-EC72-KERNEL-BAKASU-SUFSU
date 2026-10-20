# Kernel Sony Xperia 1 VI (pdx245 / XQ-C72)

Kernel custom cho **Sony Xperia 1 VI** (mã máy `pdx245`, model `XQ-C72` / `XQ-EC54` / `XQ-EC72`), build từ source LineageOS `android_kernel_sony_sm8650` (Linux 6.1 GKI) với:

- **BakaSU** – KernelSU fork, hỗ trợ nhiều manager.
- **SUSFS** – ẩn root, mount, path, map… khỏi các app detect.
- **NoMount** – chuyển hướng/inject file mà không cần mount.
- **BBRv3 + enhanced networking** – congestion control mới, fq/cake, TTL/HL, IPv6 NAT, CIFS…
- **AnyKernel3** – flash trực tiếp qua recovery hoặc app quản lý KernelSU.

> ⚠️ **Cảnh báo**: unlock bootloader, flash kernel và dùng root đều có rủi ro mất dữ liệu, mất bảo hành, hoặc brick máy. Bạn tự chịu trách nhiệm. Hãy backup `boot`/`init_boot` gốc trước khi flash.

---

## 1. Tính năng

| Thành phần | Chi tiết |
|---|---|
| Kernel | Linux 6.1.x, GKI `android14-6.1`, KMI generation `11` |
| Root | BakaSU (KernelSU), hook bằng SUSFS inline hook |
| Ẩn root | SUSFS v2.x: sus_path, sus_mount, sus_kstat, spoof_uname, spoof_cmdline, open_redirect, sus_map, hide symbols |
| NoMount | `CONFIG_NOMOUNT=y` |
| TCP | BBRv3 mặc định, kèm BBRv1 |
| QoS | fq, fq_codel, fq_pie, cake, pie, htb |
| Firewall | connmark, TTL/HL target, IPv6 NAT, MASQUERADE, REDIRECT |
| Khác | WireGuard, CIFS/SMB (built-in), DNS resolver |
| Đóng gói | AnyKernel3, `BLOCK=boot`, hỗ trợ A/B slot |

---

## 2. Build bằng GitHub Actions

1. Fork hoặc tạo repo mới từ source này.
2. Vào **Settings → Actions → General**, chọn *Allow all actions and reusable workflows*.
3. Vào tab **Actions → Build XQ-C72 Kernel → Run workflow**.
4. Có thể để trống các ô commit để dùng phiên bản pin sẵn, hoặc nhập commit khác để thử nghiệm.
5. Sau khi build xong (~1–2 giờ), tải file zip trong **Artifacts**.

Build cũng tự chạy khi push tag dạng `v1.0.0`, và tự tạo GitHub Release kèm file zip.

### Tùy chọn đầu vào

| Input | Mặc định | Ý nghĩa |
|---|---|---|
| `kernel_commit` | commit trong `scripts/build.sh` | Commit của LineageOS kernel |
| `bakasu_commit` | commit trong `scripts/build.sh` | Commit BakaSU |
| `susfs_commit` | commit trong `scripts/build.sh` | Commit SUSFS |

---

## 3. Build trên máy local

### Yêu cầu

- Linux x86_64 (Ubuntu/Debian/Arch…), **≥ 8 GB RAM** (khuyến nghị 16 GB), ≥ 30 GB dung lượng trống.
- Các gói: `bc bison flex libssl-dev libelf-dev dwarves cpio rsync zip unzip zstd lz4 python3 git curl`.
- Mạng để tải kernel source (~200 MB) và toolchain AOSP (~3 GB).

### Chạy

```bash
git clone <repo-cua-ban> XQ-C72-Kernel
cd XQ-C72-Kernel
chmod +x scripts/build.sh
./scripts/build.sh
```

Kết quả:

```
work/dist/XQ-C72_<kernel-release>_BakaSU-SUSFS-NoMount.zip
work/dist/Image
work/dist/kernel.release
```

### Biến môi trường hữu ích

| Biến | Mặc định | Mô tả |
|---|---|---|
| `WORKDIR` | `$REPO/work` | Thư mục làm việc (source, toolchain, out) |
| `JOBS` | `nproc` | Số job build song song |
| `SKIP_SYNC=1` | `0` | Không clone/fetch lại source (dùng cho debug) |
| `SKIP_BUILD=1` | `0` | Dừng sau bước merge config để kiểm tra |
| `KERNEL_COMMIT` | pin sẵn | Override commit kernel |
| `BAKASU_COMMIT` | pin sẵn | Override commit BakaSU |
| `SUSFS_COMMIT` | pin sẵn | Override commit SUSFS |
| `NOMOUNT_COMMIT` | pin sẵn | Override commit NoMount |

Ví dụ build lại nhanh khi source đã có:

```bash
SKIP_SYNC=1 JOBS=12 ./scripts/build.sh
```

> `SKIP_SYNC=1` sẽ **không** reset cây kernel. Nếu lần trước build lỗi giữa chừng, hãy chạy lại không có `SKIP_SYNC` để reset sạch.

---

## 4. Flash

File zip AnyKernel3 có thể flash bằng:

- **Recovery** (TWRP/OrangeFox/Lineage Recovery) → Install → chọn file zip.
- **App quản lý KernelSU/BakaSU** → tab Modules/Flash → chọn file zip (cần root tạm thời hoặc manager đang hoạt động).

Sau khi flash, reboot. Cài **BakaSU Manager** (APK trong repo BakaSU) để quản lý root.

> **Lưu ý cho pdx245 (GKI)**: partition `boot` chỉ chứa kernel + dtb, **không có ramdisk** (ramdisk nằm ở `init_boot`). Vì vậy `scripts/anykernel.sh` dùng `split_boot` + `flash_boot` và đặt `NO_MAGISK_CHECK=1`, không dùng `dump_boot`/`write_boot`. Nếu dùng script AnyKernel3 mặc định sẽ báo `No ramdisk found to unpack. Aborting`.

### Nếu máy không boot

1. Vào fastboot: giữ `Power + Volume Down`.
2. Flash lại `boot` gốc:
   ```bash
   fastboot flash boot boot_goc.img
   ```
3. Hoặc dùng `fastboot boot boot_goc.img` để boot tạm.

---

## 5. Cấu hình

Toàn bộ option bổ sung nằm trong [`configs/xq-c72.config`](configs/xq-c72.config). Quy trình merge:

```
gki_defconfig
  + arch/arm64/configs/vendor/pineapple_GKI.config
  + arch/arm64/configs/vendor/sony/pineapple_GKI.config
  + arch/arm64/configs/vendor/sony/pdx245.config
  + configs/xq-c72.config
  → olddefconfig
```

Muốn thêm/bớt tính năng, sửa file config rồi build lại. Một số option phụ thuộc lẫn nhau; nếu build báo thiếu symbol, xem `work/out/.config` và bật các `depends on` tương ứng.

### Kiểm tra cấu hình sau build

```bash
grep -E 'CONFIG_(KSU|NOMOUNT|TCP_CONG_BBR3|MACH_SONY_PDX245)=' work/out/.config
cat work/dist/kernel.release
```

---

## 6. Phiên bản upstream (pin commit)

| Thành phần | Repo | Commit |
|---|---|---|
| Kernel | `LineageOS/android_kernel_sony_sm8650` | `3cded11904540db5fb4dc91fdade46e90ad6bba8` |
| BakaSU | `Baka-SU/BakaSU` | `7c383cfeef3a2ac450f2f1273dae74bd50356d31` |
| SUSFS | `simonpunk/susfs4ksu` (`gki-android14-6.1`) | `b57ed1998b82c4e3a2a81cdbf11172a560979c40` |
| NoMount | `maxsteeel/nomount` | `7046c7ad3ee0bf4ae66e80f6b93b1e30db0cb4e3` |
| BBRv3 patch | `WildKernels/kernel_patches` | `fa76c90e2cb284e6ce22b0b008ad4dd19820dbb1` |
| AnyKernel3 | `osm0sis/AnyKernel3` | `020dfeccf9d7e962a48400fc94d3e451df92eead` |
| Toolchain | AOSP prebuilt clang `r487747c` | nhánh `main-kernel-build-2023` |

Cập nhật phiên bản: sửa biến tương ứng ở đầu `scripts/build.sh`, sau đó build lại. Nếu SUSFS hoặc KernelSU thay đổi API hook, có thể phải chỉnh patch/`susfs_compat.mk`.

---

## 7. Cấu trúc repo

```
.
├── .github/workflows/build.yml   # CI GitHub Actions
├── configs/xq-c72.config         # config fragment cho pdx245
├── scripts/
│   ├── build.sh                  # toàn bộ pipeline build + package
│   └── anykernel.sh              # template AnyKernel3
├── LICENSE
└── README.md
```

`scripts/build.sh` thực hiện:

1. Fetch kernel + BakaSU + SUSFS + NoMount + patch + AnyKernel3 đúng commit.
2. Tải toolchain clang AOSP (cache lại cho lần sau).
3. Tích hợp BakaSU (symlink `drivers/kernelsu`, Kconfig/Makefile).
4. Copy + apply patch SUSFS, gỡ chặn tương thích trong `susfs_compat.mk`.
5. Tích hợp NoMount (`fs/nomount`).
6. Apply patch BBRv3.
7. Merge defconfig và kiểm tra các option bắt buộc.
8. `make Image` với `BRANCH=android14-6.1`, `KMI_GENERATION=11`, `KCFLAGS=-DKSU_NO_PREINIT`.
9. Đóng gói AnyKernel3.

---

## 8. Ghi chú kỹ thuật

- **KMI**: kernel giữ `KMI_GENERATION=11` và `BRANCH=android14-6.1` để vendor modules của ROM load được. Module vendor dùng CRC (`CONFIG_MODVERSIONS`) nên không cần trùng chính xác chuỗi `kernel.release`.
- **BakaSU + SUSFS**: BakaSU hiện chưa có `ksu_preinit_*`, nên build thêm `-DKSU_NO_PREINIT` để patch SUSFS bỏ phần preinit.
- **SUSFS inline hook**: chọn `CONFIG_KSU_SUSFS=y`, không bật tracepoint/manual hook.
- **SELinux hiding**: BakaSU có `feature/selinux_hide.c` hook runtime, nên patch SUSFS được áp dụng loại trừ `security/selinux/hooks.c` và `security/selinux/selinuxfs.c` để tránh xung đột/lỗi link.
- **NoMount**: source được symlink vào `fs/nomount`, build cùng kernel (không phải module rời).
- **CIFS/WireGuard** được build-in để không phải flash thêm module.
- **AVB/verity**: AnyKernel3 tự patch vbmeta flag (`PATCH_VBMETA_FLAG=auto`).

---

## 9. Troubleshooting

| Lỗi | Cách xử lý |
|---|---|
| `susfs has NOT update with latest KernelSU source` | Script đã tự gỡ; nếu vẫn gặp, kiểm tra `BakaSU/kernel/tools/susfs_compat.mk` |
| `ksu_preinit_* undeclared` | Đảm bảo `KCFLAGS=-DKSU_NO_PREINIT` được truyền (script đã làm) |
| Hết dung lượng `/tmp` | Đặt `WORKDIR` sang ổ lớn hơn; script dùng `WORKDIR`, không dùng `/tmp` cho source |
| Hết RAM/OOM | Giảm `JOBS`, tăng swap |
| `pahole not found` | Cài `dwarves` (CI đã cài) |
| Vendor module không load | Kiểm tra `kernel.release` có `android14-11`; không đổi `KMI_GENERATION` |
| Máy bootloop | Flash lại boot gốc, xem log `dmesg`/`last_kmsg` nếu còn truy cập được |
| `No ramdisk found to unpack` khi flash | Dùng bản zip mới (AnyKernel3 dùng `split_boot`/`flash_boot`); pdx245 có ramdisk ở `init_boot`, không phải `boot` |

---

## 10. Credits

- [LineageOS](https://github.com/LineageOS) – kernel source cho Sony SM8650.
- [BakaSU](https://github.com/Baka-SU/BakaSU) – KernelSU fork.
- [simonpunk/susfs4ksu](https://gitlab.com/simonpunk/susfs4ksu) – SUSFS.
- [maxsteeel/nomount](https://github.com/maxsteeel/nomount) – NoMount.
- [WildKernels](https://github.com/WildKernels) – BBRv3 patch và tham khảo CI.
- [osm0sis/AnyKernel3](https://github.com/osm0sis/AnyKernel3) – template flash.
- Cộng đồng Xperia 1 VI / SM8650.

---

## License

Kernel và các patch tuân theo GPL-2.0. Xem [LICENSE](LICENSE).
