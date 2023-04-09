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
assert 5 "main(){int abc;abc= 5;return abc;}"
assert 6 "main(){int a; int b;a=2;b=3;return a * b;}"

# if statement
assert 10 "main(){if(1) return 10; return 10;}"
assert 20 "main(){if(0) return 10; return 20;}"
assert 23 "main(){if(0) return 10; else return 23; return 30;}"
assert 5 "main(){int a;a = 10; if(1){ a = a + 5; a = a - 10;} return a;}"

# while statement
assert 5 "main(){int a; a = 0; while(a < 5) a = a + 1; return a;}"

# for statement
assert 3 "main(){int a; int b; a = 0; for(a = 1; a < 3; a = a + 1) b = 0; return a;}"

# blank statement
assert 1 "main(){ ;;;;;;;; return 1; }"

# function call
assert 4 "func0(){ return 4;} main(){ return func0();}"
assert 5 "func1(a){ return a; } main() {return func1(5); }"
assert 6 "func2(a, b){ return a + b;} main(){return func2(1, 5);}"
assert 7 "func3(a, b, c){ return a + b + c;} main(){return func3(1, 5, 1);}"
assert 9 "func4(a, b, c, d){ return a + b + c + d;} main(){return func4(1, 5, 1, 2);}"
assert 12 "func5(a, b, c, d, e){ return a + b + c + d + e;} main(){return func5(1, 5, 2, 3, 1);}"
assert 18 "func6(a, b, c, d, e, f){ return a + b + c + d + e + f;} main(){return func6(1, 5, 4, 5, 1, 2);}"

# address
assert 5 "main(){int a; int b;  a = 10; b = &a; return *b - 5;}"
