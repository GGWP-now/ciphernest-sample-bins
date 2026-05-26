#include <cstdint>
#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <vector>

// ---------------------------------------------------------------------------
// RLE compression: emit (length-1, byte) pairs for each run of identical bytes.
// max run per pair is 256 bytes. Returns compressed size, or 0 on overflow.
// ---------------------------------------------------------------------------
size_t rle_compress(const uint8_t* in, size_t in_len, uint8_t* out, size_t out_cap)
{
    size_t out_pos = 0;
    size_t i = 0;

    while (i < in_len) {
        uint8_t cur = in[i];
        size_t run = 1;
        while (i + run < in_len && in[i + run] == cur && run < 256) {
            ++run;
        }
        // run is in [1..256]
        if (out_pos + 2 > out_cap) {
            return 0; // output buffer exhausted
        }
        out[out_pos++] = (uint8_t)(run - 1);
        out[out_pos++] = cur;
        i += run;
    }
    return out_pos;
}

// ---------------------------------------------------------------------------
// RLE decompression: expand (length-1, byte) pairs back to original data.
// Returns decompressed size, or 0 on overflow / truncated input.
// ---------------------------------------------------------------------------
size_t rle_decompress(const uint8_t* in, size_t in_len, uint8_t* out, size_t out_cap)
{
    size_t out_pos = 0;
    size_t i = 0;

    while (i < in_len) {
        if (i + 2 > in_len) {
            return 0; // truncated pair
        }
        size_t run = (size_t)in[i] + 1;   // run ∈ [1..256]
        uint8_t val = in[i + 1];
        if (out_pos + run > out_cap) {
            return 0; // output would overflow
        }
        std::memset(out + out_pos, val, run);
        out_pos += run;
        i += 2;
    }
    return out_pos;
}

// ---------------------------------------------------------------------------
// FNV-1a 64-bit non-cryptographic hash.
// ---------------------------------------------------------------------------
uint64_t simple_hash(const uint8_t* data, size_t len)
{
    uint64_t h = 0xcbf29ce484222325ULL;
    for (size_t i = 0; i < len; ++i) {
        h ^= data[i];
        h *= 0x100000001b3ULL;
    }
    return h;
}

// ---------------------------------------------------------------------------
// Simple LCG PRNG (glibc-style linear congruential generator).
// ---------------------------------------------------------------------------
static uint32_t lcg_state_ = 0;

static void lcg_seed(uint32_t seed)
{
    lcg_state_ = seed;
}

static uint8_t lcg_byte()
{
    lcg_state_ = 1103515245u * lcg_state_ + 12345u;
    return (uint8_t)(lcg_state_ >> 16);
}

// ---------------------------------------------------------------------------
// Helper: run a full compress → decompress → hash round-trip on a buffer.
// ---------------------------------------------------------------------------
static void test_roundtrip(const uint8_t* data, size_t data_len,
                           const char* label)
{
    std::printf("\n=== %s ===\n", label);
    std::printf("  Input size  : %zu bytes\n", data_len);

    // Hash of original
    uint64_t hash_before = simple_hash(data, data_len);
    std::printf("  Hash (orig) : 0x%016llx\n",
                (unsigned long long)hash_before);

    // Compress
    if (data_len == 0) {
        // Edge: compression of empty is empty
        std::printf("  Compressed  : 0 bytes (empty)\n");
        std::printf("  Ratio       : N/A (empty)\n");
        std::printf("  Hash (decom): 0x%016llx\n",
                    (unsigned long long)hash_before);
        std::printf("  Round-trip  : PASS\n");
        return;
    }

    // Upper bound: worst case each byte becomes (run=1) → 2 bytes
    size_t max_comp = data_len * 2 + 2;
    std::vector<uint8_t> comp_buf(max_comp);

    size_t comp_len = rle_compress(data, data_len,
                                   comp_buf.data(), comp_buf.size());
    if (comp_len == 0) {
        std::printf("  Compress    : FAIL (buffer overflow)\n");
        return;
    }

    double ratio = (double)data_len / (double)comp_len;
    std::printf("  Compressed  : %zu bytes\n", comp_len);
    std::printf("  Ratio       : %.3f : 1\n", ratio);

    // Decompress
    std::vector<uint8_t> decomp_buf(data_len ? data_len : 1);
    size_t decomp_len = rle_decompress(comp_buf.data(), comp_len,
                                       decomp_buf.data(), decomp_buf.size());
    if (decomp_len == 0) {
        std::printf("  Decompress  : FAIL\n");
        return;
    }
    if (decomp_len != data_len) {
        std::printf("  Decompress  : size mismatch (%zu vs %zu)\n",
                    decomp_len, data_len);
        return;
    }

    uint64_t hash_after = simple_hash(decomp_buf.data(), decomp_len);
    std::printf("  Hash (decom): 0x%016llx\n",
                (unsigned long long)hash_after);

    bool ok = (hash_before == hash_after);
    std::printf("  Round-trip  : %s\n", ok ? "PASS" : "FAIL");
}

// ---------------------------------------------------------------------------
// Edge-case helpers
// ---------------------------------------------------------------------------
static void test_empty()
{
    // Passing nullptr with zero length is safe for our functions
    test_roundtrip(nullptr, 0, "EMPTY BUFFER");
}

static void test_single_byte()
{
    uint8_t buf[] = { 0xAB };
    test_roundtrip(buf, 1, "SINGLE BYTE");
}

static void test_all_same()
{
    // 1000 bytes of the same value – best-case RLE
    std::vector<uint8_t> buf(1000, 0xAB);
    test_roundtrip(buf.data(), buf.size(), "ALL SAME (1000 x 0xAB)");
}

static void test_random()
{
    // 2000 pseudo-random bytes – worst-case RLE
    std::vector<uint8_t> buf(2000);
    lcg_seed(0xDEAD);
    for (size_t i = 0; i < buf.size(); ++i) {
        buf[i] = lcg_byte();
    }
    test_roundtrip(buf.data(), buf.size(), "PSEUDO-RANDOM (2000 bytes)");
}

// ---------------------------------------------------------------------------
// Large 1 MB loop
// ---------------------------------------------------------------------------
static void test_large_loop()
{
    std::printf("\n\n========== LARGE LOOP: 1 MiB BUFFER ==========\n");

    size_t const SIZE = 1024 * 1024;   // 1 MiB
    std::vector<uint8_t> buf(SIZE);

    // Fill with LCG stream
    lcg_seed(0xCAFEBABE);
    for (size_t i = 0; i < SIZE; ++i) {
        buf[i] = lcg_byte();
    }

    uint64_t hash_before = simple_hash(buf.data(), SIZE);
    std::printf("Input size    : %zu bytes (1 MiB)\n", SIZE);
    std::printf("Hash (orig)   : 0x%016llx\n",
                (unsigned long long)hash_before);

    // Compress
    size_t max_comp = SIZE * 2 + 2;
    std::vector<uint8_t> comp_buf(max_comp);
    size_t comp_len = rle_compress(buf.data(), SIZE,
                                   comp_buf.data(), comp_buf.size());
    if (comp_len == 0) {
        std::printf("Compress      : FAIL (overflow)\n");
        return;
    }

    double ratio = (double)SIZE / (double)comp_len;
    std::printf("Compressed    : %zu bytes\n", comp_len);
    std::printf("Ratio         : %.3f : 1\n", ratio);

    // Decompress
    std::vector<uint8_t> decomp_buf(SIZE);
    size_t decomp_len = rle_decompress(comp_buf.data(), comp_len,
                                       decomp_buf.data(), decomp_buf.size());
    if (decomp_len != SIZE) {
        std::printf("Decompress    : FAIL (size %zu)\n", decomp_len);
        return;
    }

    uint64_t hash_after = simple_hash(decomp_buf.data(), decomp_len);
    std::printf("Hash (decomp) : 0x%016llx\n",
                (unsigned long long)hash_after);
    std::printf("Round-trip    : %s\n",
                (hash_before == hash_after) ? "PASS" : "FAIL");
    std::printf("Hashes match  : %s\n",
                (hash_before == hash_after) ? "YES" : "NO");
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
int main()
{
    std::printf("========================================\n");
    std::printf("  FILE COMPRESSOR & HASH UTILITY\n");
    std::printf("  RLE + FNV-1a 64-bit\n");
    std::printf("========================================\n");

    // Edge cases
    test_empty();
    test_single_byte();
    test_all_same();
    test_random();

    // Large 1 MiB loop
    test_large_loop();

    std::printf("\n--- All tests completed ---\n");
    return 0;
}
