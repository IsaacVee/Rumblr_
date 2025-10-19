enum FightCategory {
  sparring,
  exhibition,
  ranked,
}

extension FightCategoryX on FightCategory {
  String get id {
    switch (this) {
      case FightCategory.sparring:
        return 'sparring';
      case FightCategory.exhibition:
        return 'exhibition';
      case FightCategory.ranked:
        return 'ranked';
    }
  }

  String get label {
    switch (this) {
      case FightCategory.sparring:
        return 'Sparring';
      case FightCategory.exhibition:
        return 'Exhibition';
      case FightCategory.ranked:
        return 'Ranked';
    }
  }

  String get description {
    switch (this) {
      case FightCategory.sparring:
        return 'Light-contact practice rounds. No ranking impact.';
      case FightCategory.exhibition:
        return 'Full rules fight for experience. Rankings unaffected.';
      case FightCategory.ranked:
        return 'Official bout judged by gym staff. Updates ELO.';
    }
  }

  bool get affectsElo => this == FightCategory.ranked;

  static FightCategory fromId(String? id) {
    switch (id) {
      case 'sparring':
        return FightCategory.sparring;
      case 'exhibition':
        return FightCategory.exhibition;
      case 'ranked':
        return FightCategory.ranked;
      default:
        return FightCategory.ranked;
    }
  }
}
