# distutils: language = c++

from libcpp.memory cimport shared_ptr, unique_ptr
cimport grpcpp
cimport grpz

cdef class Server:
    pass

cdef class _ServerCall:
    cdef unique_ptr[grpz.ServerCall] _call
    cdef object _submit_work
    cdef bytes _method
    cdef tuple _metadata
    cdef object _read_callback
    cdef object _write_callback
    cdef void reject(_ServerCall self, code, details)
    cdef void async_read(_ServerCall self, continuation) except *
    cdef void async_write(_ServerCall self, bytes buffer, continuation) except *
    cdef void async_write_and_finish(_ServerCall self, bytes buffer, continuation) except *
    cdef void async_finish(_ServerCall self, continuation) except *
    cdef void _on_read(_ServerCall self, bint ok, bytes message)
    cdef void _on_write(_ServerCall self, bint ok)
    cpdef invocation_metadata(_ServerCall self)

cdef class _RunningServer:
    cdef unique_ptr[grpz.Server] _server
    cdef list _handlers
    cdef object _interceptor_pipeline
    cdef object _execution_thread
    cdef object _submit_work
    cdef void handle_call(_RunningServer self, _ServerCall call) except *

cdef class _BoundPort:
    cdef shared_ptr[int] _port
    cdef object _final_port

cdef class ServerBuilder:
    cdef grpcpp.ServerBuilder _builder
    cdef list _bound_ports
    cdef list _handlers
    cdef list _interceptors
    cdef object _submit_work
    cdef add_port(self, address, shared_ptr[grpcpp.ServerCredentials] creds)
    cpdef add_insecure_port(self, address)
    cpdef add_secure_port(self, address, _ServerCredentialsWrapper credentials)
    cpdef add_generic_rpc_handlers(self, generic_rpc_handlers)
    cpdef add_interceptors(self, interceptors)
    cpdef add_option(self, name, value)
    cpdef set_max_concurrent_rpcs(self, int maximum_concurrent_rpcs)
    cpdef set_submit_handler(self, handler)
    cpdef set_thread_count(self, int thread_count)
    cpdef build_and_start(self)

cdef class ServerCompat:
    cdef unique_ptr[grpz.DummyServer] _dummy_server
    cdef list _bound_addrs
    cdef ServerBuilder _builder
    cdef _RunningServer _server
    cdef int _add_http2_port(self, address, shared_ptr[grpcpp.ServerCredentials] creds) except *

cdef class _ServerCredentialsWrapper:
    cdef shared_ptr[grpcpp.ServerCredentials] credentials
