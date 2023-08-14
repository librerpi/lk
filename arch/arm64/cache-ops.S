/*
 * Copyright (c) 2014, Google Inc. All rights reserved
 * Copyright 2016 The Fuchsia Authors
 *
 * Use of this source code is governed by a MIT-style
 * license that can be found in the LICENSE file or at
 * https://opensource.org/licenses/MIT
 */

#include <lk/asm.h>
#include <arch/ops.h>
#include <arch/defines.h>
#include <arch/arm64/cache_loop.h>

.text

// Routines to flush the cache by address on the local cpu.
// NOTE: the following routines do not touch the stack and only use x0-x3
// so can be safely called from assembly that is aware of this.

.macro cache_range_op, cache op
    add     x2, x0, x1                  // calculate the end address
    bic     x3, x0, #(CACHE_LINE-1)     // align the start with a cache line
.Lcache_range_op_loop\@:
    \cache  \op, x3
    add     x3, x3, #CACHE_LINE
    cmp     x3, x2
    blo     .Lcache_range_op_loop\@
    dsb     sy
.endm

    /* void arch_flush_cache_range(addr_t start, size_t len); */
FUNCTION(arch_clean_cache_range)
    cache_range_op dc cvac         // clean cache to PoC by MVA
    ret
END_FUNCTION(arch_clean_cache_range)

    /* void arch_flush_invalidate_cache_range(addr_t start, size_t len); */
FUNCTION(arch_clean_invalidate_cache_range)
    cache_range_op dc civac        // clean & invalidate dcache to PoC by MVA
    ret
END_FUNCTION(arch_clean_invalidate_cache_range)

    /* void arch_invalidate_cache_range(addr_t start, size_t len); */
FUNCTION(arch_invalidate_cache_range)
    cache_range_op dc ivac         // invalidate dcache to PoC by MVA
    ret
END_FUNCTION(arch_invalidate_cache_range)

    /* void arch_sync_cache_range(addr_t start, size_t len); */
FUNCTION(arch_sync_cache_range)
    cache_range_op dc cvau         // clean dcache to PoU by MVA
    cache_range_op ic ivau         // invalidate icache to PoU by MVA
    ret
END_FUNCTION(arch_sync_cache_range)

// Below are 3 variants of cache flushing routines by way/set for
// an individual cpu.
// NOTE: does not touch the stack but trashes most of the temporary
// registers.

    // void arm64_local_invalidate_cache_all()
FUNCTION(arm64_local_invalidate_cache_all)
    cache_way_set_op isw, invalidate

    // dump the instruction cache as well
    ic      iallu
    isb

    ret
END_FUNCTION(arm64_local_invalidate_cache_all)

    // void arm64_local_clean_cache_all()
FUNCTION(arm64_local_clean_cache_all)
    cache_way_set_op csw, clean

    // dump the instruction cache as well
    ic      iallu
    isb

    ret
END_FUNCTION(arm64_local_clean_cache_all)

    // void arm64_local_clean_invalidate_cache_all()
FUNCTION(arm64_local_clean_invalidate_cache_all)
    cache_way_set_op cisw, clean_invalidate

    // dump the instruction cache as well
    ic      iallu
    isb

    ret
END_FUNCTION(arm64_local_clean_invalidate_cache_all)

.macro putc c
  ldr x12, =0xffffffffc0201000
  mov x13, #\c
  str x13, [x12]
.endm

/* void arch_disable_cache(uint flags) */
FUNCTION(arch_disable_cache)
  // LK runs in EL1

  /* Disable iCache and dCache */
.inEL1:
  mrs x4, sctlr_el1
  bic x4, x4, #(1 << 12) // Disable iCache
  bic x4, x4, #(1 << 2)  // Disable dCache
  msr sctlr_el1, x4
  isb

  /* Clean and Invalidate dCache */
  mrs x0, CLIDR_EL1
  and w3, w0, #0x07000000     // Bits: 26:24 Level of Coherence
  lsr w3, w3, #23             // Store 2 x LoC in W3
  cbz w3, Finished            // If 0, we are done
  mov w10, #0                 // store 2x cache level (since csselr starts at bit 1)
  mov w8, #1

Loop1:
  //putc 'a'
  add w2, w10, w10, lsr #1    // Calculate 3x cache level a(w10 + 2w10 = 3w10)
  lsr w1, w0, w2              // read cType (cache type)
  and w1, w1, #0x7            // mask 3-bits
  cmp w1, #2                  // types >=2 include data cache
  b.lt Skip                   // skip if no data cache implemented

  msr csselr_el1, x10         // select the cache level
  isb                         // sync
  mrs x1, ccsidr_el1          // read ccsidr (current cache size id)
  and w2, w1, #0x7            // w2 = log2(linesize) - 4
  add w2, w2, #4              // w2 = log2(linesize)
  ubfx w4, w1, #3, #10        // w4 = way number (associativity)
  clz w5, w4                  // w5 = 32 - log2(ways), bit pos in dc operand
  lsl w9, w4, w5              // w9 = max way number, aligned to position in dc operand
  lsl w16, w8, w5             // w16 = amount to decrement way number per iteration
Loop2:
  //putc 'b'
  ubfx w7, w1, #13, #15       // w7 = max set number
  lsl w7, w7, w2              // w7= max set number, aligned to position in dc operand
  lsl w17, w8, w2             // w17 = amount to decrement set number per iteration
Loop3:
  //putc 'c'
  orr w11, w10, w9            // w11 = combine way number, cache number and set num for dc operand
  orr w11, w11, w7
  dc cisw, x11                 // perform clean by set and way
  subs w7, w7, w17            // decrement set number
  b.ge Loop3
  subs x9, x9, x16            // decrement way number
  b.ge Loop2
Skip:
  //putc 'd'
  add w10, w10, #2
  cmp w3, w10
  dsb sy
  b.gt Loop1
Finished:
  //putc 'e'
  /* invalidate iCache*/
  ic ialluis
  isb
  //putc 'f'

  /* invalidate TLB */
  tlbi vmalle1
  dsb sy
  isb
  //putc 'g'
  ret
FUNCTION(arch_disable_cache_unfinished)
  putc 'a'
  mov     x7, x0                      // save flags
  mrs     x8, daif                    // save the old interrupt state
  msr daifset, #2                     // interrupts disabled
.Ldcache_disable:
  tst     x7, #DCACHE
  beq     .Licache_disable
  mrs     x0, sctlr_el1
  tst     x0, #(1<<2)                 // is the dcache already disabled?
  beq     .Ldcache_already_disabled

  bic     x0, x0, #(1<<2)
  msr     sctlr_el1, x0
  // flush and invalidate the dcache
  bl      arm64_local_clean_invalidate_cache_all
  b       .Ldcache_disable_L2

.Ldcache_already_disabled:
  bl      invalidate_cache

.Ldcache_disable_L2:
.Licache_disable:
  tst     x7, #ICACHE
  beq     .Ldone_disable

  mrs     x0, sctlr_el1
  bic     x0, x0, #(1<<12)
  msr     sctlr_el1, x0

.Ldone_disable:
  // make sure the icache is always invalidated
  ic iallu  // instruction cache invalid all to PoU

  msr     daif, x8            // restore irq flags

  ret

invalidate_cache:
  dmb     ishst
  mrs     x0, clidr_el1

  b .
literals:
.ltorg
