from libcpp.memory cimport shared_ptr
from libcpp.string cimport string as std_string

ctypedef unsigned char uint8_t
ctypedef int int32_t
ctypedef unsigned uint32_t
ctypedef long long int64_t


cdef extern from "grpcpp/grpcpp.h" namespace "grpc" nogil:
    cppclass ServerCredentials:
        pass
    shared_ptr[ServerCredentials] InsecureServerCredentials() except +
    cppclass ServerBuilder:
        ServerBuilder& AddListeningPort(const std_string& addr_uri, shared_ptr[ServerCredentials] creds, int* selected_port) except +
        ServerBuilder& AddIntegerArgument "AddChannelArgument"(const std_string& name, const int& value)
        ServerBuilder& AddStringArgument "AddChannelArgument"(const std_string& name, const std_string& value)

cdef extern from "grpcpp/impl/codegen/string_ref.h" namespace "grpc" nogil:
    cppclass string_ref:
        const char* data()
        size_t length()

cdef extern from "grpcpp/impl/codegen/byte_buffer.h" namespace "grpc" nogil:
    cppclass ByteBuffer:
        size_t Length()
        void Swap(ByteBuffer* other)

cdef extern from "grpc/grpc.h" nogil:

  ctypedef enum gpr_clock_type:
    GPR_CLOCK_MONOTONIC
    GPR_CLOCK_REALTIME
    GPR_CLOCK_PRECISE
    GPR_TIMESPAN

  ctypedef struct gpr_timespec:
    int64_t seconds "tv_sec"
    int32_t nanoseconds "tv_nsec"
    gpr_clock_type clock_type

  gpr_timespec gpr_time_0(gpr_clock_type type) nogil
  gpr_timespec gpr_inf_future(gpr_clock_type type) nogil
  gpr_timespec gpr_inf_past(gpr_clock_type type) nogil

  gpr_timespec gpr_now(gpr_clock_type clock) nogil

  gpr_timespec gpr_convert_clock_type(gpr_timespec t,
                                      gpr_clock_type target_clock) nogil

  gpr_timespec gpr_time_from_millis(int64_t ms, gpr_clock_type type) nogil

  gpr_timespec gpr_time_add(gpr_timespec a, gpr_timespec b) nogil

  int gpr_time_cmp(gpr_timespec a, gpr_timespec b) nogil



cdef extern from "grpcpp/impl/codegen/async_generic_service.h" namespace "grpc" nogil:
    cppclass GenericServerContext:
        const std_string& method()
        const std_string& host()
        gpr_timespec raw_deadline()