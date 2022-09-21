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

/* void arch_disable_cache(uint flags) */
FUNCTION(arch_disable_cache)
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
