import os

env = Environment(
	tools=["default", "os"],
	CXXFLAGS=["-fobjc-arc"],
	LINKFLAGS=["-framework", "CoreLocation"]
)

env.Append(CPPPATH=["godot-cpp/include"])

sources = [
	"src/register_types.cpp",
	"src/geolocation.mm",
]

library = env.SharedLibrary(
	target="bin/libgodot_ios_geolocation",
	source=sources
)

Default(library)
