file(GLOB_RECURSE PROJECT_SOURCES_VAR CONFIGURE_DEPENDS
    "${CMAKE_PROJ_SOURCE_DIR}/${TELINK_APP_SOURCE_DIR}/*.c"
    "${CMAKE_PROJ_SOURCE_DIR}/common/*.c"
)

set(PROJECT_INCLUDES_VAR
    "${CMAKE_PROJ_SOURCE_DIR}/${TELINK_APP_SOURCE_DIR}"
    "${CMAKE_PROJ_SOURCE_DIR}/common"
)

file(GLOB_RECURSE SDK_SOURCES_PLATFORM_VAR CONFIGURE_DEPENDS
    "${CMAKE_SDK_SOURCE_DIR}/platform/boot/link_cfg.S"
    "${CMAKE_SDK_SOURCE_DIR}/platform/boot/8258/cstartup_8258.S"
    "${CMAKE_SDK_SOURCE_DIR}/platform/tc32/div_mod.S"
    "${CMAKE_SDK_SOURCE_DIR}/platform/chip_8258/*.c"
    "${CMAKE_SDK_SOURCE_DIR}/platform/services/b85m/*.c"
)

file(GLOB_RECURSE SDK_SOURCES_GENERAL_VAR CONFIGURE_DEPENDS
    "${CMAKE_SDK_SOURCE_DIR}/proj/*.c"
    "${CMAKE_SDK_SOURCE_DIR}/zigbee/*.c"
    "${CMAKE_SDK_SOURCE_DIR}/zbhci/*.c"
)

set(include_roots
    "${CMAKE_SDK_SOURCE_DIR}/platform/chip_8258"
    "${CMAKE_SDK_SOURCE_DIR}/proj"
    "${CMAKE_SDK_SOURCE_DIR}/zigbee"
    "${CMAKE_SDK_SOURCE_DIR}/zbhci"
)

set(ALL_SDK_INCLUDES "")
foreach(root IN LISTS include_roots)
    list(APPEND ALL_SDK_INCLUDES "${root}")
    file(GLOB_RECURSE child_paths LIST_DIRECTORIES true "${root}/*")
    foreach(path IN LISTS child_paths)
        if(IS_DIRECTORY "${path}")
            list(APPEND ALL_SDK_INCLUDES "${path}")
        endif()
    endforeach()
endforeach()

set(SDK_INCLUDES_VAR
    ${ALL_SDK_INCLUDES}
    "${CMAKE_SDK_SOURCE_DIR}/platform"
    "${CMAKE_SDK_SOURCE_DIR}/platform/tc32"
)

set(PROJECT_SOURCES ${PROJECT_SOURCES_VAR} PARENT_SCOPE)
set(PROJECT_INCLUDES ${PROJECT_INCLUDES_VAR} PARENT_SCOPE)
set(SDK_SOURCES ${SDK_SOURCES_GENERAL_VAR} ${SDK_SOURCES_PLATFORM_VAR} PARENT_SCOPE)
set(SDK_INCLUDES ${SDK_INCLUDES_VAR} PARENT_SCOPE)
