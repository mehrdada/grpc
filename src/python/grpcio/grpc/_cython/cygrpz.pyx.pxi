from libcpp.memory cimport make_shared, make_unique

cdef class _BoundPort:

    def __cinit__(self):
        self._port = make_shared[int]()
        self._final_port = None

    def read_port(self):
        self._final_port = self._port.get()[0]
        self._port.reset()

    def get_port(self):
        return self._final_port

cdef class _RunningServer:
    pass

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

    def add_interceptors(self, interceptors):
        self._interceptors.extend(interceptors)

    def add_option(self, name, value):
        if isinstance(value, int):    
            self._builder.AddIntegerArgument(name, value)
        elif isinstance(value, (bytes, str, unicode)):
            self._builder.AddStringArgument(name, value)
        else:
            raise ValueError('Invalid option type')

    def build_and_start(self):
        grpz.BuildAndStartServer(self._builder)
        for bound_port in self._bound_ports:
            bound_port.read_port()
        self._bound_ports = None

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
        
    def add_secure_port(self, address, ServerCredentialsWrapper server_credentials):
        return self._add_http2_port(address, server_credentials.credentials)

    def start(self):
        self._dummy_server.reset()
        self._server = self._builder.build_and_start()
        for expected, actual in self._bound_addrs:
            actual_val = actual()
            if expected != actual_val:
                raise Exception('Failed to start server: race between dummy server and main server initialization: previously bound port[{}]!=newly bound port[{}]'.format(expected, actual_val))
        self._server.run()

    def stop(self, grace):
        if self._dummy_server:
            self._dummy_server.reset()

