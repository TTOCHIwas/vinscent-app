import 'dart:io';

final class MobileToolPaths {
  MobileToolPaths.fromScript(Uri scriptUri)
    : mobileProject = File.fromUri(scriptUri).parent.parent,
      repositoryRoot = File.fromUri(scriptUri).parent.parent.parent.parent;

  final Directory mobileProject;
  final Directory repositoryRoot;

  File mobileFile(String relativePath) =>
      File.fromUri(mobileProject.uri.resolve(relativePath));

  File repositoryFile(String relativePath) =>
      File.fromUri(repositoryRoot.uri.resolve(relativePath));
}
