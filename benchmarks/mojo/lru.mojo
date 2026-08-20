# LRU cache benchmark in Mojo
# Ported from the Computer Language Benchmarks Game
# Values and output match the fixed Zig/Odin/Python references

from std.sys import argv


struct LRUNode:
    var key: Int
    var value: Int
    var prev: Optional[Pointer[LRUNode, MutUntrackedOrigin]]
    var next: Optional[Pointer[LRUNode, MutUntrackedOrigin]]

    def __init__(out self, key: Int, value: Int):
        self.key = key
        self.value = value
        self.prev = None
        self.next = None


struct LRUCache:
    var size: Int
    var count: Int
    var head: Optional[Pointer[LRUNode, MutUntrackedOrigin]]
    var tail: Optional[Pointer[LRUNode, MutUntrackedOrigin]]
    var lookup: Dict[Int, Pointer[LRUNode, MutUntrackedOrigin]]

    def __init__(out self, capacity: Int):
        self.size = capacity
        self.count = 0
        self.head = None
        self.tail = None
        self.lookup = Dict[Int, Pointer[LRUNode, MutUntrackedOrigin]]()

    def remove(mut self, node: Pointer[LRUNode, MutUntrackedOrigin]):
        if self.head is not None and self.head.value() == node:
            self.head = node[].next
        if self.tail is not None and self.tail.value() == node:
            self.tail = node[].prev
        if node[].prev is not None:
            node[].prev.value()[].next = node[].next
        if node[].next is not None:
            node[].next.value()[].prev = node[].prev
        node[].prev = None
        node[].next = None

    def add_to_tail(mut self, node: Pointer[LRUNode, MutUntrackedOrigin]):
        if self.head is None:
            self.head = node
            node[].prev = None
        elif self.tail is not None:
            self.tail.value()[].next = node
            node[].prev = self.tail
        self.tail = node
        node[].next = None

    def move_to_end(mut self, node: Pointer[LRUNode, MutUntrackedOrigin]):
        self.remove(node)
        self.add_to_tail(node)

    def get(mut self, key: Int) -> Int:
        var opt = self.lookup.get(key)
        if opt is not None:
            var node = opt.value()
            self.move_to_end(node)
            return node[].value
        return -1

    def put(mut self, key: Int, value: Int) raises:
        var opt = self.lookup.get(key)
        if opt is not None:
            var node = opt.value()
            node[].value = value
            self.move_to_end(node)
            return
        elif self.count == self.size:
            if self.head is not None:
                var old = self.head.value()
                self.lookup.pop(old[].key)
                old[].key = key
                old[].value = value
                self.move_to_end(old)
                self.lookup[key] = old
                return
        var node = alloc[LRUNode](1)
        node[].key = key
        node[].value = value
        node[].prev = None
        node[].next = None
        self.lookup[key] = node
        self.add_to_tail(node)
        self.count += 1


def lcg_next(mut seed: Int) -> Int:
    var A: Int = 1103515245
    var C: Int = 12345
    var M: Int = 2147483648
    seed = (A * seed + C) % M
    return seed


def main() raises:
    var size = 100
    var n = 500000
    var a = argv()
    if len(a) > 1:
        size = Int(a[1])
    if len(a) > 2:
        n = Int(a[2])

    var mod_val = size * 10
    var seed0: Int = 0
    var seed1: Int = 1
    var hit = 0
    var missed = 0

    var cache = LRUCache(size)
    for i in range(n):
        seed0 = lcg_next(seed0)
        var key0 = seed0 % mod_val
        cache.put(key0, key0)
        seed1 = lcg_next(seed1)
        var key1 = seed1 % mod_val
        if cache.get(key1) == -1:
            missed += 1
        else:
            hit += 1

    print(hit)
    print(missed)