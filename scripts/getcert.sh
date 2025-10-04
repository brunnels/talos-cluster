#!/bin/bash

#
# Usage: getcert.sh remote.host.name [port] [--info]
#
REMHOST=$1
REMPORT=${2:-443}
INFO=$3

CERT_DATA="$(echo |\
openssl s_client -showcerts -connect "${REMHOST}:${REMPORT}" 2>&1 | openssl x509 -outform PEM)"
#openssl s_client -connect "${REMHOST}:${REMPORT}")"
#| sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p'
#| openssl x509 -inform pem -noout -text)"

if [ "$INFO" == "--info" ]; then
    COMMON_NAME=$(echo "$CERT_DATA" | openssl x509 -noout -subject | awk -F'CN = ' '{print $2}')
    SAN_DATA=$(echo "$CERT_DATA" | openssl x509 -noout -ext subjectAltName | sed 's/IP Address/IP/g' | grep -E '^.*{2}(DNS:|IP:).*$')
    ISSUER_CN=$(echo "$CERT_DATA" | openssl x509 -noout -issuer | awk -F'CN = ' '{print $2}')
    ISSUER_ORG=$(echo "$CERT_DATA" | openssl x509 -noout -issuer | sed 's/.*O = \(.*\),.*/\1/')
    VALID_FROM=$(echo "$CERT_DATA" | openssl x509 -noout -dates | awk -F'notBefore=' '{print $2}')
    VALID_TO=$(echo "$CERT_DATA" | openssl x509 -noout -dates | awk -F'notAfter=' '{print $2}' | tail -n 1)
    KEY_SIZE=$(echo "$CERT_DATA" | openssl x509 -noout -text | awk '/Public-Key:/ {gsub(/[()]/,"",$2); print $2}')
    SERIAL_NUMBER=$(echo "$CERT_DATA" | openssl x509 -noout -serial | sed -e 's/serial=//')

    # Print the information
    echo "Common Name: $COMMON_NAME"
    if [ -n "$SAN_DATA" ]; then
        echo "Subject Alternative Names:"
        for line in $SAN_DATA; do
          clean_line=$(echo "$line" | sed 's/^[[[:blank:]]*\u00A0*]//; s/,$//' )
          echo "  $clean_line"
        done
    fi
    echo "Valid From: $VALID_FROM"
    echo "Valid To: $VALID_TO"
    echo "Issuer: $ISSUER_CN, $ISSUER_ORG"
    echo "Key Size: $KEY_SIZE bit"
    echo "Serial Number: $SERIAL_NUMBER"
else
    echo "$CERT_DATA"
fi
