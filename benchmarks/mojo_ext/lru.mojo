# LRU cache benchmark as a Python-callable Mojo extension module.
# Exposes two integration patterns:
#   1. compute(size, n)       - PythonObject boundary ("python objects")
#   2. Sim(size).run(n)       - native Mojo struct holding the LRU cache
#                                exposed to Python ("native objects")
# Built with: mojo build --emit shared-lib lru.mojo -o lru.so

from std.os import abort
from std.python import Python, PythonObject
from std.python.bindings import PythonModuleBuilder


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


struct LRUCache(Writable):
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

    def write_to(self, mut writer: Some[Writer]):
        writer.write("LRUCache(size=", self.size, ", count=", self.count, ")")

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


def run_lru(size: Int, n: Int) raises -> Tuple[Int, Int]:
    var cache = LRUCache(size)
    var mod_val = size * 10
    var seed0: Int = 0
    var seed1: Int = 1
    var hit = 0
    var missed = 0
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
    return (hit, missed)


def compute(size: PythonObject, n: PythonObject) raises -> PythonObject:
    var si = Int(py=size)
    var ni = Int(py=n)
    var (hit, missed) = run_lru(si, ni)
    return PythonObject(String(t"{hit}\n{missed}"))


struct Sim(Movable, Writable):
    var cache: LRUCache
    var hit: Int
    var missed: Int

    def __init__(out self, capacity: Int):
        self.cache = LRUCache(capacity)
        self.hit = 0
        self.missed = 0

    def write_to(self, mut writer: Some[Writer]):
        writer.write("Sim(hit=", self.hit, ", missed=", self.missed, ")")

    @staticmethod
    def py_init(out self: Sim, args: PythonObject, kwargs: PythonObject) raises:
        var capacity = Int(py=args[0])
        self = Sim(capacity)

    @staticmethod
    def run(self_ptr: Pointer[Sim, MutAnyOrigin], n: PythonObject) raises -> PythonObject:
        var ni = Int(py=n)
        var mod_val = self_ptr[].cache.size * 10
        var seed0: Int = 0
        var seed1: Int = 1
        for i in range(ni):
            seed0 = lcg_next(seed0)
            var key0 = seed0 % mod_val
            self_ptr[].cache.put(key0, key0)
            seed1 = lcg_next(seed1)
            var key1 = seed1 % mod_val
            if self_ptr[].cache.get(key1) == -1:
                self_ptr[].missed += 1
            else:
                self_ptr[].hit += 1
        return PythonObject(String(t"{self_ptr[].hit}\n{self_ptr[].missed}"))

    @staticmethod
    def put(self_ptr: Pointer[Sim, MutAnyOrigin], key: PythonObject) raises -> PythonObject:
        var k = Int(py=key)
        self_ptr[].cache.put(k, k)
        return Python.none()

    @staticmethod
    def get(self_ptr: Pointer[Sim, MutAnyOrigin], key: PythonObject) raises -> PythonObject:
        return PythonObject(self_ptr[].cache.get(Int(py=key)))


@export
def PyInit_lru() abi("C") -> PythonObject:
    try:
        var m = PythonModuleBuilder("lru")
        m.def_function[compute]("compute")
        _ = (
            m.add_type[Sim]("Sim")
            .def_py_init[Sim.py_init]()
            .def_method[Sim.run]("run")
            .def_method[Sim.put]("put")
            .def_method[Sim.get]("get")
        )
        return m.finalize()
    except e:
        abort(String("failed to create module: ", e))