set(TELINK_LINK_FLAGS
    --gc-sections
    -T${TELINK_LINKER_SCRIPT}
    -Map=${TELINK_PROJECT_NAME}.map
)

if(TELINK_EQUIP_TYPE STREQUAL "ZC")
    set(TELINK_LIB_ZB "${CMAKE_SDK_SOURCE_DIR}/zigbee/lib/tc32/libzb_coordinator.a")
elseif(TELINK_EQUIP_TYPE STREQUAL "ZR")
    set(TELINK_LIB_ZB "${CMAKE_SDK_SOURCE_DIR}/zigbee/lib/tc32/libzb_router.a")
elseif(TELINK_EQUIP_TYPE STREQUAL "ZED")
    set(TELINK_LIB_ZB "${CMAKE_SDK_SOURCE_DIR}/zigbee/lib/tc32/libzb_ed.a")
else()
    message(FATAL_ERROR "Unknown TELINK_EQUIP_TYPE: ${TELINK_EQUIP_TYPE}")
endif()

set(TELINK_LIBS
    "${TELINK_LIB_ZB}"
    "${CMAKE_SDK_SOURCE_DIR}/platform/lib/libdrivers_8258.a"
)
