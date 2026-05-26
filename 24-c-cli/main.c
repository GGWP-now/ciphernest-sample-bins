#define _CRT_SECURE_NO_WARNINGS
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

/* Simple CLI utility: fibonacci + prime sieve + file I/O demo.
   Exercises CRT, heap allocation, and basic file operations. */

static int fib(int n) {
    if (n <= 1) return n;
    int a = 0, b = 1;
    for (int i = 2; i <= n; ++i) {
        int t = a + b;
        a = b;
        b = t;
    }
    return b;
}

static int is_prime(int n) {
    if (n < 2) return 0;
    for (int i = 2; i * i <= n; ++i)
        if (n % i == 0) return 0;
    return 1;
}

static void sieve(int limit, int **primes, int *count) {
    char *buf = (char *)calloc((size_t)limit + 1, 1);
    if (!buf) { *primes = NULL; *count = 0; return; }
    for (int i = 2; i * i <= limit; ++i)
        if (!buf[i])
            for (int j = i * i; j <= limit; j += i)
                buf[j] = 1;
    int cnt = 0;
    for (int i = 2; i <= limit; ++i)
        if (!buf[i]) cnt++;
    *primes = (int *)malloc((size_t)cnt * sizeof(int));
    if (*primes) {
        int idx = 0;
        for (int i = 2; i <= limit; ++i)
            if (!buf[i]) (*primes)[idx++] = i;
    }
    *count = cnt;
    free(buf);
}

int main(int argc, char **argv) {
    int limit = 100;
    if (argc > 1) limit = atoi(argv[1]);
    if (limit < 10) limit = 10;

    printf("C CLI Victim -- Prime Sieve + Fibonacci\n");
    printf("Limit: %d\n\n", limit);

    /* Fibonacci */
    printf("Fibonacci(%d) = %d\n", limit, fib(limit));

    /* Prime sieve */
    int *primes = NULL;
    int count = 0;
    sieve(limit, &primes, &count);
    printf("Primes up to %d: %d\n", limit, count);
    if (primes && count > 0) {
        printf("Largest prime: %d\n", primes[count - 1]);
        free(primes);
    }

    /* File I/O */
    const char *fname = "c_cli_test.txt";
    FILE *fp = fopen(fname, "w");
    if (fp) {
        fprintf(fp, "C CLI Victim -- %d primes up to %d\n", count, limit);
        fclose(fp);
    }

    /* Read back */
    fp = fopen(fname, "r");
    if (fp) {
        char line[256];
        if (fgets(line, sizeof(line), fp))
            printf("File I/O: %s", line);
        fclose(fp);
        remove(fname);
    }

    /* CRC-like checksum */
    unsigned long hash = 5381;
    for (int i = 0; i < count; ++i)
        hash = ((hash << 5) + hash) + (unsigned)primes[i];
    printf("Checksum: 0x%08lX\n", hash);

    (void)argv; /* suppress unused warning */
    return 0;
}
