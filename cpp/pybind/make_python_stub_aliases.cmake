# Mirror the public aliases installed by open3d._insert_pybind_names.
# Forwarding imports preserve one class identity across both import paths.
set(package_dir "${PYTHON_PACKAGE_DST_DIR}/open3d")
set(binding_dir "${package_dir}/cpu/pybind")
file(GLOB_RECURSE binding_stubs RELATIVE "${binding_dir}" "${binding_dir}/*.pyi")
foreach(stub IN LISTS binding_stubs)
    # The lean build omits these viewer bindings. Keep their signatures usable
    # without emitting raw C++ names or ellipses as Python type annotations.
    file(READ "${binding_dir}/${stub}" contents)
    foreach(viewer_type TriangleMeshModel MaterialRecord)
        string(REPLACE "open3d::visualization::rendering::${viewer_type}"
               "typing.Any" contents "${contents}")
    endforeach()
    file(WRITE "${binding_dir}/${stub}" "${contents}")
    if(stub STREQUAL "__init__.pyi")
        continue()
    endif()
    string(REGEX REPLACE "(/__init__)?[.]pyi$" "" module_path "${stub}")
    string(REPLACE "/" "." module_name "${module_path}")
    set(alias_path "${package_dir}/${stub}")
    if(EXISTS "${package_dir}/${module_path}/__init__.py")
        set(alias_path "${package_dir}/${module_path}/__init__.pyi")
    endif()
    get_filename_component(alias_dir "${alias_path}" DIRECTORY)
    file(MAKE_DIRECTORY "${alias_dir}")
    file(WRITE "${alias_path}" "from open3d.cpu.pybind.${module_name} import *\n")
endforeach()
file(WRITE "${package_dir}/py.typed" "")
