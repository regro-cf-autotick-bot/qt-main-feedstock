#!/bin/sh

if test "$CONDA_BUILD_CROSS_COMPILATION" = "1"
then
  (
    mkdir -p build_native && cd build_native

    export CC=$CC_FOR_BUILD
    export CXX=$CXX_FOR_BUILD
    export LDFLAGS=${LDFLAGS//$PREFIX/$BUILD_PREFIX}
    export PKG_CONFIG_PATH=${PKG_CONFIG_PATH//$PREFIX/$BUILD_PREFIX}
    export CFLAGS=${CFLAGS//$PREFIX/$BUILD_PREFIX}
    export CXXFLAGS=${CXXFLAGS//$PREFIX/$BUILD_PREFIX}

    # hide host libs
    mkdir -p $BUILD_PREFIX/${HOST}
    mv $BUILD_PREFIX/${HOST} _hidden

    cmake -LAH -G "Ninja" \
      -DCMAKE_PREFIX_PATH=${BUILD_PREFIX} \
      -DCMAKE_IGNORE_PREFIX_PATH="${PREFIX}" \
      -DCMAKE_FIND_FRAMEWORK=LAST \
      -DCMAKE_INSTALL_RPATH:STRING=${BUILD_PREFIX}/lib \
      -DFEATURE_system_sqlite=ON \
      -DFEATURE_framework=OFF \
      -DFEATURE_gssapi=OFF \
      -DFEATURE_qml_animation=OFF \
      -DQT_BUILD_SUBMODULES="qtbase;qtdeclarative;qtshadertools;qttools" \
      -DCMAKE_RANLIB=$BUILD_PREFIX/bin/${CONDA_TOOLCHAIN_BUILD}-ranlib \
      -DFEATURE_opengl=OFF \
      -DCMAKE_INSTALL_PREFIX=${BUILD_PREFIX} \
    ..
    cmake --build . --target install
    mv _hidden $BUILD_PREFIX/${HOST}
  )
  rm -r build_native
  CMAKE_ARGS="${CMAKE_ARGS} -DQT_HOST_PATH=${BUILD_PREFIX} -DQT_BUILD_TOOLS_WHEN_CROSSCOMPILING=ON"
fi

mkdir build && cd build
cmake -LAH -G "Ninja" ${CMAKE_ARGS} \
  -DCMAKE_PREFIX_PATH=${PREFIX} \
  -DCMAKE_FIND_FRAMEWORK=LAST \
  -DCMAKE_INSTALL_RPATH:STRING=${PREFIX}/lib \
  -DINSTALL_DOCDIR=share/doc/qt6 \
  -DINSTALL_ARCHDATADIR=lib/qt6 \
  -DINSTALL_DATADIR=share/qt6 \
  -DINSTALL_INCLUDEDIR=include/qt6 \
  -DINSTALL_MKSPECSDIR=lib/qt6/mkspecs \
  -DINSTALL_EXAMPLESDIR=share/doc/qt6/examples \
  -DFEATURE_system_sqlite=ON \
  -DFEATURE_framework=OFF \
  -DFEATURE_linux_v4l=OFF \
  -DFEATURE_gssapi=OFF \
  -DFEATURE_enable_new_dtags=OFF \
  -DFEATURE_gstreamer_gl=OFF \
  -DFEATURE_openssl_linked=ON \
  -DFEATURE_qml_animation=OFF \
  -DQT_BUILD_SUBMODULES="qt3d;\
qtbase;\
qtcharts;\
qtdatavis3d;\
qtdeclarative;\
qtimageformats;\
qtmultimedia;\
qtnetworkauth;\
qtpositioning;\
qtscxml;\
qtsensors;\
qtserialport;\
qtshadertools;\
qtsvg;\
qttools;\
qttranslations" \
  ..
cmake --build . --target install
