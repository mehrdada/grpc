from libcpp.string cimport string as std_string
from libcpp.memory cimport unique_ptr
cimport grpcpp

cdef extern from "grpz/dummy_server.h" namespace "grpz" nogil:
    cppclass DummyServer:
        int Bind(const char* addr) nogil except +

cdef extern from "grpz/server.h" namespace "grpz" nogil:
    cppclass Server:
        void Loop() except +
    cppclass ServerCall:
        const std_string& Method() except +
        void ReadClientMetadata(void(grpcpp.string_ref, grpcpp.string_ref, void*), void* tag) except +
        void Reject() except +
    unique_ptr[Server] BuildAndStartServer(grpcpp.ServerBuilder& builder, void(*)(unique_ptr[ServerCall], void*), void*) except +
