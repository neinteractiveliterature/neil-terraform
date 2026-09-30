resource "random_password" "cantrip_production_db" {
  length  = 32
  special = false
}

# Deliberately does NOT get rds_iam: this user has no AWS identity to mint
# IAM auth tokens with, and granting rds_iam would immediately invalidate the
# password below. Not a member of any other role and no createdb/createrole,
# so it can only touch what it owns.
resource "postgresql_role" "cantrip_production" {
  name     = "cantrip_production"
  login    = true
  password = random_password.cantrip_production_db.result
}

resource "postgresql_database" "cantrip_production" {
  name  = "cantrip_production"
  owner = postgresql_role.cantrip_production.name

  lifecycle {
    prevent_destroy = true
  }
}

# Postgres grants CONNECT on every database to PUBLIC by default; revoke it so
# only the owner (and neiladmin, for administration) can connect.
resource "postgresql_grant" "cantrip_production_public_revoke" {
  database    = postgresql_database.cantrip_production.name
  role        = "public"
  object_type = "database"
  privileges  = []

  depends_on = [postgresql_grant.cantrip_production_connect]
}

resource "postgresql_grant" "cantrip_production_connect" {
  for_each = toset([postgresql_role.cantrip_production.name, "neiladmin"])

  database    = postgresql_database.cantrip_production.name
  role        = each.key
  object_type = "database"
  privileges  = ["CONNECT"]
}

# Password-authenticated connection string for the app. RDS forces SSL
# (rds.force_ssl), so clients should verify against the RDS CA bundle. Read it
# with `tofu output -raw cantrip_production_database_url`.
output "cantrip_production_database_url" {
  value     = "postgres://${postgresql_role.cantrip_production.name}:${random_password.cantrip_production_db.result}@${aws_db_instance.neil_production.endpoint}/${postgresql_database.cantrip_production.name}?sslmode=verify-full&sslrootcert=rds-global-bundle.pem"
  sensitive = true
}
