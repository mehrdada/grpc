#ifndef GRPZ_SERVER_H_
#define GRPZ_SERVER_H_

#include <grpcpp/grpcpp.h>
#include <grpcpp/impl/codegen/grpc_library.h>

namespace grpz {

class PrivateConstructor;

class Server {
 public:
  Server(const PrivateConstructor&, grpc::ServerBuilder& builder, std::unique_ptr<grpc::ServerCompletionQueue> cq);
  ~Server();
 private:
  std::unique_ptr<grpc::Server> server_;
  std::unique_ptr<grpc::ServerCompletionQueue> cq_;
};

std::unique_ptr<Server> BuildAndStartServer(grpc::ServerBuilder& builder);

}

#endif  // GRPZ_SERVER_H_
