from libcpp.memory cimport unique_ptr
cimport grpcpp

cdef extern from "grpz/dummy_server.h" namespace "grpz" nogil:
    cppclass DummyServer:
        int Bind(const char* addr) except +

cdef extern from "grpz/server.h" namespace "grpz" nogil:
    cppclass Server:
        void Loop() except +
    cppclass ServerCall:
        pass
    unique_ptr[Server] BuildAndStartServer(grpcpp.ServerBuilder& builder, void(*callback)(unique_ptr[ServerCall], void*), void*) except +
