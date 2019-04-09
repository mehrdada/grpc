#include "grpz/server.h"

#include <utility>

#include "absl/memory/memory.h"

namespace grpz {

class PrivateConstructor {};

Server::Server(const PrivateConstructor&, grpc::ServerBuilder& builder, std::unique_ptr<grpc::ServerCompletionQueue> cq) : server_(builder.BuildAndStart()), cq_(std::move(cq)){
}

Server::~Server(){
    server_->Shutdown();
    cq_->Shutdown();
    void* tag;
    bool ok;
    while (cq_->Next(&tag, &ok));
}

std::unique_ptr<Server> BuildAndStartServer(grpc::ServerBuilder& builder) {
    return absl::make_unique<Server>(PrivateConstructor{}, builder, builder.AddCompletionQueue());
}

}
