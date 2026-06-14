/*
 * ============================================================================
 * AES-128 Accelerator — Linux User-Space Application for ZynqMP (KV260)
 * ============================================================================
 *
 * Runs on PetaLinux (Cortex-A53) and accesses the AES hardware via /dev/mem.
 *
 * Features:
 *   - Functional correctness test (NIST SP 800-38A test vectors)
 *   - Latency measurement (single block, nanosecond precision)
 *   - Throughput benchmark (1000 blocks)
 *
 * Build:  aarch64-linux-gnu-gcc -O2 -Wall aes_linux.c -o aes_linux
 * Run:    ./aes_linux   (requires root or /dev/mem access)
 * ============================================================================
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <time.h>

/* Hardware definitions — uses aes_hw.h Linux path (aes_base) */
#include "aes_hw.h"

/* mmap'd base pointer (referenced by aes_hw.h inline functions) */
volatile uint8_t *aes_base = NULL;

/* ---- Page-aligned mmap helper ---- */
#define MAP_SIZE  4096   /* AES register space fits in one 4K page */
#define MAP_MASK  (MAP_SIZE - 1)

static int aes_hw_init(void) {
    int fd;
    void *map_base;

    fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (fd < 0) {
        perror("open /dev/mem");
        fprintf(stderr, "Hint: run as root (sudo ./aes_linux)\n");
        return -1;
    }

    map_base = mmap(NULL, MAP_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED,
                    fd, AES_BASE_ADDR & ~MAP_MASK);
    if (map_base == MAP_FAILED) {
        perror("mmap");
        close(fd);
        return -1;
    }

    aes_base = (volatile uint8_t *)map_base;
    close(fd);
    return 0;
}

static void aes_hw_cleanup(void) {
    if (aes_base) {
        munmap((void *)aes_base, MAP_SIZE);
        aes_base = NULL;
    }
}

/* ---- Timer helpers ---- */
static inline uint64_t get_time_ns(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000000ULL + (uint64_t)ts.tv_nsec;
}

/* ---- Test Vectors (NIST SP 800-38A, FIPS-197) ---- */

typedef struct {
    const char *name;
    uint32_t key[4];
    uint32_t plaintext[4];
    uint32_t expected[4];
} aes_test_vector_t;

/* word[3]=MSW=first NIST bytes, word[0]=LSW=last NIST bytes */
static const aes_test_vector_t vectors[] = {
    {
        "NIST SP800-38A Block 1",
        {0x09CF4F3C, 0xABF71588, 0x28AED2A6, 0x2B7E1516},
        {0x7393172A, 0xE93D7E11, 0x2E409F96, 0x6BC1BEE2},
        {0x2466EF97, 0xA89ECAF3, 0x0D7A3660, 0x3AD77BB4},
    },
    {
        "NIST SP800-38A Block 2",
        {0x09CF4F3C, 0xABF71588, 0x28AED2A6, 0x2B7E1516},
        {0x45AF8E51, 0x9EB76FAC, 0x1E03AC9C, 0xAE2D8A57},
        {0x96FDBAAF, 0xE785895A, 0x03B9699D, 0xF5D3D585},
    },
    {
        "NIST SP800-38A Block 3",
        {0x09CF4F3C, 0xABF71588, 0x28AED2A6, 0x2B7E1516},
        {0x1A0A52EF, 0xE5FBC119, 0xA35CE411, 0x30C81C46},
        {0xED030688, 0x881B00E3, 0x598ECE23, 0x43B1CD7F},
    },
    {
        "NIST SP800-38A Block 4",
        {0x09CF4F3C, 0xABF71588, 0x28AED2A6, 0x2B7E1516},
        {0xE66CEA35, 0xAD2B417B, 0xDF4F9B17, 0xF69F2445},
        {0x184C7549, 0x6892DE6E, 0xEC52DDB3, 0x9367966A},
    },
    {
        "FIPS-197 App B",
        {0x09CF4F3C, 0xABF71588, 0x28AED2A6, 0x2B7E1516},
        {0xE0370734, 0x313198A2, 0x885A308D, 0x3243F6A8},
        {0x196A0B32, 0xDC118597, 0x02DC09FB, 0x3925841D},
    },
};

#define NUM_TV (sizeof(vectors)/sizeof(vectors[0]))

/* ---- Main Application ---- */

int main(int argc, char *argv[]) {
    int pass_count = 0;
    int total_tests = 0;
    uint32_t ct[4];
    int bench_blocks = 1000;

    if (argc > 1) {
        bench_blocks = atoi(argv[1]);
        if (bench_blocks <= 0) bench_blocks = 1000;
    }

    printf("\n");
    printf("==============================================\n");
    printf("  AES-128 Hardware Accelerator\n");
    printf("  Linux User-Space Test on ZynqMP (KV260)\n");
    printf("==============================================\n");
    printf("  AES base address: 0x%08X\n", AES_BASE_ADDR);
    printf("\n");

    /* ---- Initialize hardware access ---- */
    if (aes_hw_init() < 0) {
        return 1;
    }
    printf("Hardware mapped successfully.\n\n");

    /* ---- Phase 1: Functional Correctness Test ---- */
    printf("--- Phase 1: Functional Correctness ---\n");

    /* Hold AES core in reset before writing key */
    printf("Holding AES core in reset...\n");
    aes_hold_reset();

    printf("Loading AES-128 key...\n");
    aes_load_key(vectors[0].key);

    /* Small delay to ensure key registers are written */
    for (volatile int d = 0; d < 100; d++);

    printf("Releasing AES core from reset...\n");
    aes_release_reset();

    /* Wait for key expansion */
    int timeout;
    for (timeout = 0; timeout < 100000 && !aes_key_ready(); timeout++);
    if (!aes_key_ready()) {
        printf("ERROR: Key expansion timeout!\n");
        aes_hw_cleanup();
        return 1;
    }
    printf("Key expansion complete.\n\n");

    for (int i = 0; i < (int)NUM_TV; i++) {
        aes_load_plaintext(vectors[i].plaintext);
        aes_start();

        for (timeout = 0; timeout < 10000 && !aes_valid_out(); timeout++);

        if (timeout >= 10000) {
            printf("  [FAIL] %s - timeout\n", vectors[i].name);
            continue;
        }

        aes_read_ciphertext(ct);
        aes_stop();

        /* Small delay for pipeline flush */
        for (volatile int d = 0; d < 100; d++);

        total_tests++;
        int match = 1;
        for (int j = 0; j < 4; j++) {
            if (ct[j] != vectors[i].expected[j]) {
                match = 0;
                break;
            }
        }

        if (match) {
            pass_count++;
            printf("  [PASS] %s\n", vectors[i].name);
        } else {
            printf("  [FAIL] %s\n", vectors[i].name);
            printf("    Got:      %08X %08X %08X %08X\n",
                   ct[3], ct[2], ct[1], ct[0]);
            printf("    Expected: %08X %08X %08X %08X\n",
                   vectors[i].expected[3], vectors[i].expected[2],
                   vectors[i].expected[1], vectors[i].expected[0]);
        }
    }

    printf("\nFunctional Test: %d/%d passed\n\n", pass_count, total_tests);

    /* ---- Phase 2: Latency Measurement ---- */
    printf("--- Phase 2: Latency Measurement ---\n");

    /* Key already loaded and expanded in Phase 1 */
    uint32_t pt[4]  = {0x7393172A, 0xE93D7E11, 0x2E409F96, 0x6BC1BEE2};

    aes_load_plaintext(pt);

    uint64_t t_start = get_time_ns();
    aes_start();
    while (!aes_valid_out());
    uint64_t t_end = get_time_ns();
    aes_read_ciphertext(ct);
    aes_stop();

    uint64_t latency_ns = t_end - t_start;

    printf("  Single-block latency: %llu ns\n",
           (unsigned long long)latency_ns);
    printf("\n");

    /* ---- Phase 3: Throughput Benchmark ---- */
    printf("--- Phase 3: Throughput Benchmark (%d blocks) ---\n", bench_blocks);

    aes_load_plaintext(pt);

    uint64_t bench_start = get_time_ns();
    for (int b = 0; b < bench_blocks; b++) {
        aes_start();
        while (!aes_valid_out());
        aes_read_ciphertext(ct);
        aes_stop();
        for (volatile int d = 0; d < 20; d++);
    }
    uint64_t bench_end = get_time_ns();

    uint64_t total_ns = bench_end - bench_start;
    uint64_t ns_per_block = total_ns / bench_blocks;
    double blocks_per_sec = (double)bench_blocks / ((double)total_ns / 1e9);
    double mbps = (blocks_per_sec * 128.0) / 1e6;

    printf("  Blocks encrypted: %d\n", bench_blocks);
    printf("  Total time:       %llu us\n", (unsigned long long)(total_ns / 1000));
    printf("  Time per block:   %llu ns\n", (unsigned long long)ns_per_block);
    printf("  Throughput:       %.2f Mbps (%.0f blocks/sec)\n",
           mbps, blocks_per_sec);
    printf("\n");

    /* ---- Summary ---- */
    printf("==============================================\n");
    printf("  SUMMARY\n");
    printf("==============================================\n");
    printf("  Correctness: %d/%d passed\n", pass_count, total_tests);
    printf("  Latency:     %llu ns/block\n",
           (unsigned long long)latency_ns);
    printf("  Throughput:  %.2f Mbps (%.0f blocks/sec)\n",
           mbps, blocks_per_sec);
    printf("==============================================\n");

    aes_hw_cleanup();
    return (pass_count == total_tests) ? 0 : 1;
}
