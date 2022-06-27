CREATE TABLE "tenants"."backup_RETENTION_tenants" AS SELECT * FROM "tenants"."tenants";
CREATE TABLE "tenants"."backup_RETENTION_orgs" AS SELECT * FROM "tenants"."orgs";
CREATE TABLE "tenants"."backup_RETENTION_hosts" AS SELECT * FROM "tenants"."hosts";
CREATE TABLE "tenants"."backup_RETENTION_tracker_apps" AS SELECT * FROM "tenants"."tracker_apps";

