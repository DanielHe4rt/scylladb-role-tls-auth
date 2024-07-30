# Cert Role Based Authentication Demo


## Quick Setup

```bash
make setup # This will generate the certificates and the truststore
docker-compose up -d # This will start the ScyllaDB cluster

make auth-type auth=password # This will set the authentication type to password based
make create-role-cql # This will create the role developer in the cluster

make auth-type auth=role # This will set the authentication type to role based

# Now you can *in theory* login with the role developer
cqlsh --ssl # WIP

```

Links:
- https://opensource.docs.scylladb.com/stable/operating-scylla/security/authentication.html
- https://opensource.docs.scylladb.com/stable/operating-scylla/security/client-node-encryption.html

## What is this?


## 1. Create the certificates:

Generate the your root certificate to use as truststore for the other role based certificates:

This will be the main certificated placed in the server:
```bash
make root-cert

# openssl genpkey -algorithm RSA -out root_key.pem -pkeyopt rsa_keygen_bits:2048
# openssl req -x509 -new -key root_key.pem -days 3650 -out root_cert.pem -subj "/CN=SUPERCOOLADMIN"
```

Now for each role that you plan to let available, create a new certificated signed in by the root certificate:

```bash
make user-cert role=developer

# openssl genpkey -algorithm RSA -out "./${DIRECTORY}/$(role)_key.pem" -pkeyopt rsa_keygen_bits:2048
# openssl req -new -key "./${DIRECTORY}/$(role)_key.pem" -out "./${DIRECTORY}/$(role).csr" -subj "/CN=$(role)"
# openssl x509 -req -in "./${DIRECTORY}/$(role).csr" -CA "./${DIRECTORY}/${CA_CERT}.pem" -CAkey "./${DIRECTORY}/${CA_KEY}.pem" -CAcreateserial -out "./${DIRECTORY}/$(role)_cert.pem" -days 365
```

The `truststore` in the context of ScyllaDB's TLS configuration is a file that contains one or more trusted Certificate Authority (CA) certificates. These CA certificates are used to verify the authenticity of client certificates presented during the TLS handshake. Essentially, the truststore allows the server to determine whether the client's certificate was issued by a trusted authority.

```bash
make truststore

# cat ./${DIRECTORY}/*_cert.pem > ./${DIRECTORY}/truststore.pem
# openssl x509 -in "./${DIRECTORY}/truststore.pem" -text -noout
```

## 2. Example of Truststore Configuration

In your `/etc/scylla/scylla.yaml` file, you will reference this combined file in the `client_encryption_options`:

```yaml
client_encryption_options:
   enabled: True
   certificate: /path/to/your/server_certificate.pem
   keyfile: /path/to/your/server_key.pem
   truststore: /path/to/your/truststore.pem
   require_client_auth: True
```