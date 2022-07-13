CROSS_COMPILE ?= arm-none-eabi-
CC = $(CROSS_COMPILE)gcc
OBJCOPY = $(CROSS_COMPILE)objcopy
GIT_VERSION := $(shell git describe --abbrev=8 --dirty --always --tags)

# Config bits
BOOTLOADER_SIZE = 4
FLASH_SIZE = 64
FLASH_BASE_ADDR = 0x08000000
FLASH_BOOTLDR_PAYLOAD_SIZE_KB = $(shell echo $$(($(FLASH_SIZE) - $(BOOTLOADER_SIZE))))

LD_SCRIPT ?= stm32f103.ld

# Default config
CONFIG ?= -DENABLE_DFU_UPLOAD -DENABLE_SAFEWRITE -DHSE_SPEED_16MHZ
# -DENABLE_PROTECTIONS -DENABLE_GPIO_DFU_BOOT -DENABLE_WATCHDOG=20 -DGPIO_DFU_BOOT_PORT=GPIOB -DGPIO_DFU_BOOT_PIN=2 -DENABLE_CHECKSUM

CFLAGS = -Os -ggdb -std=c11 -Wall -pedantic -Werror \
	-ffunction-sections -fdata-sections -Wno-overlength-strings \
	-mcpu=cortex-m3 -mthumb -DSTM32F1 -fno-builtin-memcpy  \
	-pedantic -DVERSION=\"$(GIT_VERSION)\" -flto $(CONFIG)

LDFLAGS = -ggdb -ffunction-sections -fdata-sections \
	-Wl,-T$(LD_SCRIPT) -nostartfiles -lc -lnosys \
	-mthumb -mcpu=cortex-m3 -Wl,-gc-sections -flto \
	-Wl,--print-memory-usage

BUILD_DIR = build/

all:	$(BUILD_DIR) bootloader-dfu-fw.bin

# DFU bootloader firmware
bootloader-dfu-fw.elf: $(BUILD_DIR)init.o $(BUILD_DIR)main.o $(BUILD_DIR)usb.o
	$(CC) $^ -o $(BUILD_DIR)$@ $(LDFLAGS) -Wl,-Ttext=$(FLASH_BASE_ADDR) -Wl,-Map,$(BUILD_DIR)bootloader-dfu-fw.map

%.bin: %.elf
	$(OBJCOPY) -O binary $(BUILD_DIR)$^ $(BUILD_DIR)$@

$(BUILD_DIR)%.o: %.c | flash_config.h
	$(CC) -c $< -o $@ $(CFLAGS)

$(BUILD_DIR):
	mkdir -p $@

flash_config.h:
	echo "#define FLASH_BASE_ADDR $(FLASH_BASE_ADDR)" > flash_config.h
	echo "#define FLASH_SIZE_KB $(FLASH_SIZE)" >> flash_config.h
	echo "#define FLASH_BOOTLDR_PAYLOAD_SIZE_KB $(FLASH_BOOTLDR_PAYLOAD_SIZE_KB)" >> flash_config.h
	echo "#define FLASH_BOOTLDR_SIZE_KB $(BOOTLOADER_SIZE)" >> flash_config.h

clean:
	-rm -rf $(BUILD_DIR) flash_config.h

