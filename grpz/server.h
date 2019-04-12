#ifndef GRPZ_SERVER_H_
#define GRPZ_SERVER_H_
#include <iostream>

#include <mutex>
#include <condition_variable>

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
  ServerCall() {
    std::cerr<<"SERVERCALL::SERVERCALL()"<<std::endl;
    context_.AsyncNotifyWhenDone(&notify_when_done_tag_);
  }
  grpc::GenericServerAsyncReaderWriter& Stream() {
      return stream_;
  }
  grpc::GenericServerContext& Context() {
      return context_;
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
  std::function<void(ServerCall*, void*)> done_callback_ = nullptr;
  bool has_done_callback_ = false;
  void* done_user_data_;
  void SetDoneCallback(std::function<void(ServerCall*, void*)> callback, void* user_data) {
    std::cerr<<"SERVERCALL::SetDoneCallback()"<<std::endl;
    has_done_callback_ = true;
    done_callback_ = std::move(callback);
    done_user_data_ = user_data;
  }
  ~ServerCall() {
    std::cerr << "~SErverCall()" << std::endl;
    std::unique_lock<std::mutex> lock(mu_);
    std::cerr << "~SErverCall(postlock)" << std::endl;
    if (!done_) {
      std::cerr << "~!DONE()" << std::endl;
      done_cv_.wait(lock, [&]{ return done_; });
    }
    std::cerr << "DONE" << std::endl;
  }

  bool AsyncRead(std::function<void(ServerCall*, bool, grpc::ByteBuffer, void*)> callback, void* user_data) {
    std::lock_guard<std::mutex> lock(read_.mu);
    if (read_.pending) {
      return false;
    }
    read_.pending = true;
    read_.callback = std::move(callback);
    read_.user_data = user_data;
    gpr_log(GPR_DEBUG, "read tag: %p", &read_tag_);
    stream_.Read(&read_.msg, &read_tag_);
    return true;
  }

  bool AsyncWrite(std::function<void(ServerCall*, bool, void*)> callback, const grpc::ByteBuffer& buffer, void* user_data) {
    std::lock_guard<std::mutex> lock(write_.mu);
    if (write_.pending) {
      return false;
    }
    write_.pending = true;
    write_.callback = std::move(callback);
    write_.user_data = user_data;
    gpr_log(GPR_DEBUG, "write tag: %p", &write_tag_);
    stream_.Write(buffer, &write_tag_);
    return true;
  }

  bool AsyncWriteAndFinish(std::function<void(ServerCall*, bool, void*)> callback, const grpc::ByteBuffer& buffer, void* user_data) {
    std::lock_guard<std::mutex> lock(write_.mu);
    if (write_.pending) {
      return false;
    }
    write_.pending = true;
    write_.callback = std::move(callback);
    write_.user_data = user_data;
    gpr_log(GPR_DEBUG, "write and finish tag: %p", &write_tag_);
    stream_.WriteAndFinish(buffer, grpc::WriteOptions(), grpc::Status::OK, &write_tag_);
    return true;
  }

  bool AsyncFinish(std::function<void(ServerCall*, bool, void*)> callback, void* user_data) {
    std::lock_guard<std::mutex> lock(write_.mu);
    if (write_.pending) {
      return false;
    }
    write_.pending = true;
    write_.callback = callback;
    write_.user_data = user_data;
    gpr_log(GPR_DEBUG, "finish tag: %p", &write_tag_);
    stream_.Finish(grpc::Status::OK, &write_tag_);
    return true;
  }

  void SetStarted() {
    std::lock_guard<std::mutex> lock(mu_);
    done_ = false;
  }

 private:
  void OnWrite(bool ok) {
    std::unique_lock<std::mutex> lock(write_.mu);
    write_.pending = false;
    auto callback = std::move(write_.callback);
    auto user_data = write_.user_data;
    lock.unlock();
    write_.cv.notify_all();
    std::cerr<< "OnWrite" << std::endl;
    callback(this, ok, user_data);
    std::cerr<< "OnWritedone" << std::endl;
  }

  void OnRead(bool ok) {
    std::unique_lock<std::mutex> lock(read_.mu);
    read_.pending = false;
    auto callback = std::move(read_.callback);
    auto user_data = read_.user_data;
    auto msg = std::move(read_.msg);
    lock.unlock();
    read_.cv.notify_all();
    std::cerr<< "OnRead" << std::endl;
    callback(this, ok, std::move(msg), user_data);
    std::cerr<< "Onreaddone" << std::endl;
  }

  void OnNotifyWhenDone(bool ok) {
    std::cerr << "OnNotifyWhenDone()" << std::endl;
    std::unique_lock<std::mutex> lock(mu_);
    done_ = true;
    done_cv_.notify_all();
    lock.unlock();
    if (has_done_callback_) {
      done_callback_(this, done_user_data_);
    }
  }

  struct {
    std::mutex mu;
    std::condition_variable cv;
    bool pending = false;
    grpc::ByteBuffer msg;
    std::function<void(ServerCall*, bool, grpc::ByteBuffer, void*)> callback;
    void* user_data;
  } read_;

  struct {
    std::mutex mu;
    std::condition_variable cv;
    bool pending = false;
    std::function<void(ServerCall*, bool, void*)> callback;
    void* user_data;
  } write_;

  std::mutex mu_;
  std::condition_variable done_cv_;
  bool done_ = true;
  bool aborting_ = false;

  grpc::GenericServerContext context_;
  grpc::GenericServerAsyncReaderWriter stream_ = grpc::GenericServerAsyncReaderWriter(&context_);
  Tag read_tag_ = Tag([&](bool ok) { OnRead(ok); });
  Tag write_tag_ = Tag([&](bool ok) { OnWrite(ok); });
  Tag notify_when_done_tag_ = Tag([&](bool ok) { OnNotifyWhenDone(ok); });
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

  std::mutex mu_;
  std::condition_variable shut_down_cv_;
  bool shutdown_requested_ = false;
  bool shut_down_ = false;
};

std::unique_ptr<Server> BuildAndStartServer(grpc::ServerBuilder& builder, 
  std::function<void(std::unique_ptr<ServerCall>, void*)> callback, void* tag);

inline void prin() {
  std::cerr << "print()" << std::endl;
}

}

#endif  // GRPZ_SERVER_H_
