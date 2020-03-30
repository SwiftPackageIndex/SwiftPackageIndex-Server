import Foundation
import Vapor

class PackageListReconciler
{
  /// The list of new packages after reconciling
  var packagesToAdd: [URL]

  /// The list of packages which no longer exist after reconciling
  var packagesToDelete: [URL]

  /// Reconcile the master package list with the current package list producing a list of
  /// packages to add and delete.
  ///
  /// - Parameters:
  ///   - masterPackageList: The master package list from the GitHub master repository
  ///   - currentPackageList: The current package list according to the database
  init(masterPackageList: [URL], currentPackageList: [URL])
  {
    let masterPackageSet = Set(masterPackageList)
    let currentPackageSet = Set(currentPackageList)

    packagesToAdd = Array(masterPackageSet.subtracting(currentPackageSet))
    packagesToDelete = Array(currentPackageSet.subtracting(masterPackageSet))
  }
}
