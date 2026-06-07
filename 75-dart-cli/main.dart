// Dart CLI Victim -- Prime Sieve + Fibonacci
// Build: dart compile exe main.dart -o dart_cli.exe
import 'dart:io';

int fib(int n) {
  if (n <= 1) return n;
  var a = 0, b = 1;
  for (var i = 2; i <= n; i++) {
    final t = a + b;
    a = b;
    b = t;
  }
  return b;
}

void main(List<String> args) {
  var limit = 100;
  if (args.isNotEmpty) {
    final v = int.tryParse(args[0]);
    if (v != null && v >= 10) limit = v;
  }

  print('Dart CLI Victim -- Prime Sieve + Fibonacci');
  print('Limit: $limit');
  print('');
  print('Fibonacci($limit) = ${fib(limit)}');

  final buf = List<bool>.filled(limit + 1, false);
  for (var i = 2; i * i <= limit; i++) {
    if (!buf[i]) {
      for (var j = i * i; j <= limit; j += i) {
        buf[j] = true;
      }
    }
  }

  var count = 0;
  var largest = 0;
  var hash = 5381;
  for (var n = 2; n <= limit; n++) {
    if (!buf[n]) {
      count++;
      largest = n;
      hash = (hash << 5) + hash + n;
    }
  }

  print('Primes up to $limit: $count');
  if (count > 0) print('Largest prime: $largest');

  const fname = 'dart_cli_test.txt';
  try {
    final f = File(fname);
    f.writeAsStringSync('Dart CLI Victim -- $count primes up to $limit\n');
    stdout.write('File I/O: ${f.readAsStringSync()}');
    f.deleteSync();
  } catch (_) {}

  final hex = hash.toRadixString(16).toUpperCase().padLeft(16, '0');
  print('Checksum: 0x$hex');
}
