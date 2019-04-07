#ifndef GRPZ_SERVER_H_
#define GRPZ_SERVER_H_

#include <grpcpp/grpcpp.h>
#include <grpcpp/impl/codegen/grpc_library.h>

namespace grpz {

class ServerBuilder {
 public:
    ServerBuilder() {}
 private:
    grpc::ServerBuilder builder_;
};

}

#endif  // GRPZ_SERVER_H_
