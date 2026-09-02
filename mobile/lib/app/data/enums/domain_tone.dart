/// The visual weight a domain value carries, named semantically so the enums in
/// this folder can say what a status *means* without importing Flutter.
///
/// The widget layer maps these to real colours through `AppPalette`, so a new
/// payment mode picks up its colour by naming a tone rather than by anyone
/// remembering to add a case to a switch in three widgets.
enum DomainTone { success, warning, info, danger, neutral }
