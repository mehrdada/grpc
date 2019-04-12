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
    std::cerr << "ServeR::STop()" << std::endl;
    {
        std::lock_guard<std::mutex> lock(mu_);
        if (shutdown_requested_) return;
        shutdown_requested_ = true;
    }
    server_->Shutdown();
    cq_->Shutdown();
}

void Server::NewCall() {
    call_ = absl::make_unique<ServerCall>();
    service_->RequestCall(&call_->Context(), &call_->Stream(), cq_.get(), cq_.get(), &request_tag_);
}

void Server::Request(bool ok) {
    if (ok) {
        auto call = std::move(call_);
        call->SetStarted();
        NewCall();
        // TODO: check if concurrency exceeded before calling back into python
        std::cerr<< "requesT_callback_" << std::endl;
        callback_(std::move(call), tag_);
        std::cerr<< "requesT_callback_done" << std::endl;
    }
}

void Server::Loop() {
    NewCall();
    void* tag;
    bool ok;
    while (cq_->Next(&tag, &ok)) {
        if (tag) {
            gpr_log(GPR_DEBUG, "tag_recevied: %p", tag);
            static_cast<Tag*>(tag)->Handle(ok);
        }
    }
    try {

    std::unique_lock<std::mutex> lock(mu_);
    shut_down_ = true;
    shut_down_cv_.notify_all();
    } catch (std::exception ex) {
        std::cerr<< "xxx"<< std::endl;
    }
}

Server::~Server(){
    Stop();
    call_.reset();
    std::unique_lock<std::mutex> lock(mu_);
    if (!shut_down_) {
        shut_down_cv_.wait(lock, [&] { return shut_down_; });
    }
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
