#include "grpz/dummy_server.h"

namespace grpz {

namespace {
    int kShutdownTag = 1;
}

DummyServer::DummyServer() : 
    server_(grpc_server_create(nullptr, nullptr)), 
    cq_(grpc_completion_queue_create_for_next(nullptr)) {
    grpc_server_register_completion_queue(server_, cq_, nullptr);
}

DummyServer::~DummyServer() {
    grpc_server_shutdown_and_notify(server_, cq_, &kShutdownTag);
    auto event = grpc_completion_queue_next(cq_, gpr_inf_future(GPR_CLOCK_REALTIME), nullptr);
    assert(event.tag == &kShutdownTag);
    grpc_completion_queue_shutdown(cq_);
    grpc_server_destroy(server_);
    grpc_completion_queue_destroy(cq_);
}

int DummyServer::Bind(const char* addr) {
    return grpc_server_add_insecure_http2_port(server_, addr);
}

}