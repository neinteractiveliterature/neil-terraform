# Every app database on aws_db_instance.neil_production. All of these predate
# Terraform management and are imported as-is. Each app connects as a role of
# the same name, which is the only role (besides neiladmin) granted CONNECT.
locals {
  production_databases = toset([
    "arisia_furniture_production",
    "glitchtip_production",
    "intercode_production",
    "intercon_feedback_production",
    "intercon_furniture_production",
    "larp_library_production",
    "listmonk_production",
    "rotator_production",
    "tapestries_furniture_production",
    "www_interactiveliterature_org_production",
  ])

  # Databases that are never imported as resources but still need PUBLIC's
  # default CONNECT revoked (neiladmin owns them and keeps access as owner).
  # template0/template1/rdsadmin are RDS-managed, so left alone.
  production_admin_databases = toset(["postgres"])

  # Every (database, role) pair that needs an explicit CONNECT grant once
  # PUBLIC's is revoked — each app's own role, plus neiladmin for admin work.
  # cantrip_production is handled in cantrip.tf.
  production_database_connect_grants = {
    for pair in setproduct(local.production_databases, ["self", "neiladmin"]) :
    "${pair[0]}/${pair[1]}" => {
      database = pair[0]
      role     = pair[1] == "self" ? pair[0] : pair[1]
    }
  }
}

import {
  for_each = local.production_databases
  to       = postgresql_database.production[each.key]
  id       = each.key
}

# Only track existence here; owner/encoding/collation/template are left
# exactly as they are on the live databases (changing any of them would force
# a destroy/recreate), and prevent_destroy makes sure a bad plan can't take
# the data with it.
resource "postgresql_database" "production" {
  for_each = local.production_databases

  name = each.key

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      owner,
      template,
      encoding,
      lc_collate,
      lc_ctype,
      tablespace_name,
      connection_limit,
      allow_connections,
      is_template,
    ]
  }
}

# Postgres grants CONNECT on every database to PUBLIC by default, so without
# this any role on the instance (including new ones like cantrip_production)
# could connect to every app's database. Depends on the explicit grants below
# so apps never lose access in between.
resource "postgresql_grant" "production_public_revoke" {
  for_each = setunion(
    [for db in postgresql_database.production : db.name],
    local.production_admin_databases,
  )

  database    = each.key
  role        = "public"
  object_type = "database"
  privileges  = []

  # Grant each role its own CONNECT first so no app loses access mid-apply.
  depends_on = [postgresql_grant.production_connect]
}

resource "postgresql_grant" "production_connect" {
  for_each = local.production_database_connect_grants

  database    = postgresql_database.production[each.value.database].name
  role        = each.value.role
  object_type = "database"
  privileges  = ["CONNECT"]
}
