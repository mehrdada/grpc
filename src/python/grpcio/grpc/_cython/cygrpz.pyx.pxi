from libcpp.memory cimport make_shared, make_unique
cimport cpython
from cpython cimport PyObject
import threading
import logging
cimport grpcpp

_LOGGER = logging.getLogger(__name__)

import collections
class _HandlerCallDetails(
        collections.namedtuple('_HandlerCallDetails', (
            'method',
            'invocation_metadata',
        ))):
    pass

cdef class _BoundPort:

    def __cinit__(self):
        self._port = make_shared[int]()
        self._final_port = None

    def read_port(self):
        self._final_port = self._port.get()[0]
        self._port.reset()

    def get_port(self):
        return self._final_port


cdef void _read_metadata_item(grpcpp.string_ref key, grpcpp.string_ref val, void* list_ptr) nogil:
    with gil:
        l = <list><PyObject*>list_ptr
        k_bytes = key.data()[:key.length()]
        v_bytes = val.data()[:val.length()]
        l.append((k_bytes, v_bytes))

cdef void _handle_call(unique_ptr[grpz.ServerCall] call, void* user_data) nogil:
    with gil:
        try:
            _LOGGER.error("_handle_call2")
            server_call = _ServerCall()
            _LOGGER.error("_handle_call3")
            running_server = <_RunningServer>user_data
            _LOGGER.error("_handle_call4")
            (<_ServerCall>server_call)._call.swap(call)
            _LOGGER.error("_handle_call5")
            running_server.handle_call(server_call)
        except Exception as ex:
            _LOGGER.exception(ex)

cdef _find_method_handler(handler_call_details, generic_handlers, interceptor_pipeline):

    def query_handlers(handler_call_details):
        for generic_handler in generic_handlers:
            method_handler = generic_handler.service(handler_call_details)
            if method_handler is not None:
                return method_handler
        return None

    if interceptor_pipeline is not None:
        return interceptor_pipeline.execute(query_handlers,
                                            handler_call_details)
    else:
        return query_handlers(handler_call_details)

cdef class _RunningServer:

    def __cinit__(self, handlers, interceptors):
        self._handlers = handlers
        self._interceptor_pipeline = None # _interceptor.service_pipeline(interceptors)

    def loop(self):
        def _loop():
            cdef grpz.Server* server = self._server.get()
            _LOGGER.error('Starting loop')
            with nogil:
                server.Loop()
            _LOGGER.error('stopped loop')
            cpython.Py_DECREF(self)

        self._execution_thread = threading.Thread(target=_loop)
        self._execution_thread.daemon = True
        self._execution_thread.start()

    def stop(self, grace=None):
        with nogil:
            self._server.reset()
        e = threading.Event()
        e.set()
        return e

    def __dealloc__(self):
        with nogil:
            self._server.reset()

    cdef void handle_call(_RunningServer self, _ServerCall call) except *:
        cdef list metadata = []
        _LOGGER.error('handle_call(call')
        call._call.get().ReadClientMetadata(_read_metadata_item, <PyObject*>metadata)
        call._method = call._call.get().Method()
        call._metadata = tuple(metadata)
        method_handler = _find_method_handler(
            _HandlerCallDetails(call._method, call._metadata),
            self._handlers, self._interceptor_pipeline)
        _LOGGER.error('rejecting RPC')
        call.reject()
        return
        if call._method:
            try:
                method_handler = _find_method_handler(rpc_event, generic_handlers,
                                                    interceptor_pipeline)
            except Exception as exception:  # pylint: disable=broad-except
                details = 'Exception servicing handler: {}'.format(exception)
                _LOGGER.exception(details)
                return _reject_rpc(rpc_event, cygrpc.StatusCode.unknown,
                                b'Error in service handler!'), None
            if method_handler is None:
                return _reject_rpc(rpc_event, cygrpc.StatusCode.unimplemented,
                                b'Method not found!'), None
            elif concurrency_exceeded:
                return _reject_rpc(rpc_event, cygrpc.StatusCode.resource_exhausted,
                                b'Concurrent RPC limit exceeded!'), None
            else:
                return _handle_with_method_handler(rpc_event, method_handler,
                                                thread_pool)

cdef class ServerBuilder:

    def __cinit__(self):
        self._bound_ports = []
        self._handlers = []
        self._interceptors = []

    cdef add_port(self, address, shared_ptr[grpcpp.ServerCredentials] creds):
        cdef _BoundPort port = _BoundPort()
        self._bound_ports.append(port)
        self._builder.AddListeningPort(address, creds, port._port.get())
        return port.get_port

    cpdef add_insecure_port(self, address):
        return self.add_port(address, grpcpp.InsecureServerCredentials())

    cpdef add_secure_port(self, address, _ServerCredentialsWrapper credentials):
        return self.add_port(address, credentials.credentials)

    cpdef add_generic_rpc_handlers(self, generic_rpc_handlers):
        for generic_rpc_handler in generic_rpc_handlers:
            service_attribute = getattr(generic_rpc_handler, 'service', None)
            if service_attribute is None:
                raise AttributeError(
                    '"{}" must conform to grpc.GenericRpcHandler type but does '
                    'not have "service" method!'.format(generic_rpc_handler))
        self._handlers.extend(generic_rpc_handlers)

    cpdef add_interceptors(self, interceptors):
        self._interceptors.extend(interceptors)

    cpdef add_option(self, name, value):
        if isinstance(value, int):    
            self._builder.AddIntegerArgument(name, value)
        elif isinstance(value, (bytes, str, unicode)):
            self._builder.AddStringArgument(name, value)
        else:
            raise ValueError('Invalid option type')

    cpdef set_max_concurrent_rpcs(self, int maximum_concurrent_rpcs):
        pass

    cpdef set_submit_handler(self, handler):
        pass

    cpdef set_thread_count(self, int thread_count):
        pass

    cpdef build_and_start(self):
        cdef _RunningServer running_server = _RunningServer(self._handlers, self._interceptors)
        cpython.Py_INCREF(running_server)
        running_server._server.swap(grpz.BuildAndStartServer(self._builder, _handle_call, <PyObject*>running_server))
        for bound_port in self._bound_ports:
            bound_port.read_port()
        self._bound_ports = None
        running_server.loop()
        return running_server

cdef class ServerCompat:

    def __cinit__(self, thread_pool, handlers=None, interceptors=None, options=None, maximum_concurrent_rpcs=None):
        self._dummy_server = make_unique[grpz.DummyServer]()
        self._bound_addrs = []
        self._builder = ServerBuilder()
        self._server = None
        self._builder.add_generic_rpc_handlers(handlers)
        self._builder.add_interceptors(interceptors)
        if options:
            for option, value in options:
                self._builder.add_option(option, value)
        if maximum_concurrent_rpcs:
            self._builder.set_max_concurrent_rpcs(maximum_concurrent_rpcs)
        if thread_pool:
            self._builder.set_submit_handler(thread_pool.submit)
        self._builder.set_thread_count(4)        

    cdef int _add_http2_port(self, address, shared_ptr[grpcpp.ServerCredentials] creds) except *:
        cdef int bound_port = self._dummy_server.get().Bind(address)
        if bound_port <= 0:
            return 0
        adapted_address = '{}:{}'.format(address.rsplit(':', 1)[0], bound_port)
        actual_port_fetcher = self._builder.add_port(adapted_address, creds)
        self._bound_addrs.append((bound_port, actual_port_fetcher))
        return bound_port

    def add_generic_rpc_handlers(self, generic_rpc_handlers):
        self._builder.add_generic_rpc_handlers(generic_rpc_handlers)

    def add_insecure_port(self, address):
        return self._add_http2_port(address, grpcpp.InsecureServerCredentials())        
        
    def add_secure_port(self, address, _ServerCredentialsWrapper server_credentials):
        return self._add_http2_port(address, server_credentials.credentials)

    def start(self):
        self._dummy_server.reset()
        self._server = self._builder.build_and_start()
        for expected, actual in self._bound_addrs:
            actual_val = actual()
            if expected != actual_val:
                raise Exception('Failed to start server: race between dummy server and main server initialization: previously bound port[{}]!=newly bound port[{}]'.format(expected, actual_val))
        _LOGGER.error('start() done')

    def stop(self, grace=None):
        with nogil:
            if self._dummy_server:
                self._dummy_server.reset()
        if self._server:
            return self._server.stop(grace=grace)
        e = threading.Event()
        e.set()
        return e


cdef class _ServerCall:
    cdef void reject(_ServerCall self):
        self._call.get().Reject()