cmake_minimum_required(VERSION 3.16)
project(DicomViewer VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Enable Qt tools
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

# Find required Qt components
find_package(Qt6 REQUIRED COMPONENTS Core Widgets Network)

# DCMTK (optional)
find_package(DCMTK QUIET)

# Sources
set(SOURCES
    main.cpp
)

add_executable(DicomViewer ${SOURCES})

target_link_libraries(DicomViewer PRIVATE Qt6::Core Qt6::Widgets Qt6::Network)

if(DCMTK_FOUND)
    message(STATUS "DCMTK found - enabling full DICOM support")
    target_link_libraries(DicomViewer PRIVATE ${DCMTK_LIBRARIES})
    target_include_directories(DicomViewer PRIVATE ${DCMTK_INCLUDE_DIRS})
    target_compile_definitions(DicomViewer PRIVATE DCMTK_AVAILABLE)
endif()

# Warnings
if(MSVC)
    target_compile_options(DicomViewer PRIVATE /W4)
else()
    target_compile_options(DicomViewer PRIVATE -Wall -Wextra -Wpedantic)
endif()

# Install
install(TARGETS DicomViewer RUNTIME DESTINATION bin)