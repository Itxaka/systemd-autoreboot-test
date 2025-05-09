TARGET = x86_64-unknown-uefi
BUILD_DIR = target/$(TARGET)/release
OUT_EFI = esp/EFI/BOOT/boot_entry.efi

.PHONY: all clean

all:
	cargo build --target $(TARGET) --release
	mkdir -p $(dir $(OUT_EFI))
	cp $(BUILD_DIR)/efi_reboot.efi $(OUT_EFI)

clean:
	cargo clean
	rm esp/EFI/BOOT/boot_entry.efi


ESP_DIR = esp
IMG = disk.img
IMG_SIZE = 64M

.PHONY: esp-img clean all

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