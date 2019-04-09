from libcpp.memory cimport shared_ptr
from libcpp.string cimport string as std_string

cdef extern from "grpcpp/grpcpp.h" namespace "grpc" nogil:
    cppclass ServerCredentials:
        pass
    shared_ptr[ServerCredentials] InsecureServerCredentials() except +
    cppclass ServerBuilder:
        ServerBuilder& AddListeningPort(const std_string& addr_uri, shared_ptr[ServerCredentials] creds, int* selected_port) except +
        ServerBuilder& AddIntegerArgument "AddChannelArgument"(const std_string& name, const int& value)
        ServerBuilder& AddStringArgument "AddChannelArgument"(const std_string& name, const std_string& value)
