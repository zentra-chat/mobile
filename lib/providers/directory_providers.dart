import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/index.dart';
import 'api_provider.dart';

// Community members are what turn a mention id such as <@uuid> into a name.
// The member list does not carry role assignments, so author name colours are
// left out rather than guessed at.

final communityMembersProvider =
    FutureProvider.family<List<CommunityMember>, String>((ref, communityId) async {
      final api = ref.read(apiClientProvider);
      return api.getCommunityMembers(communityId);
    });

final communityRolesProvider =
    FutureProvider.family<List<Role>, String>((ref, communityId) async {
      final api = ref.read(apiClientProvider);
      return api.getRoles(communityId);
    });

class CommunityDirectory {
  const CommunityDirectory(this.members, this.roles);

  final List<CommunityMember> members;
  final List<Role> roles;

  /// Display name for a mentioned user: nickname, then display name, then
  /// username, matching the web client.
  String? userName(String userId) {
    for (final member in members) {
      if (member.userId != userId) continue;
      final nickname = member.nickname;
      if (nickname != null && nickname.isNotEmpty) return nickname;
      return member.user.effectiveName;
    }
    return null;
  }

  String? roleName(String roleId) {
    for (final role in roles) {
      if (role.id == roleId) return role.name;
    }
    return null;
  }

  User? user(String userId) {
    for (final member in members) {
      if (member.userId == userId) return member.user;
    }
    return null;
  }
}

final communityDirectoryProvider =
    Provider.family<CommunityDirectory, String>((ref, communityId) {
      final members = ref.watch(communityMembersProvider(communityId)).value;
      final roles = ref.watch(communityRolesProvider(communityId)).value;
      return CommunityDirectory(members ?? const [], roles ?? const []);
    });