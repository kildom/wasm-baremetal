#!/bin/bash
set -e -o pipefail
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )/globals.sh"

sysroot_targets="libc crt libcxx libunwind"

mkdir -p $BUILD_DIR
mkdir -p $INSTALL_DIR

MAKEFILE=$BUILD_DIR/Makefile

echo BM_FORCE_FULL_REBUILD?=false > $MAKEFILE #TODO: delete it, always use environment variable
echo export BM_FORCE_FULL_REBUILD >> $MAKEFILE
echo BM_CONFIGURE_ONLY?=false >> $MAKEFILE
echo export BM_CONFIGURE_ONLY >> $MAKEFILE

function make-target {
    echo "$1: $2" >> $MAKEFILE
    echo "	$SCRIPTS_DIR/$3" >> $MAKEFILE
    echo "only-$1:" >> $MAKEFILE
    echo "	$SCRIPTS_DIR/$3" >> $MAKEFILE
    echo ".PHONY: only-$1 $1" >> $MAKEFILE
}

for f in $SCRIPTS_DIR/conf-*.sh; do
    conf_file=$(basename $f)
    conf=${conf_file:5:-3}
    echo "all: $conf" >> $MAKEFILE
    echo "compiler-rt-$conf: compiler-rt" >> $MAKEFILE
    echo "_only__compiler-rt-$conf: empty" >> $MAKEFILE
    prev=compiler-rt
    for target in $sysroot_targets; do
        make-target $target-$conf $prev-$conf "build-$target.sh $conf_file"
        make-target _only__$target-$conf _only__$prev-$conf "build-$target.sh $conf_file"
        echo "$target: $target-$conf" >> $MAKEFILE
        echo "only-$target: only-$target-$conf" >> $MAKEFILE
        prev=$target
    done
    echo "$conf: libunwind-$conf" >> $MAKEFILE
    echo "only-$conf: _only__libunwind-$conf" >> $MAKEFILE
    echo ".PHONY: compiler-rt-$conf _only__compiler-rt-$conf $conf only-$conf" >> $MAKEFILE
done

echo "empty:" >> $MAKEFILE
make-target llvm empty build-llvm.sh
make-target compiler-rt llvm build-compiler-rt.sh
echo ".PHONY: all empty llvm compiler-rt" >> $MAKEFILE

make -C $BUILD_DIR -j1 $@
