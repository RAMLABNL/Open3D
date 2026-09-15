#!/usr/bin/env bash
set -euo pipefail
expected_version=${2:?Pass the version derived from the release tag}

shopt -s nullglob
debs=(/artifacts/*.deb)
wheels=(/artifacts/*.whl)
[[ ${#debs[@]} == 1 && ${#wheels[@]} == 1 ]]
[[ "$(dpkg-deb --field "${debs[0]}" Version)" == "$expected_version" ]]
case "${1:?Select apt or python verification}" in
apt)
apt-get update
apt-get install --yes --no-install-recommends "${debs[0]}"
dpkg-deb --field "${debs[0]}" Package Version Depends
cmake -S /opt/open3d-consumer -B /tmp/open3d-consumer-build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_STANDARD=23 \
    -DEXPECTED_OPEN3D_VERSION="$expected_version"
cmake --build /tmp/open3d-consumer-build --parallel 2
ctest --test-dir /tmp/open3d-consumer-build --output-on-failure
if ldd /tmp/open3d-consumer-build/open3d-consumer | \
    grep -E 'not found|libc\+\+|libGL\.|libGLX\.|libX11\.'; then
    echo 'Unexpected C++ runtime or viewer dependency.' >&2
    exit 1
fi
if grep -RE '/src/|/build/|/usr/lib/llvm|3rdparty_filament|3rdparty_glfw' \
    /usr/lib/cmake/Open3D /usr/lib/*/cmake/Open3D 2>/dev/null; then
    echo 'Open3D exports contain a build path or viewer dependency.' >&2
    exit 1
fi
;;
python)
python3 -m venv /tmp/open3d-consumer-venv
/tmp/open3d-consumer-venv/bin/pip install "${wheels[0]}"
/tmp/open3d-consumer-venv/bin/python -I /opt/open3d-consumer/check_python.py "$expected_version"
# Check public aliases from the installed wheel, without generating consumer stubs.
/tmp/open3d-consumer-venv/bin/pip install mypy==1.15.0
/tmp/open3d-consumer-venv/bin/python -m mypy --strict --follow-imports=silent \
    /opt/open3d-consumer/check_typing.py
# Trace from the extension so its auditwheel RPATH applies to bundled dependencies.
python_module="$(/tmp/open3d-consumer-venv/bin/python -I -c \
    'import open3d.cpu.pybind as pybind; print(pybind.__file__)')"
dependency_report="$(ldd "$python_module")"
if grep -E 'not found|libc\+\+|libGL\.|libGLX\.|libX11\.' <<< "$dependency_report"; then
    echo 'Unexpected Python runtime or viewer dependency.' >&2
    exit 1
fi
;;
*) echo 'Select apt or python verification.' >&2; exit 1 ;;
esac
mkdir -p /verification
touch "/verification/${1}-passed"
echo "Open3D ${1} package verification passed"
