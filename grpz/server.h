#ifndef GRPZ_SERVER_H_
#define GRPZ_SERVER_H_

#include <grpcpp/grpcpp.h>
#include <grpcpp/impl/codegen/grpc_library.h>

namespace grpz {


class Server {
 public:
  class PrivateConstructor;
  Server(const PrivateConstructor&, grpc::ServerBuilder& builder, std::unique_ptr<grpc::ServerCompletionQueue> cq, std::function<void(void*)> callback, void* tag);
  ~Server();
  void Loop();
  void Stop();

 private:
  std::unique_ptr<grpc::Server> server_;
  std::unique_ptr<grpc::ServerCompletionQueue> cq_;
  std::function<void(void*)> callback_;
  void* tag_;
};

std::unique_ptr<Server> BuildAndStartServer(grpc::ServerBuilder& builder, std::function<void(void*)> callback, void* tag);

}

#endif  // GRPZ_SERVER_H_
