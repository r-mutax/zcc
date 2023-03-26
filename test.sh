#!/bin/bash
assert() {
  expected="$1"
  input="$2"

  ./zig-out/bin/zcc "$input" > tmp.s
  cc -o tmp tmp.s
  ./tmp
  actual="$?"

  if [ "$actual" = "$expected" ]; then
    echo "$input => $actual"
  else
    echo "$input => $expected expected, but got $actual"
    exit 1
  fi
}

assert 0 "return 0;"
assert 42 "return 42;"
assert 5 "return 2+3;"
assert 3 "return 7-4;"
assert 13 "return 1 + 3 * 4;"
assert 4 "return 2 + 4 / 2;"
assert 16 "return (1 + 3) * 4;"
assert 1 "return -3 * 3 + +10;"
assert 1 "return 0==0;"
assert 1 "return 1 != 2;"
assert 1 "return 3<5;"
assert 2 "return (2>1) + (3 <=5);"
assert 4 "return 12 & 6;"
assert 5 "return 3 ^ 6;"
assert 7 "return 3 | 6;"


# logic and
assert 1 "return 1 && 44;"
assert 0 "return 0 && 44;"
assert 0 "return 1 && 0;"
assert 0 "return 0 && 0;"

# logic or
assert 1 "return 1 || 44;"
assert 1 "return 0 || 44;"
assert 1 "return 1 || 0;"
assert 0 "return 0 || 0;"

