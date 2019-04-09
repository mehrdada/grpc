# distutils: language = c++

from libcpp.memory cimport shared_ptr, unique_ptr
cimport grpcpp
cimport grpz

cdef class _RunningServer:
    pass

cdef class _BoundPort:
    cdef shared_ptr[int] _port
    cdef object _final_port

cdef class ServerBuilder:
    cdef grpcpp.ServerBuilder _builder
    cdef list _bound_ports
    cdef list _handlers
    cdef list _interceptors
    cdef add_port(self, address, shared_ptr[grpcpp.ServerCredentials] creds)

cdef class ServerCompat:
    cdef unique_ptr[grpz.DummyServer] _dummy_server
    cdef list _bound_addrs
    cdef ServerBuilder _builder
    cdef _RunningServer _server
    cdef int _add_http2_port(self, address, shared_ptr[grpcpp.ServerCredentials] creds) except *

cdef class ServerCredentialsWrapper:
    cdef shared_ptr[grpcpp.ServerCredentials] credentials
