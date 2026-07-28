cmake_minimum_required(VERSION 3.16)

set(CMAKE_CONFIG_DIR "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

include("${CMAKE_CONFIG_DIR}/config.cmake")
include("${CMAKE_CONFIG_DIR}/toolchain.cmake")
include("${CMAKE_CONFIG_DIR}/link.cmake")

project(${TELINK_PROJECT_NAME} C ASM)

add_subdirectory(cmake)

add_executable(${PROJECT_NAME} ${PROJECT_SOURCES} ${SDK_SOURCES})
set_target_properties(${PROJECT_NAME} PROPERTIES SUFFIX ".elf")

target_include_directories(${PROJECT_NAME} PRIVATE ${PROJECT_INCLUDES} ${SDK_INCLUDES})
target_compile_definitions(${PROJECT_NAME} PRIVATE ${TELINK_COMPILE_DEFINITIONS})
target_link_options(${PROJECT_NAME} PRIVATE ${TELINK_LINK_FLAGS})
target_link_libraries(${PROJECT_NAME} PRIVATE ${TELINK_LIBS})

add_custom_command(
    TARGET ${PROJECT_NAME}
    POST_BUILD
    COMMAND ${CMAKE_OBJCOPY} -v -O binary $<TARGET_FILE:${PROJECT_NAME}> ${PROJECT_NAME}.bin
    COMMAND ${CMAKE_SIZE} -t $<TARGET_FILE:${PROJECT_NAME}>
    VERBATIM
)
