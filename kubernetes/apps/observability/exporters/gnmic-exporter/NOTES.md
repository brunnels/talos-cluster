# arista setup

- create self-signed cert
https://nickplunkett.com/posts/arista-eos-eapi-https-self-signed-cert/

```
management api http-commands
   protocol https ssl profile self-signed
   no shutdown
!
management api gnmi
   transport grpc default
      ssl profile self-signed
   provider eos-native
!
management api netconf
   transport ssh default
!
management api restconf
   transport https default
      ssl profile self-signed
!
management security
   ssl profile client
      tls versions 1.2
   !
   ssl profile self-signed
      certificate self-signed.crt key self-signed.key
!
```
