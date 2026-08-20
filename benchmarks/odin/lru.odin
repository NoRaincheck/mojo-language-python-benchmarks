// LRU Cache benchmark in Odin
// Ported from the Computer Language Benchmarks Game
// Fixed for current Odin (dev-2026): ^T pointers, builtin map, new/mem.free

package main

import "core:fmt"
import "core:mem"
import "core:os"
import "core:strconv"

LRUNode :: struct {
    key:   i32,
    value: i32,
    prev:  ^LRUNode,
    next:  ^LRUNode,
}

LRUCache :: struct {
    size:   int,
    count:  int,
    head:   ^LRUNode,
    tail:   ^LRUNode,
    lookup: map[i32]^LRUNode,
}

lru_cache_init :: proc(capacity: int) -> LRUCache {
    return LRUCache {
        size   = capacity,
        count  = 0,
        head   = nil,
        tail   = nil,
        lookup = make(map[i32]^LRUNode),
    }
}

lru_cache_drop :: proc(cache: ^LRUCache) {
    delete(cache.lookup)
}

lru_alloc_node :: proc(key: i32, value: i32, alloc: mem.Allocator) -> ^LRUNode {
    node := new(LRUNode, alloc)
    node.key = key
    node.value = value
    node.prev = nil
    node.next = nil
    return node
}

lru_remove :: proc(cache: ^LRUCache, node: ^LRUNode) {
    if cache.head == node { cache.head = node.next }
    if cache.tail == node { cache.tail = node.prev }
    if node.prev != nil { node.prev.next = node.next }
    if node.next != nil { node.next.prev = node.prev }
    node.prev = nil
    node.next = nil
}

lru_add_to_tail :: proc(cache: ^LRUCache, node: ^LRUNode) {
    if cache.head == nil {
        cache.head = node
        node.prev = nil
    } else if cache.tail != nil {
        cache.tail.next = node
        node.prev = cache.tail
    }
    cache.tail = node
    node.next = nil
}

lru_move_to_end :: proc(cache: ^LRUCache, node: ^LRUNode) {
    lru_remove(cache, node)
    lru_add_to_tail(cache, node)
}

lru_get :: proc(cache: ^LRUCache, key: i32) -> i32 {
    if node_ptr, ok := cache.lookup[key]; ok {
        lru_move_to_end(cache, node_ptr)
        return node_ptr.value
    }
    return -1
}

lru_put :: proc(cache: ^LRUCache, key: i32, value: i32, alloc: mem.Allocator) {
    if node_ptr, ok := cache.lookup[key]; ok {
        node_ptr.value = value
        lru_move_to_end(cache, node_ptr)
        return
    } else if cache.count == cache.size {
        if cache.head != nil {
            old := cache.head
            delete_key(&cache.lookup, old.key)
            old.key = key
            old.value = value
            lru_move_to_end(cache, old)
            cache.lookup[old.key] = old
            return
        }
    }
    node := lru_alloc_node(key, value, alloc)
    cache.lookup[key] = node
    lru_add_to_tail(cache, node)
    cache.count += 1
}

lcg_next :: proc(seed: ^i64) -> i64 {
    A := i64(1103515245)
    C := i64(12345)
    M := i64(2147483648)
    seed^ = (A * seed^ + C) % M
    return seed^
}

main :: proc() {
    args := os.args
    size := 100
    n := 500000
    if len(args) > 1 { size = strconv.parse_int(args[1]) or_else 100 }
    if len(args) > 2 { n = strconv.parse_int(args[2]) or_else 500000 }

    alloc := context.allocator
    mod_val := size * 10
    seed0 := i64(0)
    seed1 := i64(1)
    hit := 0
    missed := 0

    cache := lru_cache_init(size)
    defer lru_cache_drop(&cache)

    for i in 0 ..< n {
        seed0 = lcg_next(&seed0)
        k0 := i32(seed0 % i64(mod_val))
        lru_put(&cache, k0, k0, alloc)
        seed1 = lcg_next(&seed1)
        k1 := i32(seed1 % i64(mod_val))
        if lru_get(&cache, k1) == -1 {
            missed += 1
        } else {
            hit += 1
        }
    }

    fmt.printfln("%d", hit)
    fmt.printfln("%d", missed)
}