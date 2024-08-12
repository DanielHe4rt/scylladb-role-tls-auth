import { Cluster, VerifyMode } from "@lambda-group/scylladb";

const cluster = new Cluster({
  nodes: ["127.0.0.1:9142"],
  ssl: {
    enabled: true,
    truststoreFilepath: "../certificates/developer_cert.pem",
    privateKeyFilepath: "../certificates/developer_key.pem",
    caFilepath: "../certificates/developer_truststore.pem",
    verifyMode: VerifyMode.Peer,
  }
});

const session = await cluster.connect("system_schema");

interface Role {
  role: String,
  can_login: boolean,
  is_superuser: boolean,
  member_of?: String[],
  salted_hash?: String,
}

const roles: Role[] = await session
  .execute("SELECT role, can_login, is_superuser, member_of, salted_hash FROM system.roles")
  .catch(console.error);

roles.forEach((role) => {
  console.log(role);
});

interface ConnectedClient {
  username: String,
  driver_name: String,
  driver_version: String,
}

const clients: ConnectedClient[] = await session
  .execute("SELECT username, driver_name, driver_version  FROM system.clients")
  .catch(console.error);

clients.forEach((client) => {
  console.log(client);
});