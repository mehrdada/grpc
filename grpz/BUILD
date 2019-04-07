cc_library(
	name = "grpz",
	hdrs = [
		"server.h",
	],
	srcs = [
		"server.cc",
	],
	visibility = [
		"//:__subpackages__",
	],
	deps = [
		"//:grpc",
		"//:grpc++",
	],
)

cc_library(
	name = "dummy_server",
	hdrs = ["dummy_server.h"],
	srcs = ["dummy_server.cc"],
	visibility = ["//:__subpackages__"],
	deps = [
		"//:grpc",
		"//:grpc++",
	],
)
