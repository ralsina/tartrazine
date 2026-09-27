cmake_minimum_required(VERSION 3.20)
project(demo VERSION 1.2.3 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
option(DEMO_TESTS "Build tests" ON)

# main library
add_library(demo STATIC src/demo.cpp src/util.cpp)
target_include_directories(demo PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)
target_compile_definitions(demo PRIVATE DEMO_VERSION="${PROJECT_VERSION}")

if(DEMO_TESTS)
  enable_testing()
  add_executable(demo_test test/main.cpp)
  target_link_libraries(demo_test PRIVATE demo)
  add_test(NAME demo_test COMMAND demo_test)
endif()

foreach(f IN LISTS EXTRA_FILES)
  message(STATUS "extra: ${f}")
endforeach()
