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

assert 0 "int main(){return 0;}"
assert 42 "int main(){return 42;}"
assert 5 "int main(){return 2+3;}"
assert 3 "int main(){return 7-4;}"
assert 13 "int main(){return 1 + 3 * 4;}"
assert 4 "int main(){return 2 + 4 / 2;}"
assert 16 "int main(){return (1 + 3) * 4;}"
assert 1 "int main(){return -3 * 3 + +10;}"
assert 1 "int main(){return 0==0;}"
assert 1 "int main(){return 1 != 2;}"
assert 1 "int main(){return 3<5;}"
assert 2 "int main(){return (2>1) + (3 <=5);}"
assert 4 "int main(){return 12 & 6;}"
assert 5 "int main(){return 3 ^ 6;}"
assert 7 "int main(){return 3 | 6;}"


# logic and
assert 1 "int main(){return 1 && 44;}"
assert 0 "int main(){return 0 && 44;}"
assert 0 "int main(){return 1 && 0;}"
assert 0 "int main(){return 0 && 0;}"

# logic or
assert 1 "int main(){return 1 || 44;}"
assert 1 "int main(){return 0 || 44;}"
assert 1 "int main(){return 1 || 0;}"
assert 0 "int main(){return 0 || 0;}"

# variable
assert 5 "int main(){int abc;abc= 5;return abc;}"
assert 6 "int main(){int a; int b;a=2;b=3;return a * b;}"

# if statement
assert 10 "int main(){if(1) return 10; return 10;}"
assert 20 "int main(){if(0) return 10; return 20;}"
assert 23 "int main(){if(0) return 10; else return 23; return 30;}"
assert 5 "int main(){int a;a = 10; if(1){ a = a + 5; a = a - 10;} return a;}"

# while statement
assert 5 "int main(){int a; a = 0; while(a < 5) a = a + 1; return a;}"

# for statement
assert 3 "int main(){int a; int b; a = 0; for(a = 1; a < 3; a = a + 1) b = 0; return a;}"

# blank statement
assert 1 "int main(){ ;;;;;;;; return 1; }"

# function call
assert 4 "int func0(){ return 4;} int main(){ return func0();}"
assert 5 "int func1(a){ return a; } int main() {return func1(5); }"
assert 6 "int func2(a, b){ return a + b;} int main(){return func2(1, 5);}"
assert 7 "int func3(a, b, c){ return a + b + c;} int main(){return func3(1, 5, 1);}"
assert 9 "int func4(a, b, c, d){ return a + b + c + d;} int main(){return func4(1, 5, 1, 2);}"
assert 12 "int func5(a, b, c, d, e){ return a + b + c + d + e;} int main(){return func5(1, 5, 2, 3, 1);}"
assert 18 "int func6(a, b, c, d, e, f){ return a + b + c + d + e + f;} int main(){return func6(1, 5, 4, 5, 1, 2);}"

# address
assert 5 "int main(){int a; int b;  a = 10; b = &a; return *b - 5;}"
