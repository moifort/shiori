resource "google_firebaserules_ruleset" "firestore" {
  provider = google-beta
  project  = google_project.this.project_id

  source {
    files {
      name    = "firestore.rules"
      content = file("${path.root}/../firestore.rules")
    }
  }

  depends_on = [google_firestore_database.default]
}

resource "google_firebaserules_release" "firestore" {
  provider     = google-beta
  project      = google_project.this.project_id
  name         = "cloud.firestore"
  ruleset_name = "projects/${google_project.this.project_id}/rulesets/${google_firebaserules_ruleset.firestore.name}"
}

locals {
  firestore_indexes = jsondecode(file("${path.root}/../firestore.indexes.json")).indexes
}

resource "google_firestore_index" "composite" {
  # Keyed by a stable identifier (collection + fields), not the array position, so
  # adding or removing an index never re-keys — and therefore never destroys and
  # recreates — the others. A position key caused a transient FAILED_PRECONDITION
  # whenever the list changed in the middle.
  for_each = {
    for idx in local.firestore_indexes :
    "${idx.collectionGroup}|${join(",", [for f in idx.fields : "${f.fieldPath}:${try(f.order, try(f.arrayConfig, "NA"))}"])}" => idx
  }

  provider    = google-beta
  project     = google_project.this.project_id
  database    = google_firestore_database.default.name
  collection  = each.value.collectionGroup
  query_scope = each.value.queryScope

  # A field is indexed either by order (a scalar, ascending or descending) or by
  # array config (`CONTAINS`, what array-contains queries need). Firestore rejects
  # a field that declares neither, so both are read from firestore.indexes.json.
  dynamic "fields" {
    for_each = each.value.fields
    content {
      field_path   = fields.value.fieldPath
      order        = try(fields.value.order, null)
      array_config = try(fields.value.arrayConfig, null)
    }
  }
}

# Migrate existing state from the old position keys to the stable keys so the
# switch is a no-op rename (no destroy/recreate, no index rebuild, no downtime).
# These blocks can be removed once state is migrated on all environments.
moved {
  from = google_firestore_index.composite["0"]
  to   = google_firestore_index.composite["wines|userId:ASCENDING,createdAt:DESCENDING"]
}
moved {
  from = google_firestore_index.composite["1"]
  to   = google_firestore_index.composite["wines|userId:ASCENDING,color:ASCENDING,createdAt:DESCENDING"]
}
moved {
  from = google_firestore_index.composite["2"]
  to   = google_firestore_index.composite["wines|userId:ASCENDING,vintage:DESCENDING"]
}
moved {
  from = google_firestore_index.composite["3"]
  to   = google_firestore_index.composite["wines|userId:ASCENDING,updatedAt:DESCENDING"]
}
moved {
  from = google_firestore_index.composite["4"]
  to   = google_firestore_index.composite["wines|userId:ASCENDING,giftedBy:ASCENDING"]
}
moved {
  from = google_firestore_index.composite["5"]
  to   = google_firestore_index.composite["wines|userId:ASCENDING,region:ASCENDING"]
}
moved {
  from = google_firestore_index.composite["6"]
  to   = google_firestore_index.composite["wines|userId:ASCENDING,purchasePrice:ASCENDING"]
}
moved {
  from = google_firestore_index.composite["7"]
  to   = google_firestore_index.composite["cellar|userId:ASCENDING,createdAt:DESCENDING"]
}
moved {
  from = google_firestore_index.composite["8"]
  to   = google_firestore_index.composite["journal|userId:ASCENDING,date:DESCENDING"]
}
moved {
  from = google_firestore_index.composite["9"]
  to   = google_firestore_index.composite["journal|userId:ASCENDING,wineId:ASCENDING,date:DESCENDING"]
}
moved {
  from = google_firestore_index.composite["10"]
  to   = google_firestore_index.composite["tasting|userId:ASCENDING,rating:DESCENDING"]
}
moved {
  from = google_firestore_index.composite["11"]
  to   = google_firestore_index.composite["tasting|userId:ASCENDING,shortlist:ASCENDING,rating:DESCENDING"]
}
