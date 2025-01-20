cmake_minimum_required(VERSION 3.28)
project(chip8Asm CXX)
set(CMAKE_CXX_STANDARD 26)

include_directories(${CMAKE_CURRENT_LIST_DIR}/include)

file(
        GLOB_RECURSE sources
        LIST_DIRECTORIES true
        CONFIGURE_DEPENDS true
        "source/*.cpp"
)

add_executable(chip8Asm ${sources})
