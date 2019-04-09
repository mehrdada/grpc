# distutils: language = c++

from libcpp.memory cimport shared_ptr, unique_ptr
cimport grpcpp
cimport grpz

cdef class _RunningServer:
    cdef unique_ptr[grpz.Server] _server
    cdef list _handlers
    cdef list _interceptors
    cdef object _execution_thread

cdef class _BoundPort:
    cdef shared_ptr[int] _port
    cdef object _final_port

cdef class ServerBuilder:
    cdef grpcpp.ServerBuilder _builder
    cdef list _bound_ports
    cdef list _handlers
    cdef list _interceptors
    cdef add_port(self, address, shared_ptr[grpcpp.ServerCredentials] creds)
    cpdef add_insecure_port(self, address)
    cpdef add_secure_port(self, address, _ServerCredentialsWrapper credentials)
    cpdef add_generic_rpc_handlers(self, generic_rpc_handlers)
    cpdef add_interceptors(self, interceptors)
    cpdef add_option(self, name, value)
    cpdef set_max_concurrent_rpcs(self, int maximum_concurrent_rpcs)
    cpdef set_submit_handler(self, handler)
    cpdef build_and_start(self)

cdef class ServerCompat:
    cdef unique_ptr[grpz.DummyServer] _dummy_server
    cdef list _bound_addrs
    cdef ServerBuilder _builder
    cdef _RunningServer _server
    cdef int _add_http2_port(self, address, shared_ptr[grpcpp.ServerCredentials] creds) except *

cdef class _ServerCredentialsWrapper:
    cdef shared_ptr[grpcpp.ServerCredentials] credentials
