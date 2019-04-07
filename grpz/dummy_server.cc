#include "grpz/dummy_server.h"

namespace grpz {

DummyServer::DummyServer() : server_(grpc_server_create(nullptr, nullptr)) {}

DummyServer::~DummyServer() {
    grpc_server_destroy(server_);
}

int DummyServer::Bind(const char* addr) {
    return grpc_server_add_insecure_http2_port(server_, addr);
}

}