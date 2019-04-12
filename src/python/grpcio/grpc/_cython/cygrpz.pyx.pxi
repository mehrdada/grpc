from libcpp.memory cimport make_shared, make_unique
from libcpp.vector cimport vector
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

cdef void _unref_call(grpz.ServerCall* call, void* user_data) nogil:
    with gil:
        _LOGGER.error('_unref_call')
        cpython.Py_DECREF(<_ServerCall><PyObject*>user_data)


cdef void _handle_call(unique_ptr[grpz.ServerCall] call, void* user_data) nogil:
    with gil:
        try:
            server_call = _ServerCall()
            cpython.Py_INCREF(server_call)
            call.get().SetDoneCallback(_unref_call, <PyObject*>server_call)
            running_server = <_RunningServer>user_data
            (<_ServerCall>server_call)._call.swap(call)
            _LOGGER.error('_handle_call_in_pool')
            _handle_call_in_pool(running_server, server_call)
        except Exception as exception:
            _LOGGER.exception(exception)

cdef void _handle_call_in_pool(_RunningServer server, _ServerCall call) except *:
    def fn():
        server.handle_call(call)
    server._submit_work(fn)

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


cdef void _handle_with_method_handler(_ServerCall call, method_handler) except *:
    if method_handler.request_streaming:
        if method_handler.response_streaming:
            _handle_stream_stream(call, method_handler)
        else:
            _handle_stream_unary(call, method_handler)
    else:
        if method_handler.response_streaming:
            _handle_unary_stream(call, method_handler)
        else:
            _handle_unary_unary(call, method_handler)

#=====================UnaryUnary===================
cdef class _UnaryUnaryRpc:
    cdef object handler
    cdef object request_deserializer
    cdef object response_serializer

cdef void _handle_unary_unary(_ServerCall call, method_handler) except *:
    cdef _UnaryUnaryRpc rpc = _UnaryUnaryRpc()
    rpc.handler = method_handler.unary_unary
    rpc.request_deserializer = method_handler.request_deserializer
    rpc.response_serializer = method_handler.response_serializer
    def read_request(_ServerCall incoming_call, bint ok, bytes request):
        incoming_call._submit_work(_start_unary_unary_in_pool, rpc, incoming_call, request)
    call.async_read(read_request)

cdef void _start_unary_unary_in_pool(_UnaryUnaryRpc rpc, _ServerCall call, bytes request_message) except *:
    cdef object request
    cdef object response
    cdef object response_message
    if rpc.request_deserializer:
        request = rpc.request_deserializer(request_message)
    else:
        request = request_message
    try:
        response = rpc.handler(request, call)
    except Exception as exception:
        _LOGGER.exception(exception)
    if rpc.response_serializer:
        response_message = rpc.response_serializer(response)
    else:
        response_message = response
    call.async_write_and_finish(response_message, None)


#=====================StreamUnary===================
cdef object _read_single_request(_ServerCall call, object request_deserializer):
    cdef object done_reading = threading.Event()
    cdef object incoming_request = None
    cdef bint incoming_ok = False
    cdef object request 
    def block_till_read(_ServerCall call, bint ok, bytes message):
        nonlocal incoming_request
        nonlocal incoming_ok
        incoming_request = message
        incoming_ok = ok
        done_reading.set()
    _LOGGER.error('reading!!!!!')
    call.async_read(block_till_read)
    _LOGGER.error('waiting!!!!!')
    done_reading.wait()
    if not incoming_ok:
        raise StopIteration()
    if request_deserializer:
        request = request_deserializer(incoming_request)
    else:
        request = incoming_request
    if request:
        return request
    raise StopIteration()

cdef class _StreamUnaryRpc:
    cdef object call
    cdef object request_deserializer
    
    def test(_StreamUnaryRpc self):
        _LOGGER.error('TEST()')

    def __next__(_StreamUnaryRpc self):
        _LOGGER.error("__next__")
        return _read_single_request(self.call, self.request_deserializer)

    def __iter__(_StreamUnaryRpc self):
        return self

cdef void _handle_stream_unary(_ServerCall call, method_handler) except *:
    cdef _StreamUnaryRpc rpc = _StreamUnaryRpc()
    cdef object response_serializer = method_handler.response_serializer
    cdef object response
    cdef object response_message
    rpc.call = call
    rpc.request_deserializer = method_handler.request_deserializer
    _LOGGER.error('STARTING!!!!!')
    response = method_handler.stream_unary(rpc, call)
    _LOGGER.error('ENDIGNG!!!!!')
    if response_serializer:
        response_message = response_serializer(response)
    else:
        response_message = response
    call.async_write_and_finish(response_message, None)


#=====================UnaryStream===================
cdef class _UnaryStreamRpc:
    cdef object handler
    cdef object iterator
    cdef object request_deserializer
    cdef object response_serializer

cdef void _handle_unary_stream(_ServerCall call, method_handler) except *:
    cdef _UnaryStreamRpc rpc = _UnaryStreamRpc()
    rpc.handler = method_handler.unary_stream
    rpc.request_deserializer = method_handler.request_deserializer
    rpc.response_serializer = method_handler.response_serializer
    def read_request(_ServerCall incoming_call, bint ok, bytes request):
        incoming_call._submit_work(_start_unary_stream_in_pool, rpc, incoming_call, request)
    call.async_read(read_request)

cdef void _start_unary_stream_in_pool(_UnaryStreamRpc rpc, _ServerCall call, bytes request) except *:
    cdef object message
    if rpc.request_deserializer:
        message = rpc.request_deserializer(request)
    else:
        message = request
    try:
        rpc.iterator = rpc.handler(message, call)
        _resume_unary_stream_in_pool(rpc, call)
    except Exception as exception:
        _LOGGER.exception(exception)

cdef object _resume_unary_stream(_UnaryStreamRpc self):
    def fn(_ServerCall incoming_call, bint ok):
        if not ok:
            _LOGGER.error('not ok')
            return 
        incoming_call._submit_work(_resume_unary_stream_in_pool, self, incoming_call)
    return fn

cdef void _resume_unary_stream_in_pool(_UnaryStreamRpc rpc, _ServerCall call) except *:
    cdef object response_message
    cdef bytes serialized_response
    _LOGGER.error('resume _resume_unary_stream_in_pool')
    try:
        response_message = next(rpc.iterator)
        if rpc.response_serializer:
            _LOGGER.error(response_message)
            serialized_response = rpc.response_serializer(response_message)
            _LOGGER.error("serialized: {}".format(serialized_response))
        else:
            serialized_response = <bytes>response_message
        call.async_write(serialized_response, _resume_unary_stream(rpc))
    except StopIteration:
        _LOGGER.error('finish')
        call.async_finish(None)
    except Exception as exception:
        _LOGGER.exception(exception)

#=====================StreamStream===================
cdef class _StreamStreamRpc:
    cdef object call
    cdef object iterator
    cdef object request_deserializer
    cdef object response_serializer

    def __next__(_StreamStreamRpc self):
        return _read_single_request(self.call, self.request_deserializer)

    def __iter__(_StreamUnaryRpc self):
        return self

cdef void _handle_stream_stream(_ServerCall call, method_handler) except *:
    cdef _StreamStreamRpc rpc = _StreamStreamRpc()
    rpc.call = call
    rpc.request_deserializer = method_handler.request_deserializer
    rpc.response_serializer = method_handler.response_serializer
    rpc.iterator = method_handler.stream_stream(rpc, call)
    _resume_stream_stream_in_pool(call, rpc)

cdef void _resume_stream_stream_in_pool(_ServerCall call, _StreamStreamRpc rpc):
    cdef object response
    cdef object respones_message
    try:
        response = next(rpc)
    except StopIteration:
        call.async_finish(None)
        return

    if rpc.response_serializer:
        response_message = rpc.response_serializer(response)
    else:
        response_message = response

    if not response_message:
        call.async_finish(None)
        return

    call.async_write(response_message, _resume_stream_stream(rpc))

cdef object _resume_stream_stream(_StreamStreamRpc rpc):
    def fn(_ServerCall incoming_call, bint ok):
        if not ok:
            _LOGGER.error('not ok')
            return 
        incoming_call._submit_work(_resume_stream_stream_in_pool, incoming_call, rpc)
    return fn


cdef class _RunningServer:

    def __cinit__(self, handlers, interceptors, submit_work):
        self._handlers = handlers
        self._interceptor_pipeline = None # _interceptor.service_pipeline(interceptors)
        self._submit_work = submit_work

    def loop(self):
        def _loop():
            with nogil:
                self._server.get().Loop()

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
        call._method = call._call.get().Context().method()
        call._call.get().ReadClientMetadata(_read_metadata_item, <PyObject*>metadata)
        call._metadata = tuple(metadata)
        call._submit_work = self._submit_work
        if call._method:
            try:
                method_handler = _find_method_handler(
                    _HandlerCallDetails(call._method, call._metadata),
                    self._handlers, self._interceptor_pipeline)
            except Exception as exception:  # pylint: disable=broad-except
                details = 'Exception servicing handler: {}'.format(exception)
                _LOGGER.exception(details)
                call.reject(StatusCode.unknown, b'Error in service handler!')
                return

            if method_handler is None:
                _LOGGER.error('handle is none')
                call.reject(StatusCode.unimplemented, b'Method not found!')
            else:
                _LOGGER.error('work submitted')
                call._submit_work(_handle_with_method_handler, call, method_handler)
        else:
            call.reject(StatusCode.unimplemented, b'Bad request: no method specified!')

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
        self._submit_work = handler

    cpdef set_thread_count(self, int thread_count):
        pass

    cpdef build_and_start(self):
        cdef _RunningServer running_server = _RunningServer(self._handlers, self._interceptors, self._submit_work)
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

cdef grpcpp.gpr_timespec _gpr_timespec_from_time(object time):
  cdef grpcpp.gpr_timespec timespec
  if time is None:
    return grpcpp.gpr_inf_future(grpcpp.GPR_CLOCK_REALTIME)
  else:
    timespec.seconds = time
    timespec.nanoseconds = (time - float(timespec.seconds)) * 1e9
    timespec.clock_type = grpcpp.GPR_CLOCK_REALTIME
    return timespec

cdef double _time_from_gpr_timespec(grpcpp.gpr_timespec timespec) except *:
  cdef grpcpp.gpr_timespec real_timespec = grpcpp.gpr_convert_clock_type(
      timespec, grpcpp.GPR_CLOCK_REALTIME)
  return <double>real_timespec.seconds + <double>real_timespec.nanoseconds / 1e9

cdef bytes _extract_buffer(const grpcpp.ByteBuffer& buffer):
    cdef bytes pbytes = cpython.PyBytes_FromStringAndSize(NULL, buffer.Length())
    cdef char* destination = cpython.PyBytes_AsString(pbytes)
    with nogil:
        grpz.CopyByteBufferToArray(destination, buffer)
    return pbytes

cdef void _server_call_on_read(grpz.ServerCall* server_call, bint ok, grpcpp.ByteBuffer buffer, void* user_data) nogil:
    with gil:
        call = <_ServerCall><PyObject*>user_data
        if ok:
            (<_ServerCall>call)._on_read(True, _extract_buffer(buffer))
        else:
            (<_ServerCall>call)._on_read(False, None)

cdef void _server_call_on_write(grpz.ServerCall* server_call, bint ok, void* user_data) nogil:
    with gil:
        call = <_ServerCall><PyObject*>user_data
        (<_ServerCall>call)._on_write(ok)


cdef class _ServerCall:

    def __dealloc__(_ServerCall self):
        if self._call:
            with nogil:
                self._call.reset()

    cdef void reject(_ServerCall self, code, details):
        self._call.get().Reject()

    cdef void async_read(_ServerCall self, continuation) except *:
        cdef PyObject* self_obj = <PyObject*>self
        cdef bint success = False
        self._read_callback = continuation
        cpython.Py_INCREF(self)
        with nogil:
            success = self._call.get().AsyncRead(_server_call_on_read, self_obj)
        if success:
            pass
        else:
            raise Exception('async_read() called while another read is pending')

    cdef void async_write(_ServerCall self, bytes buffer, continuation) except *:
        cdef const char* pbytes = cpython.PyBytes_AsString(buffer)
        cdef grpcpp.ByteBuffer destination
        cdef size_t buf_len = len(buffer)
        with nogil:
            grpz.CopyArrayToByteBuffer(destination, pbytes, buf_len)
        cdef PyObject* self_obj = <PyObject*>self
        cdef bint success = False
        _LOGGER.error("AsyncWrite()")
        self._write_callback = continuation
        cpython.Py_INCREF(self)
        with nogil:
            success = self._call.get().AsyncWrite(_server_call_on_write, destination, self_obj)
        _LOGGER.error("!AsyncWrite()")
        if success:
            #self._write_callback = continuation
            pass
        else:
            raise Exception('async_write() called while another write is pending')

    cdef void async_write_and_finish(_ServerCall self, bytes buffer, continuation) except *:
        cdef const char* pbytes = cpython.PyBytes_AsString(buffer)
        cdef grpcpp.ByteBuffer destination
        cdef size_t buf_len = len(buffer)
        with nogil:
            grpz.CopyArrayToByteBuffer(destination, pbytes, buf_len)
        cdef PyObject* self_obj = <PyObject*>self
        cdef bint success = False
        self._write_callback = continuation
        cpython.Py_INCREF(self)
        with nogil:
            success = self._call.get().AsyncWriteAndFinish(_server_call_on_write, destination, self_obj)
        if success:
            pass
        else:
            raise Exception('async_write_and_finish() called while another write is pending')

    cdef void async_finish(_ServerCall self, continuation) except *:
        cdef PyObject* self_obj = <PyObject*>self
        cdef bint success = False
        self._write_callback = continuation
        cpython.Py_INCREF(self)
        with nogil:
            success = self._call.get().AsyncFinish(_server_call_on_write, self_obj)
        if success:
            pass
        else:
            raise Exception('async_finish() called while another write is pending')

    cdef void _on_read(_ServerCall self, bint ok, bytes message):
        cdef object read_callback = self._read_callback
        cpython.Py_DECREF(self)
        if read_callback:
            self._read_callback = None
            read_callback(self, ok, message)

    cdef void _on_write(_ServerCall self, bint ok):
        cdef object write_callback = self._write_callback
        cpython.Py_DECREF(self)
        if write_callback:
            self._write_callback = None
            write_callback(self, ok)
 
    cpdef invocation_metadata(_ServerCall self):
        return self._metadata

    def peer(self):
        raise NotImplementedError()

    def peer_identities(self):
        raise NotImplementedError()

    def peer_identity_key(self):
        raise NotImplementedError()

    def auth_context(self):
        raise NotImplementedError()

    def send_initial_metadata(self, initial_metadata):
        raise NotImplementedError()

    def set_trailing_metadata(self, trailing_metadata):
        _LOGGER.error('_set_trailing_metdata')

    def abort(self, code, details):
        raise NotImplementedError()

    def abort_with_status(self, status):
        raise NotImplementedError()

    def set_code(self, code):
        raise NotImplementedError()

    def set_details(self, details):
        raise NotImplementedError()

    def is_active(self):
        return True

    def time_remaining(self):
        return max(_time_from_gpr_timespec(self._call.get().Context().raw_deadline()) - time.time(), 0)

    def cancel(self):
        raise NotImplementedError()

    def add_callback(self, callback):
        raise NotImplementedError()
