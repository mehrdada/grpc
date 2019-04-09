cimport grpcpp

cdef extern from "grpz/dummy_server.h" namespace "grpz" nogil:
    cppclass DummyServer:
        int Bind(const char* addr) except +

from libcpp.memory import unique_ptr as std_unique_ptr

cdef extern from "grpz/server.h" namespace "grpz" nogil:
    cppclass Server:
        pass
    void BuildAndStartServer(grpcpp.ServerBuilder& builder) except +
