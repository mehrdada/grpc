from libcpp.memory cimport shared_ptr

cdef extern from "<grpcpp/grpcpp.h>"  namespace "grpc":
    cdef cppclass ServerCredentials "grpc::ServerCredentials":
        pass
    cdef shared_ptr[ServerCredentials] InsecureServerCredentials "grpc::InsecureServerCredentials"() except +
