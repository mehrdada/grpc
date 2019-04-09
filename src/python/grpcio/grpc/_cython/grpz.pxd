from libcpp.memory cimport unique_ptr
cimport grpcpp

cdef extern from "grpz/dummy_server.h" namespace "grpz" nogil:
    cppclass DummyServer:
        int Bind(const char* addr) except +

cdef extern from "grpz/server.h" namespace "grpz" nogil:
    cppclass Server:
        void Loop() except +
    unique_ptr[Server] BuildAndStartServer(grpcpp.ServerBuilder& builder, void(*callback)(void*), void*) except +
