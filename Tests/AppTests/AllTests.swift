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

import Testing
import Dependencies


@Suite(.dependency(\.date.now, .t0)) struct AllTests { }


extension AllTests {
    @Suite struct AlertingTests { }
    @Suite struct AnalyzerTests { }
    @Suite struct AnalyzerVersionThrottlingTests { }
    @Suite struct API_DependencyControllerTests { }
    @Suite struct API_PackageController_GetRoute_ModelTests { }
    @Suite struct API_PackageController_GetRouteTests { }
    @Suite struct API_PackageControllerTests { }
    @Suite struct API_PackageSchemaTests { }
    @Suite struct ApiTests { }
    @Suite struct AppEnvironmentTests { }
    @Suite struct AppTests { }
    @Suite struct ArrayExtensionTests { }
    @Suite struct ArrayStringExtensionTests { }
    @Suite struct ArrayVersionExtensionTests { }
    @Suite struct AuthorControllerTests { }
    @Suite struct BadgeTests { }
    @Suite struct BlogActionsModelTests { }
    @Suite struct BuildIndexModelTests { }
    @Suite struct BuildMonitorControllerTests { }
    @Suite struct BuildMonitorIndexModelTests { }
    @Suite struct BuildResultTests { }
    @Suite struct BuildShowModelTests { }
    @Suite struct BuildTests { }
    @Suite struct BuildTriggerTests { }
    @Suite struct CustomCollectionControllerTests { }
    @Suite struct CustomCollectionTests { }
    @Suite struct DefaultStringInterpolationTests { }
    @Suite struct DocUploadTests { }
    @Suite struct DocumentationPageProcessorTests { }
    @Suite struct DocumentationTargetTests { }
    @Suite struct EmojiTests { }
    @Suite struct ErrorMiddlewareTests { }
    @Suite struct ErrorPageModelTests { }
    @Suite struct ErrorReportingTests { }
    @Suite struct FundingLinkTests { }
    @Suite struct GitTests { }
    @Suite struct GithubTests { }
    @Suite struct GitlabBuilderTests { }
    @Suite struct LiveGitlabBuilderTests { }
    @Suite struct HomeIndexModelTests { }
    @Suite struct IngestionTests { }
    @Suite struct IntExtTests { }
    @Suite struct Joined3Tests { }
    @Suite struct JoinedQueryBuilderTests { }
    @Suite struct JoinedTests { }
    @Suite struct KeywordControllerTests { }
    @Suite struct LicenseTests { }
    @Suite struct LiveTests { }
    @Suite struct MaintainerInfoIndexModelTests { }
    @Suite struct MaintainerInfoIndexViewTests { }
    @Suite struct ManifestTests { }
    @Suite struct MastodonTests { }
    @Suite struct MetricsTests { }
    @Suite struct MiscTests { }
    @Suite struct PackageCollectionControllerTests { }
    @Suite struct PackageCollectionTests { }
    @Suite struct PackageContributorsTests { }
    @Suite struct PackageController_BuildsRoute_BuildInfoTests { }
    @Suite struct PackageController_BuildsRouteTests { }
    @Suite struct PackageController_routesTests { }
    @Suite struct PackageInfoTests { }
    @Suite struct PackageReadmeModelTests { }
    @Suite struct PackageReleasesModelTests { }
    @Suite struct PackageResultTests { }
    @Suite struct PackageTests { }
    @Suite struct PipelineTests { }
    @Suite struct PlausibleTests { }
    @Suite struct ProductTests { }
    @Suite struct QueryPlanTests { }
    @Suite struct RSSTests { }
    @Suite struct ReAnalyzeVersionsTests { }
    @Suite struct RecentViewsTests { }
    @Suite struct ReconcilerTests { }
    @Suite struct ReferenceTests { }
    @Suite struct RepositoryTests { }
    @Suite struct ResourceReloadIdentifierTests { }
    @Suite struct RoutesTests { }
    @Suite struct S3StoreExtensionTests { }
    @Suite struct SQLKitExtensionTests { }
    @Suite struct ScoreTests { }
    @Suite struct SearchFilterTests { }
    @Suite struct SearchShowModelAppTests { }
    @Suite struct SearchShowModelTests { }
    @Suite struct SearchTests { }
    @Suite struct ShellOutCommandExtensionTests { }
    @Suite struct SignificantBuildsTests { }
    @Suite struct SiteURLTests { }
    @Suite struct SitemapTests { }
    @Suite struct SocialTests { }
    @Suite struct StatsTests { }
    @Suite struct StringExtTests { }
    @Suite struct SwiftVersionTests { }
    @Suite struct TargetTests { }
    @Suite struct ValidateSPIManifestControllerTests { }
    @Suite struct VersionDiffTests { }
    @Suite struct VersionTests { }
    @Suite struct ViewUtilsTests { }
}
