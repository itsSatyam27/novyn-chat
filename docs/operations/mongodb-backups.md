# Novyn MongoDB backups

The repository includes a daily encrypted MongoDB dump workflow at
`.github/workflows/daily-mongodb-backup.yml`.

## Required GitHub Actions secrets

Add these under **GitHub → repository Settings → Secrets and variables → Actions**:

- `MONGODB_URI`: the same database URI used by the Render API service.
- `ATLAS_PUBLIC_KEY` and `ATLAS_PRIVATE_KEY`: a MongoDB Atlas API key scoped to the Novyn project with permission to manage the project's IP access list.
- `ATLAS_PROJECT_ID`: the Atlas project/group ID containing the `novyn` database.
- `BACKUP_ENCRYPTION_PASSPHRASE`: a long, unique random passphrase. Store it in a password manager; without it, encrypted backups cannot be restored.

The workflow runs daily at 02:30 UTC and can also be started manually from
**GitHub → Actions → Daily encrypted MongoDB backup → Run workflow**.

For the dump, the workflow obtains the GitHub runner's public IP, temporarily
adds only that IP to the Atlas project access list, and removes it in an
always-run cleanup step. The Atlas API key therefore needs project IP access
list management permission. Do not add `0.0.0.0/0` to the Atlas access list.

Backups are compressed, encrypted with AES-256 using GPG, and uploaded as
GitHub Actions artifacts with 90-day retention. The unencrypted dump is deleted
from the runner after encryption. Do not print or expose any of the secrets.

## Restore

1. Download the required `novyn-mongodb-backup-*.archive.gz.gpg` artifact.
2. Decrypt it in a secure environment:
   `gpg --batch --pinentry-mode loopback --passphrase-file /secure/path/passphrase.txt --output novyn.archive.gz --decrypt novyn-mongodb-backup.archive.gz.gpg`
3. Restore to the intended MongoDB cluster only after confirming the target URI:
   `mongorestore --uri="$RESTORE_MONGODB_URI" --archive=novyn.archive.gz --gzip --drop`

**Warning:** `--drop` replaces collections in the target database. Never run a
restore against production as a test. Restore first to a separate staging
database/cluster and verify users, conversations, and messages.

## Operational notes

- The backup workflow will fail clearly until all five GitHub Actions secrets
  are configured.
- Artifact retention is 90 days; download and store any long-term copies in a
  separate protected backup location if longer retention is required.
- MongoDB Atlas managed backups should also be enabled in Atlas when the
  selected cluster tier supports them. The repository workflow is an
  independent logical backup, not a substitute for Atlas point-in-time recovery.
- The backup contains account records and chat data. Keep the encryption
  passphrase private and restrict repository Actions/artifact access.
