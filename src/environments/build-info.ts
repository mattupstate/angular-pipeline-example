/**
 * The values here are provided at build time.
 */
export class BuildInfo {
  static semVer = __SEMANTIC_VERSION__;
  static gitCommitSha = __GIT_COMMIT_SHA__;
  static gitCommitHref = __GIT_COMMIT_HREF__;
  static gitBranch = __GIT_BRANCH__;
  static gitBranchHref = __GIT_BRANCH_HREF__;
  static isGitDirty = __GIT_IS_DIRTY__;
}
