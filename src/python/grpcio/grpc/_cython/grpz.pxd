from libcpp.string cimport string as std_string
from libcpp.memory cimport unique_ptr
from libcpp.vector cimport vector
cimport grpcpp

ctypedef          size_t    uintptr_t


cdef extern from "grpz/dummy_server.h" namespace "grpz" nogil:
    cppclass DummyServer:
        int Bind(const char* addr) nogil except +

cdef extern from "grpz/server.h" namespace "grpz" nogil:
    cppclass Server:
        void Loop() except +
    cppclass ServerCall:
        void ReadClientMetadata(void(grpcpp.string_ref, grpcpp.string_ref, void*), void* tag) except +
        void Reject() except +
        bint AsyncRead(void(ServerCall*, bint, grpcpp.ByteBuffer, void*), void* user_data) except +
        bint AsyncWrite(void(ServerCall*, bint, void*), const grpcpp.ByteBuffer& buffer, void* user_data) except +
        bint AsyncWriteAndFinish(void(ServerCall*, bint, void*), const grpcpp.ByteBuffer& buffer, void* user_data) except +
        bint AsyncFinish(void(ServerCall*, bint, void*), void* user_data) except +
        void SetDoneCallback(void(ServerCall*, void*), void* user_data) except +

        grpcpp.GenericServerContext& Context() except +

    unique_ptr[Server] BuildAndStartServer(grpcpp.ServerBuilder& builder, void(*)(unique_ptr[ServerCall], void*), void*) except +

cdef extern from "grpz/utility.h" namespace "grpz" nogil:
    void CopyByteBufferToArray(char* destination, const grpcpp.ByteBuffer& buffer)
    void CopyArrayToByteBuffer(grpcpp.ByteBuffer& destination, const char* source, size_t length)
    vector[char] ExtractByteBuffer(const grpcpp.ByteBuffer&)