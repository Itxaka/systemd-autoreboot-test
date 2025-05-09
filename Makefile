TARGET = x86_64-unknown-uefi
BUILD_DIR = target/$(TARGET)/release
ESP_DIR = esp
OUT_EFI = $(ESP_DIR)/EFI/Linux/efi_reboot.efi
ESP_BOOTX64 = $(ESP_DIR)/EFI/BOOT/bootx64.efi
SYSTEMD_BOOT = systemd/build/src/boot/systemd-bootx64.efi
IMG = disk.img
IMG_SIZE = 64M


.PHONY: all clean esp-img systemd-boot

all: build-efi systemd-boot esp-img

build-efi:
	cargo build --target $(TARGET) --release
	mkdir -p $(dir $(OUT_EFI))
	cp $(BUILD_DIR)/efi_reboot.efi $(OUT_EFI)

clean:
	cargo clean
	rm -Rf $(ESP_DIR)/EFI/
	rm -f $(IMG)


esp-img:
	@echo "Creating disk image with GPT and FAT32 ESP (no root required)..."
	rm -f $(IMG)
	truncate -s $(IMG_SIZE) $(IMG)

	# Create GPT with ESP partition
	sgdisk --clear \
	       --new=1:2048: \
	       --typecode=1:ef00 \
	       --change-name=1:ESP \
	       $(IMG)

	# Format the ESP partition using mtools (partition starts at 1MiB offset)
	mformat -i $(IMG)@@1M -h 255 -t 63 -s 32 -F ::

	# Copy EFI contents into image using mcopy
	mcopy -s -i $(IMG)@@1M $(ESP_DIR)/* ::/


systemd-boot: $(SYSTEMD_BOOT)
	mkdir -p $(ESP_DIR)/EFI/BOOT/
	cp $(SYSTEMD_BOOT) $(ESP_BOOTX64)

$(SYSTEMD_BOOT):
	cd systemd && \
	meson setup build -Dmode=developer -Defi=true -Dinstall-tests=false || true && \
	ninja -C build systemd-boot

run-qemu:
	qemu-system-x86_64 -enable-kvm -m 4G \
	-drive if=pflash,format=raw,readonly=on,file=${PWD}/OVMF_CODE.fd \
  	-drive if=pflash,format=raw,file=${PWD}/OVMF_VARS.fd \
	-drive format=raw,file=$(IMG) \