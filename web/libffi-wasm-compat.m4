# This libffi checkout calls the legacy Libtool symbol-prefix probe. In
# Emscripten WebAssembly object files, C symbols use their source spelling.
m4_ifndef([LT_SYS_SYMBOL_USCORE], [
  AC_DEFUN([LT_SYS_SYMBOL_USCORE], [
    sys_symbol_underscore=no
    AC_SUBST([sys_symbol_underscore])
  ])
])
