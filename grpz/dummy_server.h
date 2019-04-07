#ifndef GRPZ_DUMMY_SERVER_H_
#define GRPZ_DUMMY_SERVER_H_

#include <grpc/grpc.h>
#include <grpcpp/impl/codegen/grpc_library.h>

namespace grpz {

class DummyServer : private grpc::GrpcLibraryCodegen {
 public:
  DummyServer();
  ~DummyServer();
  int Bind(const char* addr);

 private:
  grpc_server* server_;
};

}

#endif  // GRPZ_DUMMY_SERVER_H_
