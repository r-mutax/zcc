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

assert 0 "main(){return 0;}"
assert 42 "main(){return 42;}"
assert 5 "main(){return 2+3;}"
assert 3 "main(){return 7-4;}"
assert 13 "main(){return 1 + 3 * 4;}"
assert 4 "main(){return 2 + 4 / 2;}"
assert 16 "main(){return (1 + 3) * 4;}"
assert 1 "main(){return -3 * 3 + +10;}"
assert 1 "main(){return 0==0;}"
assert 1 "main(){return 1 != 2;}"
assert 1 "main(){return 3<5;}"
assert 2 "main(){return (2>1) + (3 <=5);}"
assert 4 "main(){return 12 & 6;}"
assert 5 "main(){return 3 ^ 6;}"
assert 7 "main(){return 3 | 6;}"


# logic and
assert 1 "main(){return 1 && 44;}"
assert 0 "main(){return 0 && 44;}"
assert 0 "main(){return 1 && 0;}"
assert 0 "main(){return 0 && 0;}"

# logic or
assert 1 "main(){return 1 || 44;}"
assert 1 "main(){return 0 || 44;}"
assert 1 "main(){return 1 || 0;}"
assert 0 "main(){return 0 || 0;}"

# variable
assert 5 "main(){abc= 5;return abc;}"
assert 6 "main(){a=2;b=3;return a * b;}"

# if statement
assert 10 "main(){if(1) return 10; return 10;}"
assert 20 "main(){if(0) return 10; return 20;}"
assert 23 "main(){if(0) return 10; else return 23; return 30;}"
assert 5 "main(){a = 10; if(1){ a = a + 5; a = a - 10;} return a;}"

# while statement
assert 5 "main(){a = 0; while(a < 5) a = a + 1; return a;}"

# for statement
assert 3 "main(){a = 0; for(a = 1; a < 3; a = a + 1) b = 0; return a;}"

# function call
assert 5 "funcA(){return 5;} main(){ return funcA(); }"
assert 6 "funcA(abc, bcd){ return  19; } main(){ return 6; }"