###############################################################################
##
##       filename: makefile
##    description:
##        created: 2025/08/12
##         author: ticktechman
##
###############################################################################
.PHONY: all build test install doc

all: linux

linux: main.swift
	swiftc main.swift -o $@ -framework Virtualization
	codesign --entitlements main.entitlements -s - $@

clean:
	rm -f linux
###############################################################################
