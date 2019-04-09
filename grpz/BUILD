cc_library(
	name = "grpz",
	hdrs = [
		"channel.h",
		"server.h",
	],
	srcs = [
		"channel.cc",
		"server.cc",
	],
	visibility = [
		"//:__subpackages__",
	],
	deps = [
		"//:grpc",
		"//:grpc++",
        "@com_google_absl//absl/memory:memory",
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
