# distutils: language = c++

from libcpp.memory cimport shared_ptr, unique_ptr
cimport grpcpp

cdef extern from "grpz/dummy_server.h" namespace "grpz":
    cdef cppclass _DummyServer "grpz::DummyServer":
        _DummyServer() except +
        int Bind(const char* addr) except +


cdef class _Server:
    pass

cdef class _BoundPort:
    cdef shared_ptr[int] _port
    cdef object _final_port
    cdef void read_port(self)
    cdef get_port(self)

cdef class ServerBuilder:
    cdef list _bound_ports
    cdef list _handlers
    cdef add_port(self, address, shared_ptr[grpcpp.ServerCredentials] creds)

cdef class ServerCompat:
    cdef unique_ptr[_DummyServer] _dummy_server
    cdef list _bound_addrs
    cdef ServerBuilder _builder
    cdef Server _server
    cdef int _add_http2_port(self, address, shared_ptr[grpcpp.ServerCredentials] creds) except *

cdef class ServerCredentialsWrapper:
    cdef shared_ptr[grpcpp.ServerCredentials] credentials
