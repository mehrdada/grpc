#ifndef GRPZ_SERVER_H_
#define GRPZ_SERVER_H_

#include "grpcpp/grpcpp.h"
#include "grpcpp/impl/codegen/grpc_library.h"
#include "grpcpp/generic/async_generic_service.h"

namespace grpz {


class Tag {
 public:
  explicit Tag(std::function<void(bool)> fn) : fn_(fn) {}
  void Handle(bool ok) {
    fn_(ok);
  }
 private:
  std::function<void(bool)> fn_;
};


class ServerCall {
 public:
  grpc::GenericServerAsyncReaderWriter* Stream() {
      return &stream_;
  }
  grpc::GenericServerContext* Context() {
      return &context_;
  }
  Tag* ReadTag() {
    return &read_tag_;
  }
  Tag* WriteTag() {
    return &write_tag_;
  }

 private:
  void Write(bool) {}
  void Read(bool) {}
  void Request(bool) {}
    grpc::GenericServerContext context_;
    grpc::GenericServerAsyncReaderWriter stream_ = grpc::GenericServerAsyncReaderWriter(&context_);
  Tag read_tag_ = Tag([&](bool ok) { Read(ok); });
  Tag write_tag_ = Tag([&](bool ok) { Write(ok); });
};


class Server {
 public:
  class PrivateConstructor;
  Server(const PrivateConstructor&, grpc::ServerBuilder& builder, 
          std::unique_ptr<grpc::ServerCompletionQueue> cq,
                         std::unique_ptr<grpc::AsyncGenericService> service,
        std::function<void(void*)> callback, void* tag);
  ~Server();
  void Loop();
  void Stop();

 private:
  void Request(bool ok);
  void NewCall();
  Tag request_tag_ = Tag([this](bool ok) { Request(ok); });
  std::unique_ptr<grpc::Server> server_;
  std::unique_ptr<grpc::ServerCompletionQueue> cq_;
                 std::unique_ptr<grpc::AsyncGenericService> service_;
  std::function<void(void*)> callback_;
  void* tag_;
  std::unique_ptr<ServerCall> call_;
};

std::unique_ptr<Server> BuildAndStartServer(grpc::ServerBuilder& builder, std::function<void(void*)> callback, void* tag);

}

#endif  // GRPZ_SERVER_H_
