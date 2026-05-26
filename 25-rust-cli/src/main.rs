use std::env;
use std::fs;
use std::io::Write;

fn fib(n: u32) -> u64 {
    match n {
        0 | 1 => n as u64,
        _ => {
            let (mut a, mut b) = (0u64, 1u64);
            for _ in 2..=n {
                let t = a.wrapping_add(b);
                a = b;
                b = t;
            }
            b
        }
    }
}

fn sieve(limit: usize) -> Vec<usize> {
    let mut buf = vec![false; limit + 1];
    let mut i = 2;
    while i * i <= limit {
        if !buf[i] {
            let mut j = i * i;
            while j <= limit {
                buf[j] = true;
                j += i;
            }
        }
        i += 1;
    }
    (2..=limit).filter(|&n| !buf[n]).collect()
}

fn main() {
    let limit: usize = env::args()
        .nth(1)
        .and_then(|s| s.parse().ok())
        .unwrap_or(100)
        .max(10);

    println!("Rust CLI Victim -- Prime Sieve + Fibonacci");
    println!("Limit: {limit}\n");

    println!("Fibonacci({limit}) = {}", fib(limit as u32));

    let primes = sieve(limit);
    println!("Primes up to {limit}: {}", primes.len());
    if let Some(&largest) = primes.last() {
        println!("Largest prime: {largest}");
    }

    let fname = "rust_cli_test.txt";
    if let Ok(mut fp) = fs::File::create(fname) {
        let _ = writeln!(fp, "Rust CLI Victim -- {} primes up to {}", primes.len(), limit);
    }
    if let Ok(content) = fs::read_to_string(fname) {
        print!("File I/O: {content}");
    }
    let _ = fs::remove_file(fname);

    let hash: u64 = primes.iter().fold(5381u64, |h, &p| h.wrapping_shl(5).wrapping_add(h).wrapping_add(p as u64));
    println!("Checksum: 0x{hash:016X}");
}
