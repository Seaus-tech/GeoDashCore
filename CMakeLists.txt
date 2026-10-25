cmake_minimum_required(VERSION 3.15)
project(GeoDashCore LANGUAGES CXX)

# Force modern C++ standards
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Configure the target source files
set(SOURCES
    src/main.cpp
)

# Detect the Operating System and separate logic
if(APPLE)
    list(APPEND SOURCES src/platform/mac.mm)
    add_compile_definitions(PLATFORM_MAC)
elseif(WIN32)
    list(APPEND SOURCES src/platform/windows.cpp)
    add_compile_definitions(PLATFORM_WINDOWS)
endif()

# Instruct the compiler to output a dynamic library (.dll or .dylib)
add_library(GeoDashCore SHARED ${SOURCES})

