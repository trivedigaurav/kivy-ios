#!/bin/bash
set -x

. $(dirname $0)/environment.sh

if [ ! -f $CACHEROOT/openssl-$OPENSSL_VERSION.tar.gz ]; then
	try pushd $CACHEROOT
	try curl -LO http://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz
	popd
fi
if [ ! -d $TMPROOT/openssl-$OPENSSL_VERSION ]; then
	try pushd $TMPROOT
	try rm -rf openssl-$OPENSSL_VERSION
	try tar xzf $CACHEROOT/openssl-$OPENSSL_VERSION.tar.gz
	popd
fi

if [ ! -f $TMPROOT/openssl-$OPENSSL_VERSION/libssl.a ]; then
	try pushd $TMPROOT/openssl-$OPENSSL_VERSION
	try ./Configure no-dso no-krb5 BSD-generic32
	# taken from https://github.com/st3fan/ios-openssl/blob/master/build.sh
	ARCH=armv7
	perl -i -pe 's|static volatile sig_atomic_t intr_signal|static volatile int intr_signal|' crypto/ui/ui_openssl.c
	perl -i -pe "s|^CC= gcc|CC= ${ARM_CC}|g" Makefile
	perl -i -pe "s|^CFLAG= (.*)|CFLAG= ${ARM_CFLAGS} \$1|g" Makefile
	try make build_libs

	# copy to buildroot
	try cp libssl.a $BUILDROOT/lib/libssl.a
	try cp libcrypto.a $BUILDROOT/lib/libcrypto.a
	try cp -a include/openssl $BUILDROOT/include/openssl
	popd
fi
