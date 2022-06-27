ALTER TABLE "tenants"."backup_OLD_RETENTION_tenants" RENAME TO "backup_NEW_RETENTION_tenants";
ALTER TABLE "tenants"."backup_OLD_RETENTION_orgs" RENAME TO "backup_NEW_RETENTION_orgs";
ALTER TABLE "tenants"."backup_OLD_RETENTION_hosts" RENAME TO "backup_NEW_RETENTION_hosts";
ALTER TABLE "tenants"."backup_OLD_RETENTION_tracker_apps" RENAME TO "backup_NEW_RETENTION_tracker_apps";