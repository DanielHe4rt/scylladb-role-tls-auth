<p align="center">
  <p align="center">
  <img src=".github/images/logo.png" alt="Logo" width="150">
  </p>
  <h2 align="center"> Role Certificated Based Authentication Demo </h2>

  <p align="center">
    <a href="https://opensource.docs.scylladb.com/stable/operating-scylla/security/certificate-authentication.html">
        <strong>« Explore the Documentation »</strong>
    </a>
    <br />
    <a href="https://github.com/scylladb/role-tls-auth-demo/issues/new">Report Bug or Request Feature</a>
  </p>
</p>
<hr>

<center>
This project is designed to help you to implement TLS with Authentication via Role together with Certificates.
</center>

## How it works

ScyllaDB can support authentication via regular users creation but also with roles.

> Roles supersede users and generalize them. In addition to doing with roles everything that you could previously do with users in older versions of Scylla, roles can be granted to other roles. If a role developer is granted to a role manager, then all permissions of the developer are granted to the manager.

| Role/on  | customer.info | schedule.cust | schedule.train | customer keyspace | schedule keyspace |
|----------|---------------|---------------|----------------|-------------------|-------------------|
| DBA      | superuser     | superuser     | superuser      | superuser         | superuser         |
| developer    | MODIFY        | MODIFY        | MODIFY         | SELECT            | SELECT            |
| trainer  | SELECT        | SELECT        | SELECT         |                   | SELECT            |
| customer |               |               | SELECT         |                   |                   |

To create an role that turns into a `authenticatable`, you can run `CREATE ROLE` specifying `LOGIN = true`:

```sql
CREATE ROLE IF NOT EXISTS 'developer' WITH LOGIN = true;
GRANT SELECT ON your_keyspace.your_table TO developer;
```

After creating your role and giving the proper permissions, you have to attach the role name inside your certificate:

```sh
openssl genpkey -algorithm RSA -out "./developer_key.pem" -pkeyopt rsa_keygen_bits:2048
openssl req -new -key "./developer_key.pem" -out "./developer.csr" -subj "/CN=developer" # /CN=<your-role>
openssl x509 -req -in "./developer.csr" -CA "./root_cert.pem" -CAkey "./root_key.pem" -CAcreateserial -out "./developer.pem" -days 365
```

After you enable the TLS under `scylla.yaml` you can check under `auth_certificate_role_queries` the `query` regular expression to be executed (and you're free to change it):

```yaml
native_transport_port_ssl: 9142

authenticator: com.scylladb.auth.CertificateAuthenticator
auth_certificate_role_queries:
  - source: SUBJECT
    query: CN=([^,\s]+)

client_encryption_options:
  enabled: true
  certificate: /etc/scylla/certs/server_cert.pem
  keyfile: /etc/scylla/certs/server_key.pem
  truststore: /etc/scylla/certs/server_truststore.pem
  require_client_auth: true
```

## Quick Win: Run the example with JS/Rust

Create the environment by running:

```sh
make setup-scylla-with-tls
```

This command will:

* Create the base certificates (root and developer)
* Run a ScyllaDB Cluster (3 nodes)
* Switch to `PasswordAuthenticator` authentication mode
* Login as superuser and create `developer` role
* Switch to `com.scylladb.auth.CertificateAuthenticator` authentication mode

### Quick Win: Running with Rust

Enter the `rust` directory and run the project:

```sh
cd rust
cargo run
```

Output:

```log
Role { role: "cassandra", can_login: true, is_superuser: true, member_of: None, salted_hash: Some("$giant-hash") }
Role { role: "developer", can_login: true, is_superuser: false, member_of: None, salted_hash: None }
ConnectedClient { username: "developer", driver_name: "scylla-rust-driver", driver_version: "0.13.1" }
```

### Quick Win: Running with JS/TS

Enter the `js-ts` directory, install the dependencies and run the project:

```sh
cd js-ts
npm install
npm run tls
```

Output:

```log
{
  can_login: true,
  is_superuser: true,
  member_of: null,
  role: 'cassandra',
  salted_hash: '$giant-hash-here'
}
{
  can_login: true,
  is_superuser: false,
  member_of: null,
  role: 'developer',
  salted_hash: null
}
{
  driver_name: 'scylla-rust-driver',
  driver_version: '0.13.1',
  username: 'developer'
}
```
