#ifndef GRPZ_SERVER_H_
#define GRPZ_SERVER_H_
#include <iostream>
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
  const std::string& Method() {
    return context_.method();
  }
  void Reject() {
    std::cerr<< "RejecT()"<<std::endl;
    stream_.Finish(grpc::Status::CANCELLED, nullptr);
  }
  void ReadClientMetadata(std::function<void(grpc::string_ref, grpc::string_ref, void*)> reader, void* tag) {
    for (const auto& pair : context_.client_metadata()) {
      reader(pair.first, pair.second, tag);
    }
  }
  ~ServerCall() {
    context_.TryCancel();
  }

 private:
  void Write(bool) {}
  void Read(bool) {}
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
         std::function<void(std::unique_ptr<ServerCall>, void*)> callback, void* tag);
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
  std::function<void(std::unique_ptr<ServerCall>, void*)> callback_;
  void* tag_;
  std::unique_ptr<ServerCall> call_;
};

std::unique_ptr<Server> BuildAndStartServer(grpc::ServerBuilder& builder, 
  std::function<void(std::unique_ptr<ServerCall>, void*)> callback, void* tag);

inline void prin() {
  std::cerr << "print()" << std::endl;
}

}

#endif  // GRPZ_SERVER_H_
