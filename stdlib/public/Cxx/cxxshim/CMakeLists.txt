set(libcxxshim_modulemap_target_list)
foreach(sdk ${SWIFT_SDKS})
  foreach(arch ${SWIFT_SDK_${sdk}_ARCHITECTURES})
    set(arch_suffix "${SWIFT_SDK_${sdk}_LIB_SUBDIR}-${arch}")
    set(arch_subdir "${SWIFT_SDK_${sdk}_LIB_SUBDIR}/${arch}")

    set(module_dir "${SWIFTLIB_DIR}/${arch_subdir}")
    set(module_dir_static "${SWIFTSTATICLIB_DIR}/${arch_subdir}")

    add_custom_command(OUTPUT ${module_dir}
                       COMMAND ${CMAKE_COMMAND} "-E" "make_directory" "${module_dir}")
    if(SWIFT_BUILD_STATIC_STDLIB)
      add_custom_command(OUTPUT ${module_dir_static}
                         COMMAND ${CMAKE_COMMAND} "-E" "make_directory" "${module_dir_static}")
    endif()

    set(outputs)
    foreach(source libcxxshim.modulemap libcxxshim.h)
      add_custom_command(OUTPUT ${module_dir}/${source}
                         DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/${source}
                         COMMAND ${CMAKE_COMMAND} "-E" "copy_if_different" "${CMAKE_CURRENT_SOURCE_DIR}/${source}" "${module_dir}/${source}"
                         COMMENT "Copying ${source} to ${module_dir}")
      list(APPEND outputs "${module_dir}/${source}")

      if(SWIFT_BUILD_STATIC_STDLIB)
        add_custom_command(OUTPUT ${module_dir_static}/${source}
                           DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/${source}
                           COMMAND ${CMAKE_COMMAND} "-E" "copy_if_different" "${CMAKE_CURRENT_SOURCE_DIR}/${source}" "${module_dir_static}/${source}"
                           COMMENT "Copying ${source} to ${module_dir_static}")
        list(APPEND outputs "${module_dir_static}/${source}")
      endif()
    endforeach()
    list(APPEND outputs ${module_dir})
    if(SWIFT_BUILD_STATIC_STDLIB)
      list(APPEND outputs ${module_dir_static})
    endif()

    add_custom_target(cxxshim-${sdk}-${arch} ALL
                      DEPENDS ${outputs}
                      COMMENT "Copying cxxshims to ${module_dir}")
    list(APPEND libcxxshim_modulemap_target_list cxxshim-${sdk}-${arch})


    swift_install_in_component(FILES libcxxshim.modulemap libcxxshim.h
                               DESTINATION "lib/swift/${arch_subdir}"
                               COMPONENT compiler)
    if(SWIFT_BUILD_STATIC_STDLIB)
      swift_install_in_component(FILES libcxxshim.modulemap libcxxshim.h
                                 DESTINATION "lib/swift_static/${arch_subdir}"
                                 COMPONENT compiler)
    endif()
  endforeach()
endforeach()

add_custom_target(libcxxshim_modulemap DEPENDS ${libcxxshim_modulemap_target_list})
set_property(TARGET libcxxshim_modulemap PROPERTY FOLDER "Miscellaneous")
add_dependencies(sdk-overlay libcxxshim_modulemap)
add_dependencies(compiler libcxxshim_modulemap)
