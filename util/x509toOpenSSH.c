//
// x509toOpenSSH.c
//
// Copyright (c) 2003 Timo Felbinger
//
// This tool reads an X.509 certificate in PEM format from stdin,
// extracts the public key (currently: must be an RSA key), and
// writes it in OpenSSH format (protocol version 2) to stdout.
//
// Exponent and modulus, if extracted successfully, are written
// to stderr.
//
// The first step (key extraction) is done via OpenSSL calls.
//
// The second step (conversion into OpenSSH format) uses code which
// is largely based on the OpenSSH-3.7.1p1 sources, so the following
// applies:
//
//  * Copyright (c) 1995 Tatu Ylonen <ylo@cs.hut.fi>, Espoo, Finland
//  *
//  * As far as I am concerned, the code I have written for this software
//  * can be used freely for any purpose.  Any derived versions of this
//  * software must be clearly marked as such, and if the derived work is
//  * incompatible with the protocol description in the RFC file, it must be
//  * called by a name other than "ssh" or "Secure Shell".
//  *
//  *
//  * Copyright (c) 2000, 2001 Markus Friedl.  All rights reserved.
//  *
//  * Redistribution and use in source and binary forms, with or without
//  * modification, are permitted provided that the following conditions
//  * are met:
//  * 1. Redistributions of source code must retain the above copyright
//  *    notice, this list of conditions and the following disclaimer.
//  * 2. Redistributions in binary form must reproduce the above copyright
//  *    notice, this list of conditions and the following disclaimer in the
//  *    documentation and/or other materials provided with the distribution.
//  *
//  * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
//  * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
//  * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
//  * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
//  * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
//  * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//  * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
//  * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
//  * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
//  * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//  */
//
// As far as my (Timo Felbinger's) contribution to this code is concerned,
// Markus Friedl's conditions, including the disclaimer, apply mutatis
// mutandis.
//
//
// Building this tool:
//
// This tool will typically have to be linked against libcrypto
// (from openssl) and whatever library contains function __b64_ntop
// (with GNU-libc, this is usually in libresolv).
// Under Linux, it should compile and link with
//
//   gcc -lcrypto -lresolv x509toOpenSSH.c -o X509toOpenSSH
//

#include <stdio.h>
#include <string.h>


#define SSLEAY_MACROS 1

#include <openssl/bn.h>   // gives BIGNUM and friends
#include <openssl/pem.h>  // handles PEM format files
#include <openssl/evp.h>  // high-level cryptography
#include <openssl/rsa.h>
#include <openssl/x509.h>

#include <resolv.h>       // gives __b64_ntop() (aka uuencode)


#define PUT_32BIT(cp, value) ( \
	(cp)[0] = (value) >> 24, \
	(cp)[1] = (value) >> 16, \
	(cp)[2] = (value) >> 8, \
	(cp)[3] = (value) )

void fatal( const char *msg ) {
	fprintf( stderr, "***ERROR: %s\n", msg );
	fflush( stderr );
	exit( 1 );
}

int main( int argc, char **argv ) {
	int rv = 0;
	X509 *pcert;
	EVP_PKEY *ppkey;
	char *e_hex, *n_hex;
	unsigned char *blob, *buffer, *bp;
	int blobsize;
	int bytes_name, bytes_exponent, bytes_modulus;
	const char *keyname;

	if( argc >= 2 ) {
		fprintf( stderr , "Usage:  x509toOpenSSH < x509_cert.pem > ssh_rsa_key.pub\n" );
		exit( 0 );
	}
	
	pcert = NULL;
	if( ! PEM_read_X509( stdin, &pcert, 0, NULL ) ) {
		fatal( "PEM_read_bio_X509() failed to read X509 certificate in PEM format from stdin" );
	}

	if( ! ( ppkey = X509_get_pubkey( pcert ) ) ) {
		fatal( "X509 certificate was read, but X509_get_pkey() failed to extract public key" );
	}

	switch( ppkey->type ) {
		case EVP_PKEY_RSA:

			keyname = "ssh-rsa";

			if( ! ( e_hex = BN_bn2hex( ppkey->pkey.rsa->e ) ) ) {
				fatal( "RSA public key was extracted, but BN_bn2hex failed to convert exponent into string" );
			}
			
			if( ! ( n_hex = BN_bn2hex( ppkey->pkey.rsa->n ) ) ) {
				fatal( "RSA public key was extracted, but BN_bn2hex failed to convert modulus into string" );
			}

			fprintf( stderr, "exponent: 0x%s\n", e_hex );
			fprintf( stderr, "modulus: 0x%s\n", n_hex );

			bytes_name = strlen( keyname );
			bytes_exponent = BN_num_bytes( ppkey->pkey.rsa->e );
			bytes_modulus = BN_num_bytes( ppkey->pkey.rsa->n );
			
			blobsize =   4 + bytes_name
								 + 4 + (bytes_exponent+1)
								 + 4 + (bytes_modulus+1)
								 + 1;
						 
			if( ! ( blob = (unsigned char *)malloc( blobsize ) ) ) {
				fatal( "malloc() failed to allocate blob" );
			}
			if( ! ( buffer = (unsigned char *)malloc( 2 * blobsize ) ) ) {
				fatal( "malloc() failed to allocate buffer" );
			}
			
			bp = blob;
			
			PUT_32BIT( bp, bytes_name ), bp += 4;
			memcpy( bp, keyname, bytes_name ), bp += bytes_name;
			
			BN_bn2bin( ppkey->pkey.rsa->e, buffer );
			if( buffer[0] & 0x80 ) {
				// highest bit set would indicate a negative number.
				// to avoid this, we have to spend an extra byte:
				PUT_32BIT( bp, bytes_exponent+1 ), bp += 4;
				*(bp++) = 0;
			} else {
				PUT_32BIT( bp, bytes_exponent ), bp += 4;
			}
			memcpy( bp, buffer, bytes_exponent ), bp += bytes_exponent;
				
			BN_bn2bin( ppkey->pkey.rsa->n, buffer );
			if( buffer[0] & 0x80 ) {
				PUT_32BIT( bp, bytes_modulus+1 ), bp += 4;
				*(bp++) = 0;
			} else {
				PUT_32BIT( bp, bytes_modulus ), bp += 4;
			}
			memcpy( bp, buffer, bytes_modulus ), bp += bytes_modulus;

			break;
				
		default:
			fatal( "public key was extracted from certificate, but it's not of type RSA" );
			break;
	}
	
	if( __b64_ntop( blob, bp-blob, buffer, 2 * blobsize ) <= 0 ) {
		fatal( "__b64_ntop() (aka: uuencode) failed" );
	}

	printf( "%s %s", keyname, buffer );
	
	return rv;
}

