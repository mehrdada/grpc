# Copyright 2017 gRPC authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


cdef class _Tag:

  cdef object event(self, grpc_event c_event):
    raise NotImplementedError()


cdef class _ConnectivityTag(_Tag):

  def __cinit__(self, user_tag):
    self._user_tag = user_tag

  cdef ConnectivityEvent event(self, grpc_event c_event):
    return ConnectivityEvent(c_event.type, c_event.success, self._user_tag)


cdef class _RequestCallTag(_Tag):

  def __cinit__(self, user_tag):
    self._user_tag = user_tag
    self.call = None
    self.call_details = None

  cdef void prepare(self) except *:
    self.call = Call()
    self.call_details = CallDetails()
    grpc_metadata_array_init(&self.c_invocation_metadata)

  cdef RequestCallEvent event(self, grpc_event c_event):
    cdef tuple invocation_metadata = _metadata(&self.c_invocation_metadata)
    grpc_metadata_array_destroy(&self.c_invocation_metadata)
    return RequestCallEvent(
        c_event.type, c_event.success, self._user_tag, self.call,
        self.call_details, invocation_metadata)


cdef class _BatchOperationTag:

  def __cinit__(self, user_tag, operations, call):
    self._user_tag = user_tag
    self._operations = operations
    self._retained_call = call

  cdef void prepare(self) except *:
    self.c_nops = 0 if self._operations is None else len(self._operations)
    if 0 < self.c_nops:
      self.c_ops = <grpc_op *>gpr_malloc(sizeof(grpc_op) * self.c_nops)
      for index, operation in enumerate(self._operations):
        (<Operation>operation).c()
        self.c_ops[index] = (<Operation>operation).c_op

  cdef BatchOperationEvent event(self, grpc_event c_event):
    if 0 < self.c_nops:
      for index, operation in enumerate(self._operations):
        (<Operation>operation).c_op = self.c_ops[index]
        (<Operation>operation).un_c()
      gpr_free(self.c_ops)
      return BatchOperationEvent(
          c_event.type, c_event.success, self._user_tag, self._operations)
    else:
      return BatchOperationEvent(
          c_event.type, c_event.success, self._user_tag, ())

