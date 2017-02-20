#!/bin/sh

base_dir=$(dirname $0)
lib_dir=$(echo $1)
shift

for pkg in $@
do
    pkg_dir="${base_dir}/${pkg}"
    cat <<MAKE
${lib_dir}/$(basename ${pkg}).stamp: \$(call lookup_scala_srcs, ${pkg_dir}) \$(rocketchip_stamp)
	mkdir -p ${lib_dir}
	rm -rf ${pkg_dir}/lib
	ln -s ${base_dir}/lib ${pkg_dir}/lib
	cd ${pkg_dir} && \$(SBT) publish-local
	touch \$@
MAKE
done
