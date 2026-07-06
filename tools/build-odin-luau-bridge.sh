#!/usr/bin/env sh
set -eu

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
out_dir="$root_dir/odin-out/luau-bridge"
obj_dir="$out_dir/obj"
lib_path="$out_dir/libscrapbot_luau_bridge.a"

mkdir -p "$obj_dir"
rm -f "$lib_path"

cxx=${CXX:-c++}
ar_tool=${AR:-ar}

cxxflags="-std=c++17 -Isrc -Ithird_party/luau/Common/include -Ithird_party/luau/Ast/include -Ithird_party/luau/Bytecode/include -Ithird_party/luau/Compiler/include -Ithird_party/luau/VM/include"

sources="
src/luau_bridge.cpp
third_party/luau/Common/src/BytecodeWire.cpp
third_party/luau/Common/src/StringUtils.cpp
third_party/luau/Common/src/TimeTrace.cpp
third_party/luau/Ast/src/Allocator.cpp
third_party/luau/Ast/src/Ast.cpp
third_party/luau/Ast/src/Confusables.cpp
third_party/luau/Ast/src/Cst.cpp
third_party/luau/Ast/src/Lexer.cpp
third_party/luau/Ast/src/Location.cpp
third_party/luau/Ast/src/Parser.cpp
third_party/luau/Ast/src/PrettyPrinter.cpp
third_party/luau/Bytecode/src/BytecodeBuilder.cpp
third_party/luau/Bytecode/src/BytecodeGraph.cpp
third_party/luau/Compiler/src/Compiler.cpp
third_party/luau/Compiler/src/Builtins.cpp
third_party/luau/Compiler/src/BuiltinFolding.cpp
third_party/luau/Compiler/src/ConstantFolding.cpp
third_party/luau/Compiler/src/CostModel.cpp
third_party/luau/Compiler/src/TableShape.cpp
third_party/luau/Compiler/src/Types.cpp
third_party/luau/Compiler/src/ValueTracking.cpp
third_party/luau/Compiler/src/lcode.cpp
third_party/luau/VM/src/lapi.cpp
third_party/luau/VM/src/laux.cpp
third_party/luau/VM/src/lbaselib.cpp
third_party/luau/VM/src/lbitlib.cpp
third_party/luau/VM/src/lbuffer.cpp
third_party/luau/VM/src/lbuflib.cpp
third_party/luau/VM/src/lbuiltins.cpp
third_party/luau/VM/src/lcorolib.cpp
third_party/luau/VM/src/ldblib.cpp
third_party/luau/VM/src/ldebug.cpp
third_party/luau/VM/src/ldo.cpp
third_party/luau/VM/src/lfunc.cpp
third_party/luau/VM/src/lgc.cpp
third_party/luau/VM/src/lgcdebug.cpp
third_party/luau/VM/src/linit.cpp
third_party/luau/VM/src/lmathlib.cpp
third_party/luau/VM/src/lmem.cpp
third_party/luau/VM/src/lnumprint.cpp
third_party/luau/VM/src/lobject.cpp
third_party/luau/VM/src/loslib.cpp
third_party/luau/VM/src/lperf.cpp
third_party/luau/VM/src/lstate.cpp
third_party/luau/VM/src/lstring.cpp
third_party/luau/VM/src/lstrlib.cpp
third_party/luau/VM/src/ltable.cpp
third_party/luau/VM/src/ltablib.cpp
third_party/luau/VM/src/ltm.cpp
third_party/luau/VM/src/ludata.cpp
third_party/luau/VM/src/lutf8lib.cpp
third_party/luau/VM/src/lveclib.cpp
third_party/luau/VM/src/lintlib.cpp
third_party/luau/VM/src/lvmexecute.cpp
third_party/luau/VM/src/lclass.cpp
third_party/luau/VM/src/lclasslib.cpp
third_party/luau/VM/src/lvmload.cpp
third_party/luau/VM/src/lvmutils.cpp
"

objects=""
for source in $sources; do
	object="$obj_dir/$(printf '%s' "$source" | tr '/.' '__').o"
	"$cxx" $cxxflags -c "$root_dir/$source" -o "$object"
	objects="$objects $object"
done

"$ar_tool" rcs "$lib_path" $objects
