/*
 * ============================================================================
 * AES-128 Accelerator — Baremetal Application for ZynqMP (KV260)
 * ============================================================================
 *
 * Runs on Cortex-A53 #0 in AArch64 baremetal mode.
 * Accesses the AES hardware accelerator via AXI4-Lite at 0xA000_0000.
 *
 * Features:
 *   - Functional correctness test (NIST SP 800-38A test vectors)
 *   - Throughput benchmark (1000 blocks)
 *   - Latency measurement (single block)
 *
 * Build: make
 * Run:   Load ELF via JTAG (Vitis/XSCT) or SD card boot
 * ============================================================================
 */
#define __BAREMETAL__

#include "aes_hw.h"

/* ---- UART definitions for ZynqMP (KV260 uses PSU UART1 @ 0xFF010000) ---- */
/* KV260 board preset: UART1 on MIO 36/37, 100MHz IOPLL ref clock */
#define UART0_BASE      0xFF010000  /* UART1 base (KV260 uses UART1, NOT UART0) */
#define UART_CR         (*(volatile uint32_t *)(UART0_BASE + 0x00))
#define UART_MR         (*(volatile uint32_t *)(UART0_BASE + 0x04))
#define UART_BAUDGEN    (*(volatile uint32_t *)(UART0_BASE + 0x18))
#define UART_SR         (*(volatile uint32_t *)(UART0_BASE + 0x2C))
#define UART_FIFO       (*(volatile uint32_t *)(UART0_BASE + 0x30))
#define UART_BAUDDIV    (*(volatile uint32_t *)(UART0_BASE + 0x34))

#define UART_SR_TXFULL  (1 << 4)

/* Initialize UART0 for 115200 8N1 (FSBL uses DCC, so we must init UART ourselves) */
static void uart_init(void) {
    UART_CR = 0x0003;  /* TXRST | RXRST — reset TX/RX */
    for (volatile int i = 0; i < 100; i++);
    UART_MR  = 0x0020; /* Normal mode, 8 data bits, 1 stop bit, no parity */
    UART_BAUDGEN = 124; /* 100MHz ref: 100M/(124*7) = 115207 baud (~0.006% error) */
    UART_BAUDDIV = 6;
    UART_CR  = 0x0014; /* TXEN | RXEN */
}

/* Simple UART output */
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

static void uart_hex8(uint8_t val) {
    const char hex[] = "0123456789ABCDEF";
    uart_putc(hex[(val >> 4) & 0xF]);
    uart_putc(hex[val & 0xF]);
}

static void uart_dec(uint32_t val) {
    char buf[12];
    int i = 0;
    if (val == 0) { uart_putc('0'); return; }
    while (val > 0) { buf[i++] = '0' + (val % 10); val /= 10; }
    while (i > 0) uart_putc(buf[--i]);
}

/* ---- Timer for benchmarking (AArch64 Generic Timer via system registers) ---- */
static inline uint64_t read_generic_timer(void) {
    uint64_t val;
    __asm__ volatile("mrs %0, CNTPCT_EL0" : "=r"(val));
    return val;
}

static inline uint64_t read_timer_freq(void) {
    uint64_t val;
    __asm__ volatile("mrs %0, CNTFRQ_EL0" : "=r"(val));
    return val;
}

/* ---- Direct PCAP register programming (EL3, bypasses PMUFW) ---- */
/* When running at EL3 (after rst -processor with QSPI DDR init), we can  */
/* program the PCAP directly via CSU DMA. This replicates what PMUFW      */
/* does internally, but without version mismatch issues.                  */

/* Register addresses (from xilfpga_pcap.h and xcsudma_hw.h) */
#define REG_PCAP_CLK_CTRL          0xFF5E00A4U
#define REG_PCAP_CLK_EN_MASK       0x01000000U

#define REG_CSU_BASE               0xFFCA0000U
#define REG_CSU_SSS_CFG            (REG_CSU_BASE + 0x0008U)
#define REG_CSU_DMA_RESET          (REG_CSU_BASE + 0x000CU)
#define REG_CSU_PCAP_PROG          (REG_CSU_BASE + 0x3000U)
#define REG_CSU_PCAP_RDWR          (REG_CSU_BASE + 0x3004U)
#define REG_CSU_PCAP_CTRL          (REG_CSU_BASE + 0x3008U)
#define REG_CSU_PCAP_RESET         (REG_CSU_BASE + 0x300CU)
#define REG_CSU_PCAP_STATUS        (REG_CSU_BASE + 0x3010U)

#define PCAP_STS_WR_IDLE           0x00000001U
#define PCAP_STS_RD_IDLE           0x00000002U
#define PCAP_STS_PL_INIT           0x00000004U
#define PCAP_STS_PL_DONE           0x00000008U

#define PCAP_CTRL_PCAP_PR          0x00000001U
#define PCAP_PROG_PROG_B           0x00000001U
#define PCAP_RESET_MASK_BIT        0x00000001U

#define CSU_DMA_BASE               0xFFC80000U
#define CSU_DMA_SRC_ADDR           (CSU_DMA_BASE + 0x000U)
#define CSU_DMA_SRC_SIZE           (CSU_DMA_BASE + 0x004U)
#define CSU_DMA_SRC_STS            (CSU_DMA_BASE + 0x008U)
#define CSU_DMA_SRC_CTRL           (CSU_DMA_BASE + 0x00CU)
#define CSU_DMA_SRC_I_STS          (CSU_DMA_BASE + 0x014U)
#define CSU_DMA_SRC_ADDR_MSB       (CSU_DMA_BASE + 0x028U)
#define CSU_DMA_IXR_DONE           0x00000002U
#define CSU_DMA_CTRL_ENDIAN        0x00800000U

#define CSU_SSS_SRC_DMA            0x5U

#define REG_PMU_GLOBAL_BASE        0xFFD80000U
#define REG_PMU_PWRUP_STATUS       (REG_PMU_GLOBAL_BASE + 0x110U)
#define REG_PMU_PWRUP_EN           (REG_PMU_GLOBAL_BASE + 0x118U)
#define REG_PMU_PWRUP_TRIG         (REG_PMU_GLOBAL_BASE + 0x120U)
#define PMU_PWR_PL_MASK            0x800000U
#define REG_PMU_ISO_STATUS         (REG_PMU_GLOBAL_BASE + 0x310U)
#define REG_PMU_ISO_INT_EN         (REG_PMU_GLOBAL_BASE + 0x318U)
#define REG_PMU_ISO_TRIG           (REG_PMU_GLOBAL_BASE + 0x320U)
#define PMU_ISO_NONPCAP_MASK       0x00000004U

static inline uint32_t io_rd(uint64_t addr) {
    return *(volatile uint32_t *)(uintptr_t)addr;
}
static inline void io_wr(uint64_t addr, uint32_t val) {
    *(volatile uint32_t *)(uintptr_t)addr = val;
}

static int direct_pcap_load(uint64_t bs_addr, uint32_t bs_size) {
    volatile uint32_t regval;
    int timeout;

    uart_puts("  [PCAP] Starting direct PCAP bitstream load\r\n");
    uart_puts("  [PCAP] Bitstream @0x");
    uart_hex32((uint32_t)bs_addr);
    uart_puts(", size=");
    uart_dec(bs_size);
    uart_puts(" bytes\r\n");

    /* 1. Enable PCAP clock */
    regval = io_rd(REG_PCAP_CLK_CTRL);
    io_wr(REG_PCAP_CLK_CTRL, regval | REG_PCAP_CLK_EN_MASK);
    uart_puts("  [PCAP] PCAP clock enabled\r\n");

    /* 2. Power-up PL (PMU_GLOBAL power-up sequence) */
    io_wr(REG_PMU_PWRUP_EN, PMU_PWR_PL_MASK);
    io_wr(REG_PMU_PWRUP_TRIG, PMU_PWR_PL_MASK);
    timeout = 300000;
    while ((io_rd(REG_PMU_PWRUP_STATUS) & PMU_PWR_PL_MASK) != 0 && --timeout > 0);
    if (timeout <= 0) {
        uart_puts("  [PCAP] WARNING: PL power-up poll timeout (may be OK)\r\n");
    } else {
        uart_puts("  [PCAP] PL power-up OK\r\n");
    }

    /* 3. Remove PL isolation */
    io_wr(REG_PMU_ISO_INT_EN, PMU_ISO_NONPCAP_MASK);
    io_wr(REG_PMU_ISO_TRIG, PMU_ISO_NONPCAP_MASK);
    timeout = 300000;
    while ((io_rd(REG_PMU_ISO_STATUS) & PMU_ISO_NONPCAP_MASK) != 0 && --timeout > 0);
    if (timeout <= 0) {
        uart_puts("  [PCAP] WARNING: Isolation removal timeout (may be OK)\r\n");
    } else {
        uart_puts("  [PCAP] Isolation removed\r\n");
    }

    /* 4. Reset CSU DMA */
    io_wr(REG_CSU_DMA_RESET, 1);
    io_wr(REG_CSU_DMA_RESET, 0);

    /* 5. Init PCAP: take out of reset, set mode, write mode */
    regval = io_rd(REG_CSU_PCAP_RESET);
    io_wr(REG_CSU_PCAP_RESET, regval & ~PCAP_RESET_MASK_BIT);

    io_wr(REG_CSU_PCAP_CTRL, PCAP_CTRL_PCAP_PR);
    io_wr(REG_CSU_PCAP_RDWR, 0);

    /* Pulse PROG_B to reset PL */
    io_wr(REG_CSU_PCAP_PROG, 0);
    for (volatile int i = 0; i < 1000; i++);
    io_wr(REG_CSU_PCAP_PROG, PCAP_PROG_PROG_B);

    /* Wait for PL INIT_B to go high */
    timeout = 300000;
    while ((io_rd(REG_CSU_PCAP_STATUS) & PCAP_STS_PL_INIT) == 0 && --timeout > 0);
    if (timeout <= 0) {
        uart_puts("  [PCAP] WARNING: PL INIT timeout\r\n");
        uart_puts("    PCAP_STATUS = 0x");
        uart_hex32(io_rd(REG_CSU_PCAP_STATUS));
        uart_puts("\r\n");
    } else {
        uart_puts("  [PCAP] PL INIT_B high (ready for data)\r\n");
    }

    /* 6. Set stream switch and write mode */
    io_wr(REG_CSU_SSS_CFG, CSU_SSS_SRC_DMA);
    io_wr(REG_CSU_PCAP_RDWR, 0);

    /* 7. Configure CSU DMA SRC channel for .bin format (little-endian) */
    uint32_t word_count = bs_size / 4;
    if (bs_size % 4) word_count++;

    /* Clear endianness bit (little-endian = no byte swap for .bin) */
    regval = io_rd(CSU_DMA_SRC_CTRL);
    io_wr(CSU_DMA_SRC_CTRL, regval & ~CSU_DMA_CTRL_ENDIAN);

    io_wr(CSU_DMA_SRC_ADDR, (uint32_t)bs_addr);
    io_wr(CSU_DMA_SRC_ADDR_MSB, 0);

    /* Writing SIZE register starts the DMA transfer */
    /* Size format: bits[28:2]=word_count, bit0=last_word_flag */
    io_wr(CSU_DMA_SRC_SIZE, (word_count << 2) | 1);

    uart_puts("  [PCAP] DMA started: ");
    uart_dec(word_count);
    uart_puts(" words\r\n");

    /* 8. Wait for CSU DMA done */
    timeout = 5000000;
    while ((io_rd(CSU_DMA_SRC_I_STS) & CSU_DMA_IXR_DONE) == 0 && --timeout > 0);
    if (timeout <= 0) {
        uart_puts("  [PCAP] ERROR: DMA transfer timeout!\r\n");
        uart_puts("    SRC_STS   = 0x");
        uart_hex32(io_rd(CSU_DMA_SRC_STS));
        uart_puts("\r\n");
        uart_puts("    SRC_I_STS = 0x");
        uart_hex32(io_rd(CSU_DMA_SRC_I_STS));
        uart_puts("\r\n");
        return -1;
    }
    /* Clear DMA done interrupt */
    io_wr(CSU_DMA_SRC_I_STS, CSU_DMA_IXR_DONE);
    uart_puts("  [PCAP] DMA transfer complete\r\n");

    /* 9. Wait for PCAP write idle */
    timeout = 300000;
    while ((io_rd(REG_CSU_PCAP_STATUS) & PCAP_STS_WR_IDLE) == 0 && --timeout > 0);

    /* 10. Wait for PL DONE */
    timeout = 5000000;
    while ((io_rd(REG_CSU_PCAP_STATUS) & PCAP_STS_PL_DONE) == 0 && --timeout > 0);
    if (timeout <= 0) {
        uart_puts("  [PCAP] ERROR: PL DONE timeout!\r\n");
        uart_puts("    PCAP_STATUS = 0x");
        uart_hex32(io_rd(REG_CSU_PCAP_STATUS));
        uart_puts("\r\n");
        return -1;
    }
    uart_puts("  [PCAP] PL DONE! Bitstream loaded successfully.\r\n");

    /* 11. Post-config: power-up PL again (removes remaining isolation) */
    io_wr(REG_PMU_PWRUP_EN, PMU_PWR_PL_MASK);
    io_wr(REG_PMU_PWRUP_TRIG, PMU_PWR_PL_MASK);
    timeout = 300000;
    while ((io_rd(REG_PMU_PWRUP_STATUS) & PMU_PWR_PL_MASK) != 0 && --timeout > 0);

    /* Reset PCAP controller */
    regval = io_rd(REG_CSU_PCAP_RESET);
    io_wr(REG_CSU_PCAP_RESET, regval | PCAP_RESET_MASK_BIT);

    uart_puts("  [PCAP] Post-config complete. PL is operational.\r\n");

    /* Stabilization delay */
    for (volatile int i = 0; i < 100000; i++);

    return 0;
}

/* ---- SMC calls for PMUFW FPGA configuration ---- */
/* When running at EL2 (halted from U-Boot), ATF BL31 is alive at EL3.   */
/* SMC traps to EL3 -> ATF -> PMUFW. PMUFW does proper PL power-up,        */
/* bitstream load via PCAP, and PL reset release. No version mismatch.   */

#define BITSTREAM_DATA_ADDR  0x10000000UL
#define BITSTREAM_SIZE_ADDR  0x20000000UL

static inline uint32_t read_current_el(void) {
    uint64_t el;
    __asm__ volatile("mrs %0, CurrentEL" : "=r"(el));
    return (uint32_t)(el >> 2) & 0x3;
}

/* PM_FPGA_LOAD (EEMI API ID 26) via SMC64 SiP fast call */
static inline int32_t pmu_fpga_load(uint64_t addr, uint32_t size, uint32_t flags) {
    register int64_t r0 __asm__("x0") = 0xC200001A;
    register uint64_t r1 __asm__("x1") = (uint32_t)(addr & 0xFFFFFFFF);
    register uint64_t r2 __asm__("x2") = (uint32_t)(addr >> 32);
    register uint64_t r3 __asm__("x3") = size;
    register uint64_t r4 __asm__("x4") = flags;
    __asm__ volatile("smc #0" : "+r"(r0) : "r"(r1), "r"(r2), "r"(r3), "r"(r4)
        : "x5","x6","x7","x8","x9","x10","x11","x12",
          "x13","x14","x15","x16","x17","memory");
    return (int32_t)r0;
}

/* PM_FPGA_GET_STATUS (EEMI API ID 27) */
static inline int32_t pmu_fpga_get_status(void) {
    register int64_t r0 __asm__("x0") = 0xC200001B;
    __asm__ volatile("smc #0" : "+r"(r0) :
        : "x1","x2","x3","x4","x5","x6","x7","x8","x9",
          "x10","x11","x12","x13","x14","x15","x16","x17","memory");
    return (int32_t)r0;
}

/* PM_GET_API_VERSION (EEMI API ID 1) */
static inline int32_t pmu_get_api_version(void) {
    register int64_t r0 __asm__("x0") = 0xC2000001;
    __asm__ volatile("smc #0" : "+r"(r0) :
        : "x1","x2","x3","x4","x5","x6","x7","x8","x9",
          "x10","x11","x12","x13","x14","x15","x16","x17","memory");
    return (int32_t)r0;
}

/* ---- Test Vectors (NIST SP 800-38A, FIPS-197) ---- */

typedef struct {
    const char *name;
    uint32_t key[4];
    uint32_t plaintext[4];
    uint32_t expected[4];
} aes_test_vector_t;

/* Key: 2B7E151628AED2A6ABF7158809CF4F3C */
/* In memory: key[0]=LSW=09CF4F3C, key[1]=ABF71588, key[2]=28AED2A6, key[3]=2B7E1516 */
/* PT[0]=LSW=7393172A, PT[1]=E93D7E11, PT[2]=2E409F96, PT[3]=6BC1BEE2 */
/* CT[0]=LSW=2466EF97, CT[1]=A89ECAF3, CT[2]=0D7A3660, CT[3]=3AD77BB4 */

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

int main(void) {
    int pass_count = 0;
    int total_tests = 0;
    uint32_t ct[4];

    /* Initialize UART0 (FSBL only set up DCC, not physical UART) */
    uart_init();

    /* Read timer frequency (typically 100MHz on ZynqMP) */
    uint64_t timer_freq = read_timer_freq();
    if (timer_freq == 0) timer_freq = 100000000ULL; /* fallback */

    uart_puts("\r\n");
    uart_puts("==============================================\r\n");
    uart_puts("  AES-128 Hardware Accelerator\r\n");
    uart_puts("  Baremetal Test on ZynqMP (KV260)\r\n");
    uart_puts("==============================================\r\n");
    uart_puts("\r\n");

    /* ---- Phase 0: Configure PL ---- */
    uint32_t el = read_current_el();
    uart_puts("--- Phase 0: PL Configuration ---\r\n");
    uart_puts("  Exception Level: EL");
    uart_dec(el);
    uart_puts("\r\n");

#ifdef FSBL_BOOT
    /* FSBL boot mode: PL already configured by FSBL + PMUFW (matching 2025.2) */
    uart_puts("  FSBL boot: PL configured by boot image (FSBL+PMUFW 2025.2)\r\n");
    uart_puts("  PL is powered, configured, and out of reset.\r\n");

    volatile uint32_t pl0_clk = io_rd(0xFF5E00C0U);
    uart_puts("  PL0_REF_CTRL = 0x");
    uart_hex32(pl0_clk);
    uart_puts(" (CLKACT=");
    uart_dec((pl0_clk >> 24) & 1);
    uart_puts(")\r\n");

    /* AXI access test */
    uart_puts("\r\n  --- PL AXI Access Test ---\r\n");
    uart_puts("  Read STATUS (0xA0000024)...\r\n");
    uart_puts("  > BEFORE read\r\n");
    volatile uint32_t pl_test = io_rd(0xA0000024U);
    uart_puts("  > AFTER read = 0x");
    uart_hex32(pl_test);
    uart_puts("\r\n\r\n");

    for (volatile int d = 0; d < 500000; d++);
#else
    if (el == 3) {
        uint32_t bs_size = *(volatile uint32_t *)BITSTREAM_SIZE_ADDR;

        /* Check for JTAG pre-loaded bitstream (magic value 0xDEADBE40) */
        if (bs_size == 0xDEADBE40) {
            uart_puts("  EL3 mode: Bitstream pre-loaded via JTAG fpga command\r\n");
            uart_puts("  Skipping PCAP. PL should be out of reset.\r\n");

            /* Quick PL clock check */
            volatile uint32_t pl0_clk = io_rd(0xFF5E00C0U);
            uart_puts("  PL0_REF_CTRL = 0x");
            uart_hex32(pl0_clk);
            uart_puts(" (CLKACT=");
            uart_dec((pl0_clk >> 24) & 1);
            uart_puts(")\r\n");

            /* Stabilization delay */
            for (volatile int d = 0; d < 500000; d++);

            /* Diagnostic: Test PL AXI access before key load */
            uart_puts("\r\n  --- PL AXI Access Test ---\r\n");
            uart_puts("  Read STATUS (0xA0000024)...\r\n");
            uart_puts("  > BEFORE read\r\n");
            volatile uint32_t pl_test = io_rd(0xA0000024U);
            uart_puts("  > AFTER read = 0x");
            uart_hex32(pl_test);
            uart_puts("\r\n");

            uart_puts("  Write CTRL (0xA0000020 = 0)...\r\n");
            uart_puts("  > BEFORE write\r\n");
            io_wr(0xA0000020U, 0x0U);
            uart_puts("  > AFTER write\r\n");

            uart_puts("  Read STATUS again...\r\n");
            uart_puts("  > BEFORE read\r\n");
            pl_test = io_rd(0xA0000024U);
            uart_puts("  > AFTER read = 0x");
            uart_hex32(pl_test);
            uart_puts("\r\n\r\n");
        } else {
            uart_puts("  EL3 mode: Using direct PCAP programming (bypasses PMUFW)\r\n");

            if (bs_size == 0 || bs_size > 0x10000000) {
                uart_puts("  ERROR: Invalid bitstream size at 0x20000000!\r\n");
                uart_puts("  Stopping.\r\n");
                while (1) __asm__ volatile("wfi");
            }

            int pcap_ret = direct_pcap_load(BITSTREAM_DATA_ADDR, bs_size);
            if (pcap_ret != 0) {
                uart_puts("  ERROR: Direct PCAP load failed!\r\n");
                uart_puts("  Stopping.\r\n");
                while (1) __asm__ volatile("wfi");
            }
            uart_puts("  PL configured. PL is out of reset.\r\n");

            /* PL diagnostics */
            uart_puts("\r\n  --- PL Diagnostics ---\r\n");
            uart_puts("  PCAP_STATUS  = 0x");
            uart_hex32(io_rd(REG_CSU_PCAP_STATUS));
            uart_puts("\r\n");

            volatile uint32_t pl0_clk = io_rd(0xFF5E00C0U);
            uart_puts("  PL0_REF_CTRL = 0x");
            uart_hex32(pl0_clk);
            uart_puts(" (CLKACT=");
            uart_dec((pl0_clk >> 24) & 1);
            uart_puts(")\r\n");

            if (!((pl0_clk >> 24) & 1)) {
                uart_puts("  Enabling PL0 clock...\r\n");
                io_wr(0xFF5E00C0U, pl0_clk | (1U << 24));
            }

            uart_puts("  ISO_STATUS   = 0x");
            uart_hex32(io_rd(REG_PMU_ISO_STATUS));
            uart_puts("\r\n");

            uart_puts("  AXI test read from 0xA0000024 (STATUS)...\r\n");
            uart_puts("  BEFORE read...\r\n");
            volatile uint32_t test_val = io_rd(0xA0000024U);
            uart_puts("  AFTER read = 0x");
            uart_hex32(test_val);
            uart_puts("\r\n");

            for (volatile int d = 0; d < 500000; d++);
        }
    } else {
        /* Diagnostics: Check PMUFW API version */
        int32_t api_ver = pmu_get_api_version();
        uart_puts("  PMUFW API version: 0x");
        uart_hex32((uint32_t)api_ver);
        uart_puts("\r\n");

        /* Check PCAP status before load */
        int32_t pcap_st = pmu_fpga_get_status();
        uart_puts("  PCAP status (before): 0x");
        uart_hex32((uint32_t)pcap_st);
        uart_puts("\r\n");

        uart_puts("  Loading bitstream via SMC to PMUFW...\r\n");
        uint32_t bs_size = *(volatile uint32_t *)BITSTREAM_SIZE_ADDR;
        uart_puts("  Bitstream @0x10000000, size=");
        uart_dec(bs_size);
        uart_puts(" bytes\r\n");

        if (bs_size == 0 || bs_size > 0x10000000) {
            uart_puts("  ERROR: Invalid bitstream size! JTAG may not have written it.\r\n");
            uart_puts("  Stopping.\r\n");
            while (1) __asm__ volatile("wfi");
        }

        int32_t fpga_ret = pmu_fpga_load(BITSTREAM_DATA_ADDR, bs_size, 0);
        uart_puts("  PM_FPGA_LOAD returned: 0x");
        uart_hex32((uint32_t)fpga_ret);
        uart_puts("\r\n");

        if (fpga_ret != 0) {
            uart_puts("  ERROR: FPGA configuration failed!\r\n");
            int32_t st = pmu_fpga_get_status();
            uart_puts("  FPGA status: 0x");
            uart_hex32((uint32_t)st);
            uart_puts("\r\n");
            uart_puts("  Stopping.\r\n");
            while (1) __asm__ volatile("wfi");
        }
        uart_puts("  FPGA configured OK. PL is out of reset.\r\n");

        for (volatile int d = 0; d < 100000; d++);
    }
    uart_puts("\r\n");
#endif /* FSBL_BOOT */

    /* ---- Phase 1: Functional Correctness Test ---- */
    uart_puts("--- Phase 1: Functional Correctness ---\r\n");

    /* Hold AES core in reset before writing key */
    uart_puts("Holding AES core in reset...\r\n");
    aes_hold_reset();

    /* Load key */
    uart_puts("Loading AES-128 key...\r\n");
    aes_load_key(vectors[0].key);

    /* Small delay to ensure key registers are written */
    for (volatile int d = 0; d < 100; d++);

    /* Release AES core from reset so key expansion begins */
    uart_puts("Releasing AES core from reset...\r\n");
    aes_release_reset();

    /* Wait for key expansion */
    int timeout = 0;
    while (!aes_key_ready() && timeout < 100000) timeout++;
    if (!aes_key_ready()) {
        uart_puts("ERROR: Key expansion timeout!\r\n");
        return -1;
    }
    uart_puts("Key expansion complete.\r\n\r\n");

    /* Test each vector with the same key */
    for (int i = 0; i < (int)NUM_TV; i++) {
        /* Load plaintext */
        aes_load_plaintext(vectors[i].plaintext);

        /* Start encryption */
        aes_start();

        /* Wait for valid_out */
        timeout = 0;
        while (!aes_valid_out() && timeout < 10000) timeout++;

        if (timeout >= 10000) {
            uart_puts("  [FAIL] ");
            uart_puts(vectors[i].name);
            uart_puts(" - timeout\r\n");
            continue;
        }

        /* Read ciphertext */
        aes_read_ciphertext(ct);

        /* Deassert valid_in */
        aes_stop();

        /* Small delay for pipeline flush */
        for (volatile int d = 0; d < 100; d++);

        /* Verify */
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
            uart_puts("  [PASS] ");
            uart_puts(vectors[i].name);
            uart_puts("\r\n");
        } else {
            uart_puts("  [FAIL] ");
            uart_puts(vectors[i].name);
            uart_puts("\r\n");
            uart_puts("    Got:      ");
            for (int j = 3; j >= 0; j--) { uart_hex32(ct[j]); uart_puts(" "); }
            uart_puts("\r\n");
            uart_puts("    Expected: ");
            for (int j = 3; j >= 0; j--) { uart_hex32(vectors[i].expected[j]); uart_puts(" "); }
            uart_puts("\r\n");
        }
    }

    uart_puts("\r\nFunctional Test: ");
    uart_dec(pass_count);
    uart_putc('/');
    uart_dec(total_tests);
    uart_puts(" passed\r\n\r\n");

    /* ---- Phase 2: Latency Measurement ---- */
    uart_puts("--- Phase 2: Latency Measurement ---\r\n");

    /* Key already loaded and expanded in Phase 1 */
    uint32_t key[4] = {0x09CF4F3C, 0xABF71588, 0x28AED2A6, 0x2B7E1516};
    uint32_t pt[4]  = {0x7393172A, 0xE93D7E11, 0x2E409F96, 0x6BC1BEE2};

    aes_load_plaintext(pt);

    uint64_t t_start = read_generic_timer();
    aes_start();
    while (!aes_valid_out()) ;
    uint64_t t_end = read_generic_timer();
    aes_read_ciphertext(ct);
    aes_stop();

    uint64_t latency_ticks = t_end - t_start;
    uint32_t latency_ns = (uint32_t)((latency_ticks * 1000000000ULL) / timer_freq);

    uart_puts("  Single-block latency: ");
    uart_dec(latency_ticks);
    uart_puts(" ticks (");
    uart_dec(latency_ns);
    uart_puts(" ns @ ");
    uart_dec((uint32_t)(timer_freq / 1000000));
    uart_puts("MHz)\r\n\r\n");

    /* ---- Phase 3: Throughput Benchmark ---- */
    uart_puts("--- Phase 3: Throughput Benchmark (1000 blocks) ---\r\n");

    #define NUM_BENCH_BLOCKS 1000
    aes_load_plaintext(pt);

    uint64_t bench_start = read_generic_timer();
    for (int b = 0; b < NUM_BENCH_BLOCKS; b++) {
        aes_start();
        while (!aes_valid_out()) ;
        aes_read_ciphertext(ct);
        aes_stop();
        for (volatile int d = 0; d < 20; d++);  /* small gap between blocks */
    }
    uint64_t bench_end = read_generic_timer();

    uint64_t total_ticks = bench_end - bench_start;
    uint64_t ticks_per_block = total_ticks / NUM_BENCH_BLOCKS;
    uint32_t ns_per_block = (uint32_t)((ticks_per_block * 1000000000ULL) / timer_freq);

    uart_puts("  Blocks encrypted: ");
    uart_dec(NUM_BENCH_BLOCKS);
    uart_puts("\r\n");
    uart_puts("  Total time:       ");
    uart_dec((uint32_t)(total_ticks / (timer_freq / 1000000)));  /* microseconds */
    uart_puts(" us\r\n");
    uart_puts("  Time per block:   ");
    uart_dec(ns_per_block);
    uart_puts(" ns\r\n");
    uart_puts("  Throughput:       ");
    if (ns_per_block > 0) {
        uint32_t mbps = (128 * 1000) / ns_per_block;  /* Mbits/sec */
        uart_dec(mbps);
        uart_puts(" Mbps (");
        uart_dec(1000000000 / ns_per_block);
        uart_puts(" blocks/sec)\r\n");
    }
    uart_puts("\r\n");

    /* ---- Summary ---- */
    uart_puts("==============================================\r\n");
    uart_puts("  SUMMARY\r\n");
    uart_puts("==============================================\r\n");
    uart_puts("  Correctness: ");
    uart_dec(pass_count);
    uart_putc('/');
    uart_dec(total_tests);
    uart_puts(" passed\r\n");
    uart_puts("  Latency:     ");
    uart_dec(latency_ns);
    uart_puts(" ns/block\r\n");
    uart_puts("==============================================\r\n");

    /* Halt */
    while (1) {
        __asm__ volatile("wfi");
    }

    return 0;
}
