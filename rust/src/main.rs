use std::net::IpAddr;

use openssl::ssl::{SslContextBuilder, SslFiletype, SslMethod, SslVerifyMode};
use scylla::{FromRow, SessionBuilder};
use scylla::query::Query;

#[derive(FromRow, Debug)]
struct Role {
    role: String,
    can_login: bool,
    is_superuser: bool,
    member_of: Option<Vec<String>>,
    salted_hash: Option<String>,
}

#[derive(FromRow, Debug)]
struct ConnectedClient {
    address: IpAddr,
    port: i32,
    username: String,
    driver_name: String,
    driver_version: String,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let mut context_builder = SslContextBuilder::new(SslMethod::tls())?;
    context_builder.set_ca_file("../certificates/developer_truststore.pem")?;
    context_builder.set_private_key_file("../certificates/developer_key.pem", SslFiletype::PEM)?;
    context_builder.set_certificate_chain_file("../certificates/developer_cert.pem")?;
    context_builder.set_verify(SslVerifyMode::PEER);

    let session = SessionBuilder::new()
        .known_nodes(["localhost:9042"])
        .ssl_context(Some(context_builder.build()))
        .build()
        .await?;

    let roles_query = Query::new("SELECT * FROM system.roles");
    let connected_clients_query = Query::new("SELECT address, port, username, driver_name, driver_version FROM system.clients");

    let mut current_roles = session.query(roles_query, &[]).await?
        .rows_typed::<Role>()?;

    while let Some(role) = current_roles.next().transpose()? {
        println!("{:?}", role);
    }

    let mut current_clients = session.query(connected_clients_query, &[]).await?
        .rows_typed::<ConnectedClient>()?;

    while let Some(client) = current_clients.next().transpose()? {
        println!("{:?}", client);
    }

    Ok(())
}
