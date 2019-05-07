#include "grpz/server.h"

#include <utility>
#include <iostream>
#include "absl/memory/memory.h"

namespace grpz {

class Server::PrivateConstructor {};

Server::Server(const PrivateConstructor&, grpc::ServerBuilder& builder,
               std::vector<ServerCompletionQueueWatcher> cq_watchers,
               std::unique_ptr<grpc::AsyncGenericService> service,
               std::function<void(std::unique_ptr<ServerCall>, void*)> callback, void* tag) :
    server_(builder.BuildAndStart()),
    cq_watchers_(std::move(cq_watchers_)),
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
    call_.reset();
    server_->Shutdown();
    for (auto& cq_watcher : cq_watchers_) {
        cq_watcher.Shutdown();
    }
}

grpc::ServerCompletionQueue* Server::CompletionQueue() {
    return cq_watchers_[0].CompletionQueue();
}

void Server::NewCall() {
    call_ = absl::make_unique<ServerCall>();
    service_->RequestCall(&call_->Context(), &call_->Stream(), CompletionQueue(), CompletionQueue(), &request_tag_);
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
    std::unique_lock<std::mutex> lock(mu_);
    shut_down_ = true;
    shut_down_cv_.notify_all();
}

Server::~Server(){
    Stop();
    std::unique_lock<std::mutex> lock(mu_);
    if (!shut_down_) {
        shut_down_cv_.wait(lock, [&] { return shut_down_; });
    }
}

std::unique_ptr<Server> BuildAndStartServer(grpc::ServerBuilder& builder, std::function<void(std::unique_ptr<ServerCall>, void*)> callback, void* tag){
    constexpr size_t num_threads = 4;
    auto service = absl::make_unique<grpc::AsyncGenericService>();
    builder.RegisterAsyncGenericService(service.get());
    std::vector<ServerCompletionQueueWatcher> cq_watchers;
    cq_watchers.reserve(num_threads);
    for (size_t i = 0; i < num_threads; ++i) {
        cq_watchers.emplace_back(builder.AddCompletionQueue());
    }
    return absl::make_unique<Server>(Server::PrivateConstructor{}, 
                                     builder,
                                     std::move(cq_watchers),
                                     std::move(service),
                                     callback, tag);
}

}
