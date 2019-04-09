#include "grpz/server.h"

#include <utility>
#include <iostream>
#include "absl/memory/memory.h"

namespace grpz {

class Server::PrivateConstructor {};

Server::Server(const PrivateConstructor&, grpc::ServerBuilder& builder,
               std::unique_ptr<grpc::ServerCompletionQueue> cq,
               std::unique_ptr<grpc::AsyncGenericService> service,
               std::function<void(std::unique_ptr<ServerCall>, void*)> callback, void* tag) :
    server_(builder.BuildAndStart()),
    cq_(std::move(cq)),
    service_(std::move(service)),
    callback_(callback),
    tag_(tag) {}

void Server::Stop() {
    //server_->Shutdown();
}

void Server::NewCall() {
    call_ = absl::make_unique<ServerCall>();
    service_->RequestCall(call_->Context(), call_->Stream(), cq_.get(), cq_.get(), &request_tag_);
}

void Server::Request(bool ok) {
    if (ok) {
        auto call = std::move(call_);
        NewCall();
        // TODO: check if concurrency exceeded before calling back into python
        std::cerr<< "callback_" << std::endl;
        callback_(std::move(call), tag_);
        std::cerr<< "callback_new_" << std::endl;
    }
}

void Server::Loop() {
    NewCall();
    void* tag;
    bool ok;
    while (cq_->Next(&tag, &ok)) {
        if (tag) {
            static_cast<Tag*>(tag)->Handle(ok);
        }
    }
}

Server::~Server(){
    Stop();
    void* tag;
    bool ok;
    while (cq_->Next(&tag, &ok));
    cq_->Shutdown();
}

  std::unique_ptr<Server> BuildAndStartServer(grpc::ServerBuilder& builder, std::function<void(std::unique_ptr<ServerCall>, void*)> callback, void* tag){
    auto service = absl::make_unique<grpc::AsyncGenericService>();
    builder.RegisterAsyncGenericService(service.get());
    return absl::make_unique<Server>(Server::PrivateConstructor{}, 
                                     builder,
                                     builder.AddCompletionQueue(),
                                     std::move(service),
                                     callback, tag);
}

}
