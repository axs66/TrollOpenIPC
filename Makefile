# TrollOpenIPC Root Makefile
# 统一构建 ReceiverSB 和 SenderApp

export THEOS_PACKAGE_SCHEME ?= rootless

.PHONY: all clean package receiver sender

all: receiver sender

receiver:
	$(MAKE) -C ReceiverSB

sender:
	$(MAKE) -C SenderApp

clean:
	$(MAKE) -C ReceiverSB clean
	$(MAKE) -C SenderApp clean
	rm -rf packages

package:
	mkdir -p packages
	$(MAKE) -C ReceiverSB package FINALPACKAGE=1
	$(MAKE) -C SenderApp package FINALPACKAGE=1
	cp ReceiverSB/packages/*.deb packages/ 2>/dev/null || true
	cp SenderApp/packages/*.deb packages/ 2>/dev/null || true
	@echo "Packages created in ./packages/"
	@ls -la packages/
