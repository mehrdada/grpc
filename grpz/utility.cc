#include "grpz/utility.h"

#include <iostream>
#include <vector>

namespace grpz {

void CopyByteBufferToArray(char* destination, const grpc::ByteBuffer& buffer) {
    std::vector<grpc::Slice> slices;
    buffer.Dump(&slices);
    char* current = destination;
    for (const auto& slice : slices) {
        size_t size = slice.size();
        if (size > 0) {
            memcpy(current, slice.begin(), size);
            current += size;
        }
    }
}

void CopyArrayToByteBuffer(grpc::ByteBuffer& destination, const char* source, size_t length) {
    grpc::Slice slice(source, length);
    grpc::ByteBuffer buffer(&slice, 1);
    buffer.Swap(&destination);
}

std::vector<char> ExtractByteBuffer(const grpc::ByteBuffer& buffer) {
    std::vector<char> data;
    std::vector<grpc::Slice> slices;

    std::cerr << "buffer: " << buffer.Length() << std::endl;

    buffer.Dump(&slices);
    for (const auto& slice : slices) {
        std::cerr << "slice: " << slice.size() << std::endl;
        std::copy(slice.begin(), slice.end(), std::back_inserter(data));
    }
    return data;
}

}
