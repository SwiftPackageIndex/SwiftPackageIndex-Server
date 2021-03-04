// In a local development environment, appVersion will remain nil (as set here).
// In the staging development environment, appVersion is set to the commit hash of the deployed version.
// In production, appVersion is set either to released tag name, or to the commit hash if that does not exist.

// Note: If the definition of appVersion ever changes, the `gitlab-ci.yml` file also
// needs updating as this file is re-generated during the deployment process.

let appVersion: String? = nil
