#include "grpz/server.h"

#include <utility>

#include "absl/memory/memory.h"

namespace grpz {

class Server::PrivateConstructor {};

Server::Server(const PrivateConstructor&, grpc::ServerBuilder& builder,
               std::unique_ptr<grpc::ServerCompletionQueue> cq,
               std::function<void(void*)> callback, void* tag) :
    server_(builder.BuildAndStart()),
    cq_(std::move(cq)),
    callback_(callback),
    tag_(tag) {}

void Server::Stop() {

}

void Server::Loop() {
    
}

Server::~Server(){
    server_->Shutdown();
    cq_->Shutdown();
    void* tag;
    bool ok;
    while (cq_->Next(&tag, &ok));
}

std::unique_ptr<Server> BuildAndStartServer(grpc::ServerBuilder& builder, std::function<void(void*)> callback, void* tag){
    return absl::make_unique<Server>(Server::PrivateConstructor{}, builder, builder.AddCompletionQueue(), callback, tag);
}

}
