// Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Fluent


/// Every migration, in the order they must be applied.
///
/// Append new migrations to the end. Never reorder or remove an entry: the `migrations` table keys
/// off ``Migration/name``, so an already-applied migration that disappears from this list stays
/// applied, and a reordered one still won't re-run.
///
/// ``register(on:)`` is the only way these get registered, and it wraps every one in
/// ``TransactionalMigration``, so a migration cannot be registered non-transactionally.
enum AllMigrations {

    static let all: [any AsyncMigration] = [
        // Migration 001 - schema 1.0
        CreatePackage(),
        CreateRepository(),
        CreateVersion(),
        CreateProduct(),
        CreateRecentPackages(),
        CreateRecentReleases(),
        CreateSearch(),

        // Migration 002 - unique owner/repository index
        CreateOwnerRepositoryIndex(),
        CreateRepositoriesNameIndex(),

        // Migration 003 - update recent packages/releases views
        UpdateRecentPackages1(),
        UpdateRecentReleases1(),

        // Migration 004 - make status required, defaulting to 'new'
        UpdatePackageStatusNew(),

        // Migration 005 - update recent packages/releases views
        UpdateRecentPackages2(),
        UpdateRecentReleases2(),

        // Migration 006 - update recent releases view
        UpdateRecentReleases3(),

        // Migration 007 - dedupe package name changes
        UpdateRecentPackages3(),
        UpdateRecentReleases4(),

        // Migration 008 - add stats view
        CreateStats(),

        // Migration 009 - add builds table
        CreateBuild(),

        // Migration 010 - add non-null constraints to builds fields
        UpdateBuildNonNull(),

        // Migration 011 - add log_url field to builds
        UpdateBuildAddLogURL(),

        // Migration 012 - change platfrom to .string
        UpdateBuildPlatform(),

        // Migration 013 - add build command
        UpdateBuildAddBuildCommand(),

        // Migration 014 - add latest
        UpdateVersionAddLatest(),

        // Migration 015 - add unique index to builds
        UpdateBuildUniqueIndex1(),

        // Migration 016 - add job_url field to builds
        UpdateBuildAddJobUrl(),

        // Migration 017 - remove logs field from builds
        UpdateBuildRemoveLogs(),

        // Migration 018 - add license_url to repositories
        UpdateRepositoryAddLicenseUrl(),

        // Migration 019 - add readme_url to repositories
        UpdateRepositoryAddReadmeUrl(),

        // Migration 020 - add tools_version to versions
        UpdateVersionAddToolsVersion(),

        // Migration 021 - add release_url to recent_releases and url to versions
        UpdateVersionAddUrl(),
        UpdateRecentReleases5(),

        // Migration 022 - add is_archived to repositories
        UpdateRepositoryAddIsArchived(),

        // Migration 023 - add releases to repositories and published_at and release_notes to versions
        UpdateRepositoryAddReleases(),
        UpdateVersionAddPublisedAtReleaseNotes(),

        // Migration 024 - add targets table
        CreateTarget(),

        // Migration 025 - add targets to products
        UpdateProductAddTargets(),

        // Migration 026 - Add rendered README url
        UpdateRepositoryAddReadmeHtmlUrl(),

        // Migration 027 - add owner name, owner avatar url, and is in organization metadata to repositories
        UpdateRepositoryAddOwnerFields(),

        // Migration 028 - change products.type from string to json
        UpdateProductType(),

        // Migration 029 - add release_notes_html to recent_releases and release_notes_html to versions
        UpdateVersionAddReleaseNotesHTML(),
        UpdateRecentReleases6(),

        // Migration 030 - add repositories.keywords
        UpdateRepositoryAddKeywords(),

        // Migration 031 - add search.keywords
        UpdateSearch1(),

        // Migration 032 - add [license, stars, last_commit_date] to search
        UpdateSearch2(),

        // Migration 033 - add resolved_dependencies to versions
        UpdateVersionAddResolvedDependencies(),

        // Migration 034 - make resolved_dependencies nullable
        UpdateVersionResolvedDependenciesNullable(),

        // Migration 035 - change builds.pending to triggered
        UpdateBuildPendingToTriggered(),

        // Migration 036 - make packages.score required
        UpdatePackageScoreNotNullable(),

        // Migration 037 - make several columns on repositories required
        UpdateRepositoryStarsNotNullable(),
        UpdateRepositoryForksNotNullable(),
        UpdateRepositoryCommitCountNotNullable(),
        UpdateRepositoryOpenIssuesNotNullable(),
        UpdateRepositoryOpenPullRequestsNotNullable(),
        UpdateRepositoryIsArchivedNotNullable(),
        UpdateRepositoryIsInOrganizationNotNullable(),

        // Migration 038 - add last_activity_at to search
        AddLastActivityAtToRepositories(),
        UpdateSearch3(),

        // Migration 039 - rename id to package_id on recent_releases
        UpdateRecentReleases7(),

        // Migration 040 - add platform_compatibility field
        UpdatePackageAppPlatformCompatibility(),

        // Migration 041 - add platform_compatibility to search
        UpdateSearch4(),

        // Migration 042 - increase number of rows in recent_releases and recent_packages
        UpdateRecentPackages4(),
        UpdateRecentReleases8(),

        // Migration 043 - add runner_id to builds
        UpdateBuildAddRunnerId(),

        // Migration 044 - make version fields required
        UpdateVersionCommitNotNullable(),
        UpdateVersionCommitDateNotNullable(),
        UpdateVersionReferenceNotNullable(),

        // Migration 045 - create fuzzystrmatch extension for search
        CreateExtensionFuzzyStrMatch(),

        // Migration 046 - delete `%-arm` builds
        DeleteArmBuilds(),

        // Migration 047 - Remove `version_count` from `stats` materialized view.
        RemoveVersionCountFromStats(),

        // Migration 048 - add repositories.homepage_url
        UpdateRepositoryAddHomepageUrl(),

        // Migration 049 - add versions.spi_manifest
        UpdateVersionAddSPIManifest(),

        // Migration 050 - add versions.doc_archives
        UpdateVersionAddDocArchives(),

        // Migration 051 - remove versions.doc_archives
        UpdateVersionRemoveDocArchives(),

        // Migration 052 - add versions.doc_archives again
        UpdateVersionAddDocArchives2(),

        // Migration 053 - adds products.type to search
        UpdateSearchAddProductType(),

        // Migration 054 - create weighted_keywords view for counting keywords
        CreateWeightedKeywords(),

        // Migration 055 - adds boolean flag indicating existence of docs to search
        UpdateSearchAddHasDocs(),

        // Migration 056 - reset versions.doc_archives to NULL
        ResetDocArchives(),

        // Migration 057 - adds boolean flag indicating whether the package contains binary targets
        UpdateVersionAddHasBinaryTargets(),

        // Migration 058 - adds tsvector to materialised search view
        UpdateSearchAddTSVector(),

        // Migration 059 - delete Swift 5.3 builds
        DeleteSwift5_3Builds(),

        // Migration 060 - update repository authors type
        UpdateRepositoryAuthorsType(),

        // Migration 061 - create doc_uploads
        CreateDocUpload(),

        // Migration 062 - add repository name to ts vector
        UpdateSearchExtendTSVector(),

        // Migration 063 - add product names to search view
        UpdateSearchAddProductNames(),

        // Migration 064 - add type to targets
        UpdateTargetAddType(),

        // Migration 065 - add linkable_paths_count to doc_uploads
        UpdateDocUploadAddLinkablePathsCount(),

        // Migration 066 - add virtual macro product type to search view
        UpdateSearchAddMacroProductType(),

        // Migration 067 - remove readmeUrl, readmeHtmlUrl from repositories, add readmeEtag
        UpdateRepositoryReadmeChanges(),

        // Migration 068 - add product_dependencies to versions
        UpdateVersionAddProductDependencies(),

        // Migration 069 - add builder_version to builds
        UpdateBuildAddBuilderVersion(),

        // Migration 070 - Add score_details to packages
        UpdatePackageAddScoreDetails(),

        // Migration 071 - Remove default from product_dependencies, reset product_dependencies and resolved_dependencies
        UpdateVersionResetProductDependenciesWithDefault(),
        UpdateVersionResetResolvedDependencies(),

        // Migration 072 - Update has_docs to include external documentation
        UpdateSearchUpdateHasDocs(),

        // Migration 073 - Add `funding` JSON field to `repositories`
        AddFundingToRepositories(),

        // Migration 074 - Add `build_duration` field to `builds`
        UpdateBuildAddBuildDuration(),

        // Migration 075 - Reset repositories.funding_links
        UpdateRepositoryResetFundingLinks(),

        // Migration 076 - Add `build_errors` to `builds`
        UpdateBuildAddBuildErrors(),

        // Migration 077 - Remove all etags from README files so they are re-fetched
        UpdateRepositoryResetReadmes(),

        // Migration 078 - Add `build_date` and `commit_hash` to `builds`
        UpdateBuildAddBuildDateCommitHash(),

        // Migration 079 - Add `forked_from` to `repositories`
        UpdateRepositoryAddForkedFrom(),

        // Migration 080 - Set`forked_from` to NULL because of Fork model change in Repository
        UpdateRepositoryResetForkedFrom(),

        // Migration 081 - Create `custom_collections`
        CreateCustomCollection(),
        CreateCustomCollectionPackage(),

        // Migration 082 - Add `has_spi_badge` to `repositories`
        UpdateRepositoryAddHasSPIBadge(),

        // Migration 083 - Add `key` and unique constraint to `custom_collections`
        UpdateCustomCollectionAddKey(),

        // Migration 084 - Update licenses with `other` -> `unknown` and `compatible`/`incompatible` -> `known`
        UpdateRepositoriesLicenseAndScoreDetails(),
    ]

    /// Registers every migration, each wrapped in a transaction.
    static func register(on migrations: Migrations) {
        migrations.add(all.map(TransactionalMigration.init))
    }

}
