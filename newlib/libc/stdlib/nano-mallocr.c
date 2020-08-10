/*
 * Copyright (c) 2012, 2013 ARM Ltd
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. The name of the company may not be used to endorse or promote
 *    products derived from this software without specific prior written
 *    permission.
 *
 * THIS SOFTWARE IS PROVIDED BY ARM LTD ``AS IS'' AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL ARM LTD BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 * TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/* Implementation of <<malloc>> <<free>> <<calloc>> <<realloc>>, optional
 * as to be reenterable.
 *
 * Interface documentation refer to malloc.c.
 */

#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <malloc.h>

#if DEBUG
#include <assert.h>
#else
#define assert(x) ((void)0)
#endif

#ifndef MAX
#define MAX(a,b) ((a) >= (b) ? (a) : (b))
#endif

#include <sys/config.h>

#define MALLOC_LOCK __malloc_lock()
#define MALLOC_UNLOCK __malloc_unlock()

#define nano_malloc		malloc
#define nano_free		free
#define nano_realloc	realloc
#define nano_memalign	memalign
#define nano_valloc		valloc
#define nano_pvalloc	pvalloc
#define nano_calloc		calloc
#define nano_cfree		cfree
#define nano_malloc_usable_size malloc_usable_size
#define nano_malloc_stats   malloc_stats
#define nano_mallinfo	mallinfo
#define nano_mallopt	mallopt

/* Redefine names to avoid conflict with user names */
#define free_list __malloc_free_list
#define sbrk_start __malloc_sbrk_start
#define current_mallinfo __malloc_current_mallinfo

#define ALIGN_TO(size, align) \
    (((size) + (align) -1L) & ~((align) -1L))

/* Alignment of allocated block */
#define MALLOC_ALIGN (8U)
#define CHUNK_ALIGN (sizeof(void*))
#define MALLOC_PADDING ((MAX(MALLOC_ALIGN, CHUNK_ALIGN)) - CHUNK_ALIGN)

/* as well as the minimal allocation size
 * to hold a free pointer */
#define MALLOC_MINSIZE (sizeof(void *))
#define MALLOC_PAGE_ALIGN (0x1000)
#define MAX_ALLOC_SIZE (0x80000000U)

typedef size_t malloc_size_t;

// #define MALLOC_DEBUG

typedef struct malloc_chunk
{
#ifdef MALLOC_DEBUG
    void *malloc_backtrace[31];
    int malloc_backtrace_len;
    void *free_backtrace[31];
    int free_backtrace_len;
    struct malloc_chunk *busy;
    int signature;
#endif

    /*          --------------------------------------
     *   chunk->| size                               |
     *          --------------------------------------
     *          | Padding for alignment              |
     *          | This includes padding inserted by  |
     *          | the compiler (to align fields) and |
     *          | explicit padding inserted by this  |
     *          | implementation. If any explicit    |
     *          | padding is being used then the     |
     *          | sizeof (size) bytes at             |
     *          | mem_ptr - CHUNK_OFFSET must be     |
     *          | initialized with the negative      |
     *          | offset to size.                    |
     *          --------------------------------------
     * mem_ptr->| When allocated: data               |
     *          | When freed: pointer to next free   |
     *          | chunk                              |
     *          --------------------------------------
     */
    /* size of the allocated payload area, including size before
       CHUNK_OFFSET */
    long size;

    /* since here, the memory is either the next free block, or data load */
    struct malloc_chunk * next;
}chunk;


#define CHUNK_OFFSET 	offsetof(chunk, next)

/* size of smallest possible chunk. A memory piece smaller than this size
 * won't be able to create a chunk */
#define MALLOC_MINCHUNK (CHUNK_OFFSET + MALLOC_PADDING + MALLOC_MINSIZE)

/* Forward data declarations */
extern chunk * free_list;
extern char * sbrk_start;
extern struct mallinfo current_mallinfo;
#ifdef MALLOC_DEBUG
extern chunk * busy_list;
extern int _in_malloc;
#endif

/* Forward function declarations */
extern void * nano_malloc(malloc_size_t);
extern void nano_free (void * free_p);
extern void nano_cfree(void * ptr);
extern void * nano_calloc(malloc_size_t n, malloc_size_t elem);
extern void nano_malloc_stats(void);
extern malloc_size_t nano_malloc_usable_size(void * ptr);
extern void * nano_realloc(void * ptr, malloc_size_t size);
extern void * nano_memalign(size_t align, size_t s);
extern int nano_mallopt(int parameter_number, int parameter_value);
extern void * nano_valloc(size_t s);
extern void * nano_pvalloc(size_t s);

static inline chunk * get_chunk_from_ptr(void * ptr)
{
    /* Assume that there is no explicit padding in the
       chunk, and that the chunk starts at ptr - CHUNK_OFFSET.  */
    chunk * c = (chunk *)((char *)ptr - CHUNK_OFFSET);

    /* c->size being negative indicates that there is explicit padding in
       the chunk. In which case, c->size is currently the negative offset to
       the true size.  */
    if (c->size < 0) c = (chunk *)((char *)c + c->size);
    return c;
}

extern void  *sbrk(intptr_t);

#ifdef DEFINE_MALLOC
/* List list header of free blocks */
chunk * free_list = NULL;
#ifdef MALLOC_DEBUG
chunk * busy_list = NULL;
int _in_malloc;
int _malloc_test_fail;
#endif

/* Starting point of memory allocated from system */
char * sbrk_start = NULL;

/** Function sbrk_aligned
  * Algorithm:
  *   Use sbrk() to obtain more memory and ensure it is CHUNK_ALIGN aligned
  *   Optimise for the case that it is already aligned - only ask for extra
  *   padding after we know we need it
  */
static void* sbrk_aligned(malloc_size_t s)
{
    char *p, *align_p;

    if (sbrk_start == NULL) sbrk_start = sbrk(0);

    p = sbrk(s);

    /* sbrk returns -1 if fail to allocate */
    if (p == (void *)-1)
        return p;

    align_p = (char*)ALIGN_TO((unsigned long)p, CHUNK_ALIGN);
    if (align_p != p)
    {
        /* p is not aligned, ask for a few more bytes so that we have s
         * bytes reserved from align_p. */
        p = sbrk(align_p - p);
        if (p == (void *)-1)
            return p;
    }
    return align_p;
}

/** Function nano_malloc
  * Algorithm:
  *   Walk through the free list to find the first match. If fails to find
  *   one, call sbrk to allocate a new chunk.
  */
void * nano_malloc(malloc_size_t s)
{
    chunk *p, *r;
    char * ptr, * align_ptr;
    int offset;

#ifdef MALLOC_DEBUG
    if (!_in_malloc) {
	if (_malloc_test_fail && !--_malloc_test_fail)
	    return NULL;
    }
#endif
    malloc_size_t alloc_size;

    alloc_size = ALIGN_TO(s, CHUNK_ALIGN); /* size of aligned data load */
    alloc_size += MALLOC_PADDING; /* padding */
    alloc_size += CHUNK_OFFSET; /* size of chunk head */
    alloc_size = MAX(alloc_size, MALLOC_MINCHUNK);

    if (alloc_size >= MAX_ALLOC_SIZE || alloc_size < s)
    {
        errno = ENOMEM;
        return NULL;
    }

    MALLOC_LOCK;

    p = free_list;
    r = p;

    while (r)
    {
        int rem = r->size - alloc_size;
        if (rem >= 0)
        {
            if (rem >= MALLOC_MINCHUNK)
            {
                /* Find a chunk that much larger than required size, break
                * it into two chunks and return the second one */
                r->size = rem;
                r = (chunk *)((char *)r + rem);
                r->size = alloc_size;
            }
            /* Find a chunk that is exactly the size or slightly bigger
             * than requested size, just return this chunk */
            else if (p == r)
            {
                /* Now it implies p==r==free_list. Move the free_list
                 * to next chunk */
                free_list = r->next;
            }
            else
            {
                /* Normal case. Remove it from free_list */
                p->next = r->next;
            }
            break;
        }
        p=r;
        r=r->next;
    }

    /* Failed to find a appropriate chunk. Ask for more memory */
    if (r == NULL)
    {
        r = sbrk_aligned(alloc_size);

        /* sbrk returns -1 if fail to allocate */
        if (r == (void *)-1)
        {
            errno = ENOMEM;
            MALLOC_UNLOCK;
            return NULL;
        }
        r->size = alloc_size;
    }
    MALLOC_UNLOCK;

    ptr = (char *)r + CHUNK_OFFSET;

    align_ptr = (char *)ALIGN_TO((unsigned long)ptr, MALLOC_ALIGN);
    offset = align_ptr - ptr;

    if (offset)
    {
        /* Initialize sizeof (malloc_chunk.size) bytes at
           align_ptr - CHUNK_OFFSET with negative offset to the
           size field (at the start of the chunk).

           The negative offset to size from align_ptr - CHUNK_OFFSET is
           the size of any remaining padding minus CHUNK_OFFSET.  This is
           equivalent to the total size of the padding, because the size of
           any remaining padding is the total size of the padding minus
           CHUNK_OFFSET.

           Note that the size of the padding must be at least CHUNK_OFFSET.

           The rest of the padding is not initialized.  */
	((chunk *)((char *)align_ptr - CHUNK_OFFSET))->size = -offset;
    }

    assert(align_ptr + size <= (char *)r + alloc_size);
#ifdef MALLOC_DEBUG
    if (_in_malloc++ == 0)
	r->malloc_backtrace_len = backtrace(r->malloc_backtrace, sizeof(r->malloc_backtrace) / sizeof(r->malloc_backtrace[0]));
    else
	r->malloc_backtrace_len = 0;
    r->free_backtrace_len = 0;
    --_in_malloc;
    r->busy = busy_list;
    r->signature = 0xbeeff00d;
    busy_list = r;
#endif

    return align_ptr;
}
#endif /* DEFINE_MALLOC */

#ifdef DEFINE_FREE
#define MALLOC_CHECK_DOUBLE_FREE

/** Function nano_free
  * Implementation of libc free.
  * Algorithm:
  *  Maintain a global free chunk single link list, headed by global
  *  variable free_list.
  *  When free, insert the to-be-freed chunk into free list. The place to
  *  insert should make sure all chunks are sorted by address from low to
  *  high.  Then merge with neighbor chunks if adjacent.
  */
void nano_free (void * free_p)
{
    chunk * p_to_free;
    chunk * p, * q;

    if (free_p == NULL) return;

    p_to_free = get_chunk_from_ptr(free_p);

#ifdef MALLOC_DEBUG
    chunk **prev;

    for (prev = &busy_list; (q = *prev); prev = (&q->busy))
    {
	if (q == p_to_free) {
	    *prev = q->busy;
	    break;
	}
    }
    if (!q || p_to_free->signature != 0xbeeff00d) {
	int i;
	chunk *busy;
	fprintf(stderr, "Free block which is not busy\n");
	for (busy = busy_list; busy; busy = busy->busy) {
	    int i;
	    fprintf(stderr, " 0x%08x %10lu:", (unsigned) (uintptr_t) busy, busy->size);
	    for (i = 0; i < busy->malloc_backtrace_len; i++)
		fprintf(stderr, " 0x%08x", (unsigned) (uintptr_t) busy->malloc_backtrace[i]);
	    fprintf(stderr, "\n");
	}
	fprintf(stderr, " 0x%08x %10lu:", (unsigned) (uintptr_t) p_to_free, p_to_free->size);
	for (i = 0; i < p_to_free->free_backtrace_len; i++)
	    fprintf(stderr, " 0x%08x", (unsigned) (uintptr_t) p_to_free->free_backtrace[i]);
	fprintf(stderr, "\n");
	abort();
    }

    if (_in_malloc++ == 0)
	p_to_free->free_backtrace_len = backtrace(p_to_free->free_backtrace, sizeof(p_to_free->free_backtrace) / sizeof(p_to_free->free_backtrace[0]));
    else
	p_to_free->free_backtrace_len = 0;
    --_in_malloc;
#endif

    MALLOC_LOCK;
    if (free_list == NULL)
    {
        /* Set first free list element */
        p_to_free->next = free_list;
        free_list = p_to_free;
        MALLOC_UNLOCK;
        return;
    }

    if (p_to_free < free_list)
    {
        if ((char *)p_to_free + p_to_free->size == (char *)free_list)
        {
            /* Chunk to free is just before the first element of
             * free list  */
            p_to_free->size += free_list->size;
            p_to_free->next = free_list->next;
        }
        else
        {
            /* Insert before current free_list */
            p_to_free->next = free_list;
        }
        free_list = p_to_free;
        MALLOC_UNLOCK;
        return;
    }

    q = free_list;
    /* Walk through the free list to find the place for insert. */
    do
    {
        p = q;
        q = q->next;
    } while (q && q <= p_to_free);

    /* Now p <= p_to_free and either q == NULL or q > p_to_free
     * Try to merge with chunks immediately before/after it. */

    if ((char *)p + p->size == (char *)p_to_free)
    {
        /* Chunk to be freed is adjacent
         * to a free chunk before it */
        p->size += p_to_free->size;
        /* If the merged chunk is also adjacent
         * to the chunk after it, merge again */
        if ((char *)p + p->size == (char *) q)
        {
            p->size += q->size;
            p->next = q->next;
        }
    }
#ifdef MALLOC_CHECK_DOUBLE_FREE
    else if ((char *)p + p->size > (char *)p_to_free)
    {
        /* Report double free fault */
        errno = ENOMEM;
        MALLOC_UNLOCK;
        return;
    }
#endif
    else if ((char *)p_to_free + p_to_free->size == (char *) q)
    {
        /* Chunk to be freed is adjacent
         * to a free chunk after it */
        p_to_free->size += q->size;
        p_to_free->next = q->next;
        p->next = p_to_free;
    }
    else
    {
        /* Not adjacent to any chunk. Just insert it. Resulting
         * a fragment. */
        p_to_free->next = q;
        p->next = p_to_free;
    }
    MALLOC_UNLOCK;
}
#endif /* DEFINE_FREE */

#ifdef DEFINE_CFREE
void nano_cfree(void * ptr)
{
    nano_free(ptr);
}
#endif /* DEFINE_CFREE */

#ifdef DEFINE_CALLOC
/* Function nano_calloc
 * Implement calloc simply by calling malloc and set zero */
void * nano_calloc(malloc_size_t n, malloc_size_t elem)
{
    ptrdiff_t bytes;
    void * mem;

    if (__builtin_mul_overflow (n, elem, &bytes))
    {
        errno = ENOMEM;
        return NULL;
    }
    mem = nano_malloc(bytes);
    if (mem != NULL) memset(mem, 0, bytes);
    return mem;
}
#endif /* DEFINE_CALLOC */

#ifdef DEFINE_REALLOC
/* Function nano_realloc
 * Implement realloc by malloc + memcpy */
void * nano_realloc(void * ptr, malloc_size_t size)
{
    void * mem;

    if (ptr == NULL) return nano_malloc(size);

    if (size == 0)
    {
        nano_free(ptr);
        return NULL;
    }

#ifdef DEFINE_MALLOC_USABLE_SIZE
    /* TODO: There is chance to shrink the chunk if newly requested
     * size is much small */
    if (nano_malloc_usable_size(ptr) >= size)
      return ptr;
#endif

    mem = nano_malloc(size);
    if (mem != NULL)
    {
        memcpy(mem, ptr, size);
        nano_free(ptr);
    }
    return mem;
}
#endif /* DEFINE_REALLOC */

#ifdef DEFINE_MALLINFO
struct mallinfo current_mallinfo={0,0,0,0,0,0,0,0,0,0};

struct mallinfo nano_mallinfo(void)
{
    char * sbrk_now;
    chunk * pf;
    size_t free_size = 0;
    size_t total_size;

    MALLOC_LOCK;

    if (sbrk_start == NULL) total_size = 0;
    else {
        sbrk_now = sbrk(0);

        if (sbrk_now == (void *)-1)
            total_size = (size_t)-1;
        else
            total_size = (size_t) (sbrk_now - sbrk_start);
    }

    for (pf = free_list; pf; pf = pf->next)
        free_size += pf->size;

    current_mallinfo.arena = total_size;
    current_mallinfo.fordblks = free_size;
    current_mallinfo.uordblks = total_size - free_size;

    MALLOC_UNLOCK;
    return current_mallinfo;
}
#endif /* DEFINE_MALLINFO */

#ifdef DEFINE_MALLOC_STATS
void nano_malloc_stats(void)
{
    nano_mallinfo();
    fprintf(stderr, "max system bytes = %10zu\n",
             current_mallinfo.arena);
    fprintf(stderr, "system bytes     = %10zu\n",
             current_mallinfo.arena);
    fprintf(stderr, "in use bytes     = %10zu\n",
             current_mallinfo.uordblks);
#ifdef MALLOC_DEBUG
    chunk *busy;
    malloc_size_t total_busy = 0;

    for (busy = busy_list; busy; busy = busy->busy) {
	int i;
	total_busy += busy->size;
	fprintf(stderr, " 0x%08x %10zu:", (unsigned) (uintptr_t) busy, busy->size);
	for (i = 0; i < busy->malloc_backtrace_len; i++)
	    fprintf(stderr, " 0x%08x", (unsigned) (uintptr_t) busy->malloc_backtrace[i]);
	fprintf(stderr, "\n");
    }
    fprintf(stderr, "busy  bytes     = %10u\n", total_busy);
#endif
}
#endif /* DEFINE_MALLOC_STATS */

#ifdef DEFINE_MALLOC_USABLE_SIZE
malloc_size_t nano_malloc_usable_size(void * ptr)
{
    chunk * c = (chunk *)((char *)ptr - CHUNK_OFFSET);
    int size_or_offset = c->size;

    if (size_or_offset < 0)
    {
        /* Padding is used. Excluding the padding size */
        c = (chunk *)((char *)c + c->size);
        return c->size - CHUNK_OFFSET + size_or_offset;
    }
    return c->size - CHUNK_OFFSET;
}
#endif /* DEFINE_MALLOC_USABLE_SIZE */

#ifdef DEFINE_MEMALIGN
/* Function nano_memalign
 * Allocate memory block aligned at specific boundary.
 *   align: required alignment. Must be power of 2. Return NULL
 *          if not power of 2. Undefined behavior is bigger than
 *          pointer value range.
 *   s: required size.
 * Return: allocated memory pointer aligned to align
 * Algorithm: Malloc a big enough block, padding pointer to aligned
 *            address, then truncate and free the tail if too big.
 *            Record the offset of align pointer and original pointer
 *            in the padding area.
 */
void * nano_memalign(size_t align, size_t s)
{
    chunk * chunk_p;
    malloc_size_t size_allocated, offset, ma_size, size_with_padding;
    char * allocated, * aligned_p;

    /* Return NULL if align isn't power of 2 */
    if ((align & (align-1)) != 0) return NULL;

    align = MAX(align, MALLOC_ALIGN);
    ma_size = ALIGN_TO(MAX(s, MALLOC_MINSIZE), CHUNK_ALIGN);
    size_with_padding = ma_size + align - MALLOC_ALIGN;

    allocated = nano_malloc(size_with_padding);
    if (allocated == NULL) return NULL;

    chunk_p = get_chunk_from_ptr(allocated);
    aligned_p = (char *)ALIGN_TO(
                  (unsigned long)((char *)chunk_p + CHUNK_OFFSET),
                  (unsigned long)align);
    offset = aligned_p - ((char *)chunk_p + CHUNK_OFFSET);

    if (offset)
    {
        if (offset >= MALLOC_MINCHUNK)
        {
            /* Padding is too large, free it */
            chunk * front_chunk = chunk_p;
            chunk_p = (chunk *)((char *)chunk_p + offset);
            chunk_p->size = front_chunk->size - offset;
            front_chunk->size = offset;
            nano_free((char *)front_chunk + CHUNK_OFFSET);
        }
        else
        {
            /* Padding is used. Need to set a jump offset for aligned pointer
            * to get back to chunk head */
            assert(offset >= sizeof(int));
            *(long *)((char *)chunk_p + offset) = -offset;
        }
    }

    size_allocated = chunk_p->size;
    if ((char *)chunk_p + size_allocated >
         (aligned_p + ma_size + MALLOC_MINCHUNK))
    {
        /* allocated much more than what's required for padding, free
         * tail part */
        chunk * tail_chunk = (chunk *)(aligned_p + ma_size);
        chunk_p->size = aligned_p + ma_size - (char *)chunk_p;
        tail_chunk->size = size_allocated - chunk_p->size;
        nano_free((char *)tail_chunk + CHUNK_OFFSET);
    }
    return aligned_p;
}
#ifdef HAVE_ALIAS_ATTRIBUTE
__strong_reference(memalign, aligned_alloc);
#endif
#endif /* DEFINE_MEMALIGN */

#ifdef DEFINE_MALLOPT
int nano_mallopt(int parameter_number, int parameter_value)
{
    return 0;
}
#endif /* DEFINE_MALLOPT */

#ifdef DEFINE_VALLOC
void * nano_valloc(size_t s)
{
    return nano_memalign(MALLOC_PAGE_ALIGN, s);
}
#endif /* DEFINE_VALLOC */

#ifdef DEFINE_PVALLOC
void * nano_pvalloc(size_t s)
{
    return nano_valloc(ALIGN_TO(s, MALLOC_PAGE_ALIGN));
}
#endif /* DEFINE_PVALLOC */
