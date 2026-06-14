/*
 * ============================================================================
 * AES-128 Accelerator -- ILA Loop Application for ZynqMP (KV260)
 * ============================================================================
 *
 * Minimal app for ILA debugging. Does key load + encrypts the same block
 * in an infinite loop, generating continuous AXI4-Lite traffic for the
 * system_ila to capture.
 *
 * Build: make ila
 * Run:   Download via JTAG after ILA is armed
 * ============================================================================
 */
#define __BAREMETAL__
#define FSBL_BOOT

#include "aes_hw.h"

/* ---- UART (UART1 @ 0xFF010000 on KV260) ---- */
#define UART0_BASE      0xFF010000
#define UART_CR         (*(volatile uint32_t *)(UART0_BASE + 0x00))
#define UART_MR         (*(volatile uint32_t *)(UART0_BASE + 0x04))
#define UART_BAUDGEN    (*(volatile uint32_t *)(UART0_BASE + 0x18))
#define UART_SR         (*(volatile uint32_t *)(UART0_BASE + 0x2C))
#define UART_FIFO       (*(volatile uint32_t *)(UART0_BASE + 0x30))
#define UART_BAUDDIV    (*(volatile uint32_t *)(UART0_BASE + 0x34))
#define UART_SR_TXFULL  (1 << 4)

static void uart_init(void) {
    UART_CR = 0x0003;
    for (volatile int i = 0; i < 100; i++);
    UART_MR  = 0x0020;
    UART_BAUDGEN = 124;
    UART_BAUDDIV = 6;
    UART_CR  = 0x0014;
}

static void uart_putc(char c) {
    while (UART_SR & UART_SR_TXFULL) ;
    UART_FIFO = c;
}

static void uart_puts(const char *s) {
    while (*s) uart_putc(*s++);
}

static void uart_hex32(uint32_t val) {
    const char hex[] = "0123456789ABCDEF";
    for (int i = 7; i >= 0; i--)
        uart_putc(hex[(val >> (i*4)) & 0xF]);
}

static void uart_dec(uint32_t val) {
    char buf[12];
    int i = 0;
    if (val == 0) { uart_putc('0'); return; }
    while (val > 0) { buf[i++] = '0' + (val % 10); val /= 10; }
    while (i > 0) uart_putc(buf[--i]);
}

/* ---- NIST SP800-38A Block 1 ---- */
static const uint32_t key[4] = {0x09CF4F3C, 0xABF71588, 0x28AED2A6, 0x2B7E1516};
static const uint32_t pt[4]  = {0x7393172A, 0xE93D7E11, 0x2E409F96, 0x6BC1BEE2};
static const uint32_t expected[4] = {0x2466EF97, 0xA89ECAF3, 0x0D7A3660, 0x3AD77BB4};

int main(void) {
    uint32_t ct[4];

    uart_init();

    uart_puts("\r\n");
    uart_puts("==============================================\r\n");
    uart_puts("  AES-128 ILA Loop (continuous encryption)\r\n");
    uart_puts("==============================================\r\n\r\n");

    /* ---- Key load with reset protocol ---- */
    uart_puts("Holding AES core in reset...\r\n");
    aes_hold_reset();

    uart_puts("Loading key...\r\n");
    aes_load_key(key);

    for (volatile int d = 0; d < 100; d++);

    uart_puts("Releasing reset...\r\n");
    aes_release_reset();

    int timeout;
    for (timeout = 0; timeout < 100000 && !aes_key_ready(); timeout++);
    if (!aes_key_ready()) {
        uart_puts("ERROR: Key expansion timeout!\r\n");
        while (1) __asm__ volatile("wfi");
    }
    uart_puts("Key expansion complete.\r\n\r\n");

    /* ---- Verify correctness once ---- */
    aes_load_plaintext(pt);
    aes_start();
    while (!aes_valid_out()) ;
    aes_read_ciphertext(ct);
    aes_stop();

    int match = 1;
    for (int j = 0; j < 4; j++) {
        if (ct[j] != expected[j]) { match = 0; break; }
    }
    if (match) {
        uart_puts("Verify: [PASS] CT = ");
    } else {
        uart_puts("Verify: [FAIL] CT = ");
    }
    for (int j = 3; j >= 0; j--) { uart_hex32(ct[j]); uart_putc(' '); }
    uart_puts("\r\n\r\n");

    /* ---- Infinite encryption loop for ILA capture ---- */
    uart_puts("Starting infinite encryption loop...\r\n");
    uart_puts("(ILA can capture AXI transactions continuously)\r\n\r\n");

    uint32_t iter = 0;
    while (1) {
        aes_load_plaintext(pt);
        aes_start();
        while (!aes_valid_out()) ;
        aes_read_ciphertext(ct);
        aes_stop();

        for (volatile int d = 0; d < 50; d++);

        iter++;
        if (iter % 10000 == 0) {
            uart_puts("Iter ");
            uart_dec(iter);
            uart_puts(" (still running, CT = ");
            uart_hex32(ct[3]);
            uart_puts(" " );
            uart_hex32(ct[2]);
            uart_puts(" ");
            uart_hex32(ct[1]);
            uart_puts(" ");
            uart_hex32(ct[0]);
            uart_puts(")\r\n");
        }
    }

    return 0;
}
