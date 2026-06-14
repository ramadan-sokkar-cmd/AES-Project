/*
 * ============================================================================
 * AES-128 Hardware Accelerator Driver
 * AXI4-Lite Register Interface Definitions
 * ============================================================================
 *
 * AES IP Base Address: 0xA000_0000 (auto-assigned by Vivado)
 *
 * Register Map (all registers 32-bit, word-aligned):
 *
 *   Offset  Reg      Dir  Field
 *   ------  -------- ---  ---------------------------------
 *   0x00    DATA_IN0  W   Plaintext [31:0]    (LSW)
 *   0x04    DATA_IN1  W   Plaintext [63:32]
 *   0x08    DATA_IN2  W   Plaintext [95:64]
 *   0x0C    DATA_IN3  W   Plaintext [127:96]  (MSW)
 *   0x10    KEY_IN0   W   Key [31:0]          (LSW)
 *   0x14    KEY_IN1   W   Key [63:32]
 *   0x18    KEY_IN2   W   Key [95:64]
 *   0x1C    KEY_IN3   W   Key [127:96]        (MSW)
 *   0x20    CTRL      W   Bit 0: valid_in (start encryption)
 *   0x24    STATUS    R   Bit 0: valid_out, Bit 1: key_ready
 *   0x28    DATA_OUT0 R   Ciphertext [31:0]   (LSW)
 *   0x2C    DATA_OUT1 R   Ciphertext [63:32]
 *   0x30    DATA_OUT2 R   Ciphertext [95:64]
 *   0x34    DATA_OUT3 R   Ciphertext [127:96] (MSW)
 *
 * Usage sequence:
 *   1. Write KEY (4 words)
 *   2. Wait for key_ready (poll STATUS bit 1)
 *   3. Write DATA_IN (4 words)
 *   4. Write 1 to CTRL (valid_in)
 *   5. Wait for valid_out (poll STATUS bit 0)
 *   6. Read DATA_OUT (4 words)
 * ============================================================================
 */
#ifndef AES_HW_H
#define AES_HW_H

/* Register offsets */
#define AES_REG_DATA_IN0   0x00
#define AES_REG_DATA_IN1   0x04
#define AES_REG_DATA_IN2   0x08
#define AES_REG_DATA_IN3   0x0C
#define AES_REG_KEY_IN0    0x10
#define AES_REG_KEY_IN1    0x14
#define AES_REG_KEY_IN2    0x18
#define AES_REG_KEY_IN3    0x1C
#define AES_REG_CTRL       0x20
#define AES_REG_STATUS     0x24
#define AES_REG_DATA_OUT0  0x28
#define AES_REG_DATA_OUT1  0x2C
#define AES_REG_DATA_OUT2  0x30
#define AES_REG_DATA_OUT3  0x34

/* CTRL register bits */
#define AES_CTRL_VALID_IN  0x1   /* Bit 0: valid_in (start encryption)  */
#define AES_CTRL_RST_N     0x2   /* Bit 1: AES core reset (1=run, 0=reset) */

/* Status bits */
#define AES_STATUS_VALID_OUT  0x1
#define AES_STATUS_KEY_READY  0x2

/* Base address (Vivado auto-assigned) */
#define AES_BASE_ADDR  0xA0000000UL

/* ===========================================================================
 * Abstract I/O layer — overridden by platform-specific code
 * =========================================================================== */
#ifdef __BAREMETAL__
  /* Baremetal: direct memory-mapped I/O */
  #include <stdint.h>
  static inline void aes_write32(uint32_t offset, uint32_t val) {
      *(volatile uint32_t *)(AES_BASE_ADDR + offset) = val;
  }
  static inline uint32_t aes_read32(uint32_t offset) {
      return *(volatile uint32_t *)(AES_BASE_ADDR + offset);
  }
#else
  /* Linux: uses /dev/mem mapping (see aes_linux.c) */
  #include <stdint.h>
  extern volatile uint8_t *aes_base;
  static inline void aes_write32(uint32_t offset, uint32_t val) {
      *(volatile uint32_t *)(aes_base + offset) = val;
  }
  static inline uint32_t aes_read32(uint32_t offset) {
      return *(volatile uint32_t *)(aes_base + offset);
  }
#endif

/* ===========================================================================
 * High-level AES driver functions
 * =========================================================================== */

/*
 * Load the 128-bit key into the AES accelerator.
 * key[0] = LSW ... key[3] = MSW
 */
static inline void aes_load_key(const uint32_t key[4]) {
    aes_write32(AES_REG_KEY_IN0, key[0]);
    aes_write32(AES_REG_KEY_IN1, key[1]);
    aes_write32(AES_REG_KEY_IN2, key[2]);
    aes_write32(AES_REG_KEY_IN3, key[3]);
}

/*
 * Load 128-bit plaintext into the AES accelerator.
 * pt[0] = LSW ... pt[3] = MSW
 */
static inline void aes_load_plaintext(const uint32_t pt[4]) {
    aes_write32(AES_REG_DATA_IN0, pt[0]);
    aes_write32(AES_REG_DATA_IN1, pt[1]);
    aes_write32(AES_REG_DATA_IN2, pt[2]);
    aes_write32(AES_REG_DATA_IN3, pt[3]);
}

/*
 * Assert valid_in to start the pipeline.
 */
static inline void aes_start(void) {
    aes_write32(AES_REG_CTRL, AES_CTRL_RST_N | AES_CTRL_VALID_IN);
}

/*
 * Deassert valid_in (keep AES core out of reset).
 */
static inline void aes_stop(void) {
    aes_write32(AES_REG_CTRL, AES_CTRL_RST_N);
}

/*
 * Hold AES core in reset (key expansion halted, pipeline flushed).
 * Must be called BEFORE writing key to ensure expansion picks up the new key.
 */
static inline void aes_hold_reset(void) {
    aes_write32(AES_REG_CTRL, 0x0);
}

/*
 * Release AES core from reset so key expansion begins.
 * Key registers must already be written.
 */
static inline void aes_release_reset(void) {
    aes_write32(AES_REG_CTRL, AES_CTRL_RST_N);
}

/*
 * Check if key expansion is complete.
 */
static inline int aes_key_ready(void) {
    return (aes_read32(AES_REG_STATUS) & AES_STATUS_KEY_READY) != 0;
}

/*
 * Check if ciphertext is available.
 */
static inline int aes_valid_out(void) {
    return (aes_read32(AES_REG_STATUS) & AES_STATUS_VALID_OUT) != 0;
}

/*
 * Read 128-bit ciphertext from the AES accelerator.
 * ct[0] = LSW ... ct[3] = MSW
 */
static inline void aes_read_ciphertext(uint32_t ct[4]) {
    ct[0] = aes_read32(AES_REG_DATA_OUT0);
    ct[1] = aes_read32(AES_REG_DATA_OUT1);
    ct[2] = aes_read32(AES_REG_DATA_OUT2);
    ct[3] = aes_read32(AES_REG_DATA_OUT3);
}

#endif /* AES_HW_H */
