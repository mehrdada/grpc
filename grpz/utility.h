#ifndef GRPZ_UTILITY_H_
#define GRPZ_UTILITY_H_

#include <vector>

#include "grpcpp/grpcpp.h"

namespace grpz {

void CopyByteBufferToArray(char* destination, const grpc::ByteBuffer& buffer);
void CopyArrayToByteBuffer(grpc::ByteBuffer& destination, const char* source, size_t length);
std::vector<char> ExtractByteBuffer(const grpc::ByteBuffer& buffer);

}

#endif  // GRPZ_UTILITY_H_