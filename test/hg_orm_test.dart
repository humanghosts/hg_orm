import 'dart:async';

void main() async {
  await a();
  await b();
  print("c");
  await Future.delayed(const Duration(seconds: 3));
}

Future<void> a() async {
  await Future.delayed(const Duration(seconds: 1));
  print("a");
}

Future<void> b() async {
  await Future.delayed(const Duration(milliseconds: 200));
  print("b");
}
