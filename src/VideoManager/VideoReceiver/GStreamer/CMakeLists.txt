add_subdirectory(${CMAKE_SOURCE_DIR}/libs/qmlglsink qmlglsink.build)

if(NOT GST_QT6_PLUGIN_FOUND)
    return()
endif()

message(STATUS "Building GStreamer VideoReceiver")

find_package(Qt6 REQUIRED COMPONENTS Core Quick)

qt_add_library(GStreamerReceiver STATIC
    GLVideoItemStub.cc
    GLVideoItemStub.h
    gstqgc.c
    gstqgcvideosinkbin.c
    GStreamer.cc
    GStreamer.h
    GstVideoReceiver.cc
    GstVideoReceiver.h
)

if(IOS)
    target_sources(GStreamerReceiver
        PRIVATE
            gst_ios_init.h
            gst_ios_init.m
    )
endif()

target_link_libraries(GStreamerReceiver
    PRIVATE
        Qt6::Quick
        Utilities
    PUBLIC
        Qt6::Core
        qmlglsink
        Settings
        VideoReceiver
)

target_include_directories(GStreamerReceiver PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})

target_compile_definitions(GStreamerReceiver PUBLIC QGC_GST_STREAMING)
if(CMAKE_BUILD_TYPE STREQUAL "Release")
    target_compile_definitions(GStreamerReceiver PRIVATE QGC_INSTALL_RELEASE)
endif()
