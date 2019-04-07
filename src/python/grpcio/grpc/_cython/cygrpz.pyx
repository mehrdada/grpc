cdef class _BoundPort:

    def __cinit__(self):
        self._port = make_shared[int]()
        self._final_port = None

    cdef void read_port(self):
        self._final_port = self._port.get()[0]
        self._port.reset()

    cdef get_port(self):
        return self._final_port



cdef class ServerBuilder:
    def __cinit__(self):
        self._bound_ports = []
        self._handlers = []

    cdef add_port(self, address, shared_ptr[grpcpp.ServerCredentials] creds):
        cdef _BoundPort port = _BoundPort()
        self._bound_ports.append(port)
        # TODO: add port to builder
        return port.get_port

    def add_insecure_port(self, address):
        return self.add_port(address, grpcpp.InsecureServerCredentials())

    def add_secure_port(self, address, ServerCredentialsWrapper credentials):
        return self.add_port(address, credentials.credentials)

    def add_generic_rpc_handlers(self, generic_rpc_handlers):
        for generic_rpc_handler in generic_rpc_handlers:
            service_attribute = getattr(generic_rpc_handler, 'service', None)
            if service_attribute is None:
                raise AttributeError(
                    '"{}" must conform to grpc.GenericRpcHandler type but does '
                    'not have "service" method!'.format(generic_rpc_handler))
        self._handlers.extend(generic_rpc_handlers)

    def build_and_start(self):
        pass


cdef class ServerCompat:

    def __cinit__(self, thread_pool, handlers=None, interceptors=None, options=None, maximum_concurrent_rpcs=None):
        self._dummy_server = _DummyServer()
        self._bound_addrs = []
        self._builder = ServerBuilder()
        self._server = None

    cdef int _add_http2_port(self, address, shared_ptr[grpcpp.ServerCredentials] creds) except *:
        cdef int bound_port = self._dummy_server.Bind(address)
        if bound_port <= 0:
            return 0
        adapted_address = '{}:{}'.format(address.rsplit(':', 1)[0], bound_port)
        actual_port_fetcher = self._builder.add_port(address, creds)
        self._bound_addrs.append((bound_port, actual_port_fetcher))
        return bound_port

    def add_generic_rpc_handlers(self, generic_rpc_handlers):
        pass

    def add_insecure_port(self, address):
        return self._add_http2_port(address, grpcpp.InsecureServerCredentials())        
        
    def add_secure_port(self, address, ServerCredentialsWrapper server_credentials):
        return self._add_http2_port(address, server_credentials.credentials)

    def start(self):
        #self._dummy_server = None
        self._server = self._builder.build_and_start()
        for expected, actual in self._bound_addrs:
            if expected != actual():
                raise Exception('Bind failure. Race between dummy server and main server initialization')
        pass

    def stop(self, grace):
        pass

