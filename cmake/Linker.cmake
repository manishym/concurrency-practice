macro(concurrency_practice_configure_linker project_name)
  set(concurrency_practice_USER_LINKER_OPTION
    "DEFAULT"
      CACHE STRING "Linker to be used")
    set(concurrency_practice_USER_LINKER_OPTION_VALUES "DEFAULT" "SYSTEM" "LLD" "GOLD" "BFD" "MOLD" "SOLD" "APPLE_CLASSIC" "MSVC")
  set_property(CACHE concurrency_practice_USER_LINKER_OPTION PROPERTY STRINGS ${concurrency_practice_USER_LINKER_OPTION_VALUES})
  list(
    FIND
    concurrency_practice_USER_LINKER_OPTION_VALUES
    ${concurrency_practice_USER_LINKER_OPTION}
    concurrency_practice_USER_LINKER_OPTION_INDEX)

  if(${concurrency_practice_USER_LINKER_OPTION_INDEX} EQUAL -1)
    message(
      STATUS
        "Using custom linker: '${concurrency_practice_USER_LINKER_OPTION}', explicitly supported entries are ${concurrency_practice_USER_LINKER_OPTION_VALUES}")
  endif()

  set_target_properties(${project_name} PROPERTIES LINKER_TYPE "${concurrency_practice_USER_LINKER_OPTION}")
endmacro()
