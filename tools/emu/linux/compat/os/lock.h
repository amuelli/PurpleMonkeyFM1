/* SPDX-License-Identifier: GPL-3.0-only */
/* <os/lock.h> for the Linux build (tools/emu/build_pm.sh): macOS's os_unfair_lock as a pthread mutex. It lends no
 * priority to its holder; the headless runs are single-threaded and never wait for it. */
#pragma once
#include <pthread.h>
typedef pthread_mutex_t os_unfair_lock;
#define OS_UNFAIR_LOCK_INIT PTHREAD_MUTEX_INITIALIZER
static inline void os_unfair_lock_lock(os_unfair_lock *l) { pthread_mutex_lock(l); }
static inline void os_unfair_lock_unlock(os_unfair_lock *l) { pthread_mutex_unlock(l); }
static inline _Bool os_unfair_lock_trylock(os_unfair_lock *l) { return pthread_mutex_trylock(l) == 0; }
