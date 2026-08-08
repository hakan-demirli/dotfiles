GIT := $(shell which git_cached || echo git)

.PHONY: install
install:
	@if [ ! -d "qmk_firmware" ]; then \
		$(GIT) clone https://github.com/qmk/qmk_firmware; \
		cd qmk_firmware/ && git reset --hard 2693d6f; \
		qmk setup -H $(shell pwd)/qmk_firmware; \
	else \
		echo "qmk_firmware directory already exists"; \
	fi

.PHONY: flash_clean
flash_clean:
	rm -rf ./qmk_firmware/keyboards/tbkmini7x3
	cp -r ./tbkmini7x3 ./qmk_firmware/keyboards
	qmk flash -kb tbkmini7x3 -km default

.PHONY: flash
flash:
	@if [ ! -d "./qmk_firmware/keyboards/tbkmini7x3" ]; then \
		cp -r ./tbkmini7x3 ./qmk_firmware/keyboards; \
	fi
	qmk flash -kb tbkmini7x3 -km default
