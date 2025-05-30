cmake_minimum_required(VERSION 3.16)

project(SiYiModule)

# Qt6 requirements
find_package(Qt6 REQUIRED COMPONENTS Core Network)

# Define static library for SiYi
qt_add_library(SiYi STATIC
    SiYi.cc
    SiYi.h
    SiYiCamera.cc
    SiYiCamera.h
    SiYiCrcApi.cc
    SiYiCrcApi.h
    SiYiTcpClient.cc
    SiYiTcpClient.h
    SiYiTransmitter.cc
    SiYiTransmitter.h
)

# Include the current source directory for headers
target_include_directories(SiYi PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})

# Link necessary Qt6 libraries
target_link_libraries(SiYi
    PUBLIC
        Qt6::Core
        Qt6::Network
)

# Enable MOC for QObject classes
set_target_properties(SiYi PROPERTIES
    AUTOMOC ON
    AUTOUIC OFF
    AUTORCC OFF
)
