# zcc

zcc is a simple C Compiler created by ziglang.This project is for my practice of ziglang. zcc compile C program and output assembler for x86-64 which is written by Intel-syntax.

zcc means ***z**iglang **C** **C**ompiler.*

# Build
build zcc.
```zig
zig  build
```

# Usage
zcc compile arguments string, and output assembler to console.

```bash
zcc "a = 10; return a;" > ./tmp.s
cc -o a.out ./temp.s
```

[![Zig Build](https://github.com/r-mutax/zcc/actions/workflows/zig_build.yml/badge.svg)](https://github.com/r-mutax/zcc/actions/workflows/zig_build.yml)