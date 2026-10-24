#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p .build
swiftc Sources/CozyCafeCore/Cafe.swift Scripts/VerifyCore.swift -o .build/verify-core
.build/verify-core
swiftc -frontend -parse CozyCafe/CozyCafeApp.swift
plutil -lint CozyCafe.xcodeproj/project.pbxproj
