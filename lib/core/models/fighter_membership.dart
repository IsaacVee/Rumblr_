enum FighterMembershipType {
  gym,
  independent,
}

enum FighterMembershipStatus {
  pending,
  active,
  suspended,
}

enum BillingState {
  trialing,
  active,
  pastDue,
  canceled,
}

enum FighterRole {
  fighter,
  gymAdmin,
  rumblrAdmin,
}

extension FighterMembershipTypeX on FighterMembershipType {
  String get id {
    switch (this) {
      case FighterMembershipType.gym:
        return 'gym';
      case FighterMembershipType.independent:
        return 'independent';
    }
  }

  static FighterMembershipType fromId(String? value) {
    switch (value) {
      case 'gym':
        return FighterMembershipType.gym;
      case 'independent':
      default:
        return FighterMembershipType.independent;
    }
  }
}

extension FighterMembershipStatusX on FighterMembershipStatus {
  String get id {
    switch (this) {
      case FighterMembershipStatus.pending:
        return 'pending';
      case FighterMembershipStatus.active:
        return 'active';
      case FighterMembershipStatus.suspended:
        return 'suspended';
    }
  }

  static FighterMembershipStatus fromId(String? value) {
    switch (value) {
      case 'active':
        return FighterMembershipStatus.active;
      case 'suspended':
        return FighterMembershipStatus.suspended;
      case 'pending':
      default:
        return FighterMembershipStatus.pending;
    }
  }
}

extension BillingStateX on BillingState {
  String get id {
    switch (this) {
      case BillingState.trialing:
        return 'trialing';
      case BillingState.active:
        return 'active';
      case BillingState.pastDue:
        return 'past_due';
      case BillingState.canceled:
        return 'canceled';
    }
  }

  static BillingState fromId(String? value) {
    switch (value) {
      case 'active':
        return BillingState.active;
      case 'past_due':
        return BillingState.pastDue;
      case 'canceled':
        return BillingState.canceled;
      case 'trialing':
      default:
        return BillingState.trialing;
    }
  }
}

extension FighterRoleX on FighterRole {
  String get id {
    switch (this) {
      case FighterRole.fighter:
        return 'fighter';
      case FighterRole.gymAdmin:
        return 'gym_admin';
      case FighterRole.rumblrAdmin:
        return 'rumblr_admin';
    }
  }

  static FighterRole fromId(String? value) {
    switch (value) {
      case 'gym_admin':
        return FighterRole.gymAdmin;
      case 'rumblr_admin':
        return FighterRole.rumblrAdmin;
      case 'fighter':
      default:
        return FighterRole.fighter;
    }
  }
}
